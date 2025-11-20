import Foundation

class AIService: ObservableObject {
    static let shared = AIService()
    
    @Published var isProcessing = false
    
    // Available models
    let availableModels = [
        "gpt-3.5-turbo",
        "gpt-4-turbo",
        "gpt-4o",
        "gemini-pro"
    ]
    
    func sendMessage(_ messages: [ChatMessage], model: String = "gpt-3.5-turbo", completion: @escaping (Result<String, Error>) -> Void) {
        if model.contains("gemini") {
            sendGeminiMessage(messages, model: model, completion: completion)
        } else {
            sendOpenAIMessage(messages, model: model, completion: completion)
        }
    }
    
    private func sendOpenAIMessage(_ messages: [ChatMessage], model: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let apiKey = SettingsManager.shared.openAIKey.isEmpty ? nil : SettingsManager.shared.openAIKey else {
            completion(.failure(NSError(domain: "VeroChat", code: 401, userInfo: [NSLocalizedDescriptionKey: "OpenAI API Key Missing"])))
            return
        }
        
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Map messages to API format
        let apiMessages: [[String: Any]] = messages.map { msg in
            if let imageData = msg.imageData {
                // Vision payload
                let base64Image = imageData.base64EncodedString()
                return [
                    "role": msg.role.rawValue,
                    "content": [
                        ["type": "text", "text": msg.content],
                        ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64Image)"]]
                    ]
                ]
            } else {
                // Standard payload
                return ["role": msg.role.rawValue, "content": msg.content]
            }
        }
        
        let body: [String: Any] = [
            "model": model,
            "messages": apiMessages
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        performRequest(request: request, completion: completion)
    }
    
    private func sendGeminiMessage(_ messages: [ChatMessage], model: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let apiKey = SettingsManager.shared.geminiKey.isEmpty ? nil : SettingsManager.shared.geminiKey else {
            completion(.failure(NSError(domain: "VeroChat", code: 401, userInfo: [NSLocalizedDescriptionKey: "Gemini API Key Missing"])))
            return
        }
        
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Gemini format is different: contents: [{ role: "user", parts: [{ text: "..." }] }]
        // Note: Gemini roles are "user" and "model" (not assistant)
        let geminiContent: [[String: Any]] = messages.map { msg in
            let role = msg.role == .user ? "user" : "model"
            // System messages are not directly supported in generateContent, often prepended to user or ignore for now
            // For simplicity, treating system as user or filtering out. Let's map system to user prompt for now.
            let effectiveRole = msg.role == .system ? "user" : role
            
            return [
                "role": effectiveRole,
                "parts": [
                    ["text": msg.content]
                ]
            ]
        }
        
        let body: [String: Any] = [
            "contents": geminiContent
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        isProcessing = true
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isProcessing = false
            }
            
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "VeroChat", code: 0, userInfo: [NSLocalizedDescriptionKey: "No Data"])))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let candidates = json["candidates"] as? [[String: Any]],
                   let first = candidates.first,
                   let content = first["content"] as? [String: Any],
                   let parts = content["parts"] as? [[String: Any]],
                   let firstPart = parts.first,
                   let text = firstPart["text"] as? String {
                    completion(.success(text))
                } else {
                    // Error handling
                    completion(.failure(NSError(domain: "VeroChat", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid Gemini Response"])))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    private func performRequest(request: URLRequest, completion: @escaping (Result<String, Error>) -> Void) {
        // Removed redundant assignment
        
        isProcessing = true
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isProcessing = false
            }
            
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "VeroChat", code: 0, userInfo: [NSLocalizedDescriptionKey: "No Data"])))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    completion(.success(content))
                } else {
                     // Try to parse error message
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorObj = json["error"] as? [String: Any],
                       let message = errorObj["message"] as? String {
                         completion(.failure(NSError(domain: "API", code: 0, userInfo: [NSLocalizedDescriptionKey: message])))
                    } else {
                        completion(.failure(NSError(domain: "VeroChat", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid Response"])))
                    }
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    // Image Generation (DALL-E 3)
    func generateImage(prompt: String, completion: @escaping (Result<URL, Error>) -> Void) {
        guard let apiKey = SettingsManager.shared.openAIKey.isEmpty ? nil : SettingsManager.shared.openAIKey else {
             completion(.failure(NSError(domain: "VeroChat", code: 401, userInfo: [NSLocalizedDescriptionKey: "OpenAI API Key Missing"])))
             return
        }
        
        let url = URL(string: "https://api.openai.com/v1/images/generations")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": "dall-e-3",
            "prompt": prompt,
            "n": 1,
            "size": "1024x1024"
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        isProcessing = true
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isProcessing = false
            }
            
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "VeroChat", code: 0, userInfo: [NSLocalizedDescriptionKey: "No Data"])))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let dataArray = json["data"] as? [[String: Any]],
                   let first = dataArray.first,
                   let urlString = first["url"] as? String,
                   let url = URL(string: urlString) {
                    completion(.success(url))
                } else {
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorObj = json["error"] as? [String: Any],
                       let message = errorObj["message"] as? String {
                         completion(.failure(NSError(domain: "API", code: 0, userInfo: [NSLocalizedDescriptionKey: message])))
                    } else {
                        completion(.failure(NSError(domain: "VeroChat", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid Image Response"])))
                    }
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}
