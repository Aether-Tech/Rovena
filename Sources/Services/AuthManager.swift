import Foundation
import SwiftUI

class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var user: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    var idToken: String? {
        user?.idToken
    }
    
    struct User: Codable {
        let email: String
        let uid: String
        let idToken: String
    }
    
    private let apiKey = "AIzaSyD9Jfrm98ZGiKr5nGMMe7opRbbo56POe2c"
    
    private init() {
        loadUser()
    }
    
    func setup() {
        // Load saved user from UserDefaults
        loadUser()
    }
    
    private func loadUser() {
        if let data = UserDefaults.standard.data(forKey: "firebase_user"),
           let user = try? JSONDecoder().decode(User.self, from: data) {
            self.user = user
        }
    }
    
    private func saveUser(_ user: User) {
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: "firebase_user")
        }
        self.user = user
    }
    
    func signIn(email: String, pass: String) {
        isLoading = true
        errorMessage = nil
        
        LogManager.shared.addLog("Starting signin for email: \(email)", level: .info, category: "AuthManager")
        
        guard !email.isEmpty, !pass.isEmpty else {
            errorMessage = "EMAIL AND PASSWORD REQUIRED"
            isLoading = false
            LogManager.shared.addLog("Signin failed: Empty email or password", level: .error, category: "AuthManager")
            return
        }
        
        // Validação básica de formato de email
        guard email.contains("@") && email.contains(".") else {
            errorMessage = "INVALID EMAIL FORMAT"
            isLoading = false
            LogManager.shared.addLog("Signin failed: Invalid email format", level: .error, category: "AuthManager")
            return
        }
        
        // Use Firebase REST API for sign in
        let url = URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "email": email,
            "password": pass,
            "returnSecureToken": true
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        LogManager.shared.addLog("Sending signin request to Firebase", level: .info, category: "AuthManager")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    let errorMsg = "NETWORK ERROR :: \(error.localizedDescription.uppercased())"
                    self?.errorMessage = errorMsg
                    LogManager.shared.addLog("Signin network error: \(error.localizedDescription)", level: .error, category: "AuthManager")
                    return
                }
                
                guard let data = data else {
                    self?.errorMessage = "NO DATA RECEIVED"
                    LogManager.shared.addLog("Signin failed: No data received from Firebase", level: .error, category: "AuthManager")
                    return
                }
                
                // Log raw response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    LogManager.shared.addLog("Firebase response: \(responseString)", level: .debug, category: "AuthManager")
                }
                
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let errorData = json["error"] as? [String: Any],
                       let message = errorData["message"] as? String {
                        // Handle Firebase errors
                        LogManager.shared.addLog("Firebase error: \(message)", level: .error, category: "AuthManager")
                        switch message {
                        case "EMAIL_NOT_FOUND":
                            self?.errorMessage = "USER NOT FOUND :: CREATE AN ACCOUNT FIRST"
                        case "INVALID_PASSWORD":
                            self?.errorMessage = "WRONG PASSWORD"
                        case "USER_DISABLED":
                            self?.errorMessage = "ACCOUNT DISABLED"
                        default:
                            self?.errorMessage = "LOGIN FAILED :: \(message)"
                        }
                    } else if let email = json["email"] as? String,
                              let uid = json["localId"] as? String,
                              let token = json["idToken"] as? String {
                        // Success!
                        LogManager.shared.addLog("Signin successful! Email: \(email), UID: \(uid)", level: .info, category: "AuthManager")
                        let user = User(email: email, uid: uid, idToken: token)
                        self?.saveUser(user)
                        self?.errorMessage = nil
                        // Sincronizar tokens após login
                        TokenService.shared.syncWithAPI(force: true)
                    } else {
                        LogManager.shared.addLog("Signin failed: Unexpected response format", level: .error, category: "AuthManager")
                    }
                } else {
                    LogManager.shared.addLog("Signin failed: Invalid JSON response", level: .error, category: "AuthManager")
                }
            }
        }.resume()
    }
    
    func signUp(email: String, pass: String, name: String = "") {
        isLoading = true
        errorMessage = nil
        
        LogManager.shared.addLog("Starting signup for email: \(email)", level: .info, category: "AuthManager")
        
        guard !email.isEmpty, !pass.isEmpty else {
            errorMessage = "EMAIL AND PASSWORD REQUIRED"
            isLoading = false
            LogManager.shared.addLog("Signup failed: Empty email or password", level: .error, category: "AuthManager")
            return
        }
        
        // Validação de formato de email
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        guard emailPredicate.evaluate(with: email) else {
            errorMessage = "INVALID EMAIL FORMAT"
            isLoading = false
            LogManager.shared.addLog("Signup failed: Invalid email format", level: .error, category: "AuthManager")
            return
        }
        
        guard pass.count >= 6 else {
            errorMessage = "PASSWORD MUST BE AT LEAST 6 CHARACTERS"
            isLoading = false
            LogManager.shared.addLog("Signup failed: Password too short", level: .error, category: "AuthManager")
            return
        }
        
        // Use Firebase REST API for sign up
        let url = URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "email": email,
            "password": pass,
            "returnSecureToken": true
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        LogManager.shared.addLog("Sending signup request to Firebase", level: .info, category: "AuthManager")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    let errorMsg = "NETWORK ERROR :: \(error.localizedDescription.uppercased())"
                    self?.errorMessage = errorMsg
                    LogManager.shared.addLog("Signup network error: \(error.localizedDescription)", level: .error, category: "AuthManager")
                    return
                }
                
                guard let data = data else {
                    self?.errorMessage = "NO DATA RECEIVED"
                    LogManager.shared.addLog("Signup failed: No data received from Firebase", level: .error, category: "AuthManager")
                    return
                }
                
                // Log raw response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    LogManager.shared.addLog("Firebase response: \(responseString)", level: .debug, category: "AuthManager")
                }
                
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let errorData = json["error"] as? [String: Any],
                       let message = errorData["message"] as? String {
                        // Handle Firebase errors
                        LogManager.shared.addLog("Firebase error: \(message)", level: .error, category: "AuthManager")
                        switch message {
                        case "EMAIL_EXISTS":
                            self?.errorMessage = "EMAIL ALREADY IN USE :: TRY LOGGING IN INSTEAD"
                            LogManager.shared.addLog("Email already exists in Firebase. User may need to delete account from Firebase Console.", level: .warning, category: "AuthManager")
                        case "INVALID_EMAIL":
                            self?.errorMessage = "INVALID EMAIL FORMAT"
                        case "WEAK_PASSWORD":
                            self?.errorMessage = "PASSWORD TOO WEAK :: USE AT LEAST 6 CHARACTERS"
                        default:
                            self?.errorMessage = "ACCOUNT CREATION FAILED :: \(message)"
                        }
                    } else if let email = json["email"] as? String,
                              let uid = json["localId"] as? String,
                              let token = json["idToken"] as? String {
                        // Success!
                        LogManager.shared.addLog("Signup successful! Email: \(email), UID: \(uid)", level: .info, category: "AuthManager")
                        let user = User(email: email, uid: uid, idToken: token)
                        self?.saveUser(user)
                        
                        // Salvar nome do usuário se fornecido
                        if !name.isEmpty {
                            UserDefaults.standard.set(name, forKey: "user_name")
                            LogManager.shared.addLog("User name saved: \(name)", level: .info, category: "AuthManager")
                        }
                        
                        self?.errorMessage = nil
                        // Sincronizar tokens após signup
                        TokenService.shared.syncWithAPI(force: true)
                    } else {
                        LogManager.shared.addLog("Signup failed: Unexpected response format", level: .error, category: "AuthManager")
                    }
                } else {
                    LogManager.shared.addLog("Signup failed: Invalid JSON response", level: .error, category: "AuthManager")
                }
            }
        }.resume()
    }
    
    func signOut() {
        UserDefaults.standard.removeObject(forKey: "firebase_user")
        // Não remover o nome do usuário para manter personalização
        user = nil
        // Limpar dados de tokens ao fazer logout
        TokenService.shared.clearOnLogout()
    }
    
    // Retorna o nome do usuário salvo
    var userName: String? {
        UserDefaults.standard.string(forKey: "user_name")
    }
}
