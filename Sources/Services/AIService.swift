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
        // Process messages to include file content for AI processing
        let processedMessages = messages.map { msg -> ChatMessage in
            if let fileContent = msg.attachedFileContent, let fileName = msg.attachedFileName {
                // Include file content in the message content for AI, but keep original structure
                let enhancedContent = msg.content.isEmpty 
                    ? "\n\n[File Context: \(fileName)]\n\(fileContent)\n[End of File]"
                    : "\(msg.content)\n\n[File Context: \(fileName)]\n\(fileContent)\n[End of File]"
                return ChatMessage(role: msg.role, content: enhancedContent, imageURL: msg.imageURL, imageData: msg.imageData, hasAnimated: msg.hasAnimated, attachedFileName: msg.attachedFileName, attachedFileContent: msg.attachedFileContent)
            }
            return msg
        }
        
        // Se Rovena Cloud estiver ativo, usa chave padrão diretamente
        // Caso contrário, usa as chaves do usuário
        if model.contains("gemini") {
            sendGeminiMessage(processedMessages, model: model, completion: completion)
        } else {
            sendOpenAIMessage(processedMessages, model: model, completion: completion)
        }
    }
    
    private func sendOpenAIMessage(_ messages: [ChatMessage], model: String, completion: @escaping (Result<String, Error>) -> Void) {
        // Se Rovena Cloud estiver ativo, usa chave padrão; senão, usa chave do usuário
        let apiKey: String
        if SettingsManager.shared.useRovenaCloud {
            let defaultKey = SettingsManager.defaultRovenaAPIKey
            guard !defaultKey.isEmpty else {
                let errorMsg = "Rovena Cloud API Key not configured. Please set ROVENA_DEFAULT_API_KEY in Config.plist or environment variable."
                LogManager.shared.addLog(errorMsg, level: .error, category: "AIService")
                completion(.failure(NSError(domain: "Rovena", code: 401, userInfo: [NSLocalizedDescriptionKey: errorMsg])))
                return
            }
            
            // Validar formato da chave antes de usar
            if !defaultKey.hasPrefix("sk-") {
                let errorMsg = "Invalid API key format. OpenAI API keys should start with 'sk-'. Please check your ROVENA_DEFAULT_API_KEY in Config.plist."
                LogManager.shared.addLog(errorMsg, level: .error, category: "AIService")
                completion(.failure(NSError(domain: "Rovena", code: 401, userInfo: [NSLocalizedDescriptionKey: errorMsg])))
                return
            }
            
            apiKey = defaultKey
            print("🔑 [AIService] Using Rovena Cloud API key (length: \(apiKey.count), prefix: \(apiKey.prefix(15)))")
            LogManager.shared.addLog("Using Rovena Cloud API key (length: \(apiKey.count), prefix: \(apiKey.prefix(15)))", level: .info, category: "AIService")
            // Verificar limite de tokens antes de fazer requisição quando usar Rovena Cloud
            let estimatedTokens = estimateTokenCount(messages: messages, model: model)
            if !TokenService.shared.canUseTokens(estimatedTokens) {
                let remaining = TokenService.shared.remainingTokens()
                let used = TokenService.shared.tokensUsedLast30Days
                let limit = TokenService.shared.monthlyLimit
                let plan = TokenService.shared.currentPlan
                
                let errorMessage = """
                Token limit exceeded for plan \(plan).
                
                Used: \(used.formatted()) / \(limit.formatted()) tokens
                Remaining: \(remaining.formatted()) tokens
                
                Your limit will reset in 30 days from first usage, or upgrade your plan for more tokens.
                """
                
                LogManager.shared.addLog(
                    "Token limit blocked - Used: \(used)/\(limit), Plan: \(plan)",
                    level: .warning,
                    category: "AIService"
                )
                
                completion(.failure(NSError(domain: "Rovena", code: 429, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                return
            }
        } else {
            guard let userKey = SettingsManager.shared.openAIKey.isEmpty ? nil : SettingsManager.shared.openAIKey else {
                completion(.failure(NSError(domain: "VeroChat", code: 401, userInfo: [NSLocalizedDescriptionKey: "OpenAI API Key Missing"])))
                return
            }
            apiKey = userKey
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
        // Se Rovena Cloud estiver ativo, verificar limite de tokens
        if SettingsManager.shared.useRovenaCloud {
            let estimatedTokens = estimateTokenCount(messages: messages, model: model)
            if !TokenService.shared.canUseTokens(estimatedTokens) {
                let remaining = TokenService.shared.remainingTokens()
                let used = TokenService.shared.tokensUsedLast30Days
                let limit = TokenService.shared.monthlyLimit
                let plan = TokenService.shared.currentPlan
                
                let errorMessage = """
                Token limit exceeded for plan \(plan).
                
                Used: \(used.formatted()) / \(limit.formatted()) tokens
                Remaining: \(remaining.formatted()) tokens
                
                Your limit will reset in 30 days from first usage, or upgrade your plan for more tokens.
                """
                
                LogManager.shared.addLog(
                    "Token limit blocked (Gemini) - Used: \(used)/\(limit), Plan: \(plan)",
                    level: .warning,
                    category: "AIService"
                )
                
                completion(.failure(NSError(domain: "Rovena", code: 429, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                return
            }
        }
        
        // Se Rovena Cloud estiver ativo, usa chave padrão; senão, usa chave do usuário
        // Nota: Para Gemini, você pode adicionar uma chave padrão também se necessário
        let apiKey: String
        if SettingsManager.shared.useRovenaCloud {
            // Por enquanto, Gemini ainda requer chave do usuário mesmo com Rovena Cloud
            // Você pode adicionar uma chave padrão do Gemini aqui se quiser
            guard let userKey = SettingsManager.shared.geminiKey.isEmpty ? nil : SettingsManager.shared.geminiKey else {
                completion(.failure(NSError(domain: "VeroChat", code: 401, userInfo: [NSLocalizedDescriptionKey: "Gemini API Key Missing"])))
                return
            }
            apiKey = userKey
        } else {
            guard let userKey = SettingsManager.shared.geminiKey.isEmpty ? nil : SettingsManager.shared.geminiKey else {
                completion(.failure(NSError(domain: "VeroChat", code: 401, userInfo: [NSLocalizedDescriptionKey: "Gemini API Key Missing"])))
                return
            }
            apiKey = userKey
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
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // Debug: Print the full response
                    if let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
                       let jsonString = String(data: jsonData, encoding: .utf8) {
                        print("=== GEMINI RESPONSE ===")
                        print(jsonString)
                        print("=== END GEMINI ===")
                    }
                    
                    // Check for error first
                    if let error = json["error"] as? [String: Any],
                       let message = error["message"] as? String {
                        completion(.failure(NSError(domain: "Gemini", code: 0, userInfo: [NSLocalizedDescriptionKey: "Gemini Error: \(message)"])))
                        return
                    }
                    
                    if let candidates = json["candidates"] as? [[String: Any]],
                       let first = candidates.first,
                       let content = first["content"] as? [String: Any],
                       let parts = content["parts"] as? [[String: Any]],
                       let firstPart = parts.first,
                       let text = firstPart["text"] as? String {
                        // Registrar uso de tokens se estiver usando Rovena Cloud
                        if SettingsManager.shared.useRovenaCloud, let strongSelf = self {
                            // Estimar tokens usados (Gemini não retorna usage no response)
                            let estimatedTokens = strongSelf.estimateTokenCount(messages: messages, model: model)
                            TokenService.shared.recordTokenUsage(estimatedTokens)
                        }
                        completion(.success(text))
                    } else {
                        completion(.failure(NSError(domain: "VeroChat", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid Gemini Response structure"])))
                    }
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    private func performRequest(request: URLRequest, completion: @escaping (Result<String, Error>) -> Void) {
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
                    // Registrar uso de tokens se estiver usando Rovena Cloud
                    if SettingsManager.shared.useRovenaCloud {
                        TokenService.shared.recordUsageFromAPIResponse(json)
                        
                        // Log do uso registrado
                        if let usage = json["usage"] as? [String: Any],
                           let totalTokens = usage["total_tokens"] as? Int {
                            LogManager.shared.addLog(
                                "Tokens used: \(totalTokens) (Total: \(TokenService.shared.tokensUsedLast30Days)/\(TokenService.shared.monthlyLimit))",
                                level: .info,
                                category: "AIService"
                            )
                        }
                    }
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
    
    // MARK: - Token Estimation
    
    /// Estima quantidade de tokens baseado nas mensagens e modelo
    private func estimateTokenCount(messages: [ChatMessage], model: String) -> Int {
        // Estimativa simples: ~4 caracteres por token em média
        let totalChars = messages.reduce(0) { $0 + $1.content.count }
        let estimated = totalChars / 4
        
        // Ajuste baseado no modelo (modelos maiores tendem a usar mais tokens)
        if model.contains("gpt-4") {
            return Int(Double(estimated) * 1.2) // GPT-4 tende a usar mais tokens
        }
        
        return estimated
    }
    
    // Image Generation (DALL-E 3)
    func generateImage(prompt: String, completion: @escaping (Result<URL, Error>) -> Void) {
        // Custo de geração de imagem em tokens
        let imageGenerationCost = 1000
        
        // Verificar limite de tokens antes de gerar imagem quando usar Rovena Cloud
        if SettingsManager.shared.useRovenaCloud {
            if !TokenService.shared.canUseTokens(imageGenerationCost) {
                let remaining = TokenService.shared.remainingTokens()
                let used = TokenService.shared.tokensUsedLast30Days
                let limit = TokenService.shared.monthlyLimit
                let plan = TokenService.shared.currentPlan
                
                let errorMessage = """
                Token limit exceeded for plan \(plan).
                
                Used: \(used.formatted()) / \(limit.formatted()) tokens
                Remaining: \(remaining.formatted()) tokens
                
                Image generation costs \(imageGenerationCost) tokens. Your limit will reset in 30 days from first usage, or upgrade your plan for more tokens.
                """
                
                LogManager.shared.addLog(
                    "Token limit blocked (Image) - Used: \(used)/\(limit), Plan: \(plan)",
                    level: .warning,
                    category: "AIService"
                )
                
                completion(.failure(NSError(domain: "Rovena", code: 429, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                return
            }
        }
        
        // Se Rovena Cloud estiver ativo, usa chave padrão; senão, usa chave do usuário
        let apiKey: String
        if SettingsManager.shared.useRovenaCloud {
            let defaultKey = SettingsManager.defaultRovenaAPIKey
            guard !defaultKey.isEmpty else {
                completion(.failure(NSError(domain: "Rovena", code: 401, userInfo: [NSLocalizedDescriptionKey: "Rovena Cloud API Key not configured. Please set ROVENA_DEFAULT_API_KEY in Config.plist or environment variable."])))
                return
            }
            apiKey = defaultKey
            // Verificar limite de tokens antes de gerar imagem
            if !TokenService.shared.canUseTokens(imageGenerationCost) {
                let remaining = TokenService.shared.remainingTokens()
                let used = TokenService.shared.tokensUsedLast30Days
                let limit = TokenService.shared.monthlyLimit
                completion(.failure(NSError(domain: "Rovena", code: 429, userInfo: [NSLocalizedDescriptionKey: "Token limit exceeded. Used \(used)/\(limit) tokens. Remaining: \(remaining)"])))
                return
            }
        } else {
            guard let userKey = SettingsManager.shared.openAIKey.isEmpty ? nil : SettingsManager.shared.openAIKey else {
                completion(.failure(NSError(domain: "VeroChat", code: 401, userInfo: [NSLocalizedDescriptionKey: "OpenAI API Key Missing"])))
                return
            }
            apiKey = userKey
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
                    // Registrar uso de tokens se estiver usando Rovena Cloud
                    if SettingsManager.shared.useRovenaCloud {
                        TokenService.shared.recordTokenUsage(imageGenerationCost)
                    }
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
