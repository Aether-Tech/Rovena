import Foundation
import SwiftUI

class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var user: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
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
        
        guard !email.isEmpty, !pass.isEmpty else {
            errorMessage = "EMAIL AND PASSWORD REQUIRED"
            isLoading = false
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
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "NETWORK ERROR :: \(error.localizedDescription.uppercased())"
                    return
                }
                
                guard let data = data else {
                    self?.errorMessage = "NO DATA RECEIVED"
                    return
                }
                
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let errorData = json["error"] as? [String: Any],
                       let message = errorData["message"] as? String {
                        // Handle Firebase errors
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
                        let user = User(email: email, uid: uid, idToken: token)
                        self?.saveUser(user)
                        self?.errorMessage = nil
                    }
                }
            }
        }.resume()
    }
    
    func signUp(email: String, pass: String) {
        isLoading = true
        errorMessage = nil
        
        guard !email.isEmpty, !pass.isEmpty else {
            errorMessage = "EMAIL AND PASSWORD REQUIRED"
            isLoading = false
            return
        }
        
        guard pass.count >= 6 else {
            errorMessage = "PASSWORD MUST BE AT LEAST 6 CHARACTERS"
            isLoading = false
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
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "NETWORK ERROR :: \(error.localizedDescription.uppercased())"
                    return
                }
                
                guard let data = data else {
                    self?.errorMessage = "NO DATA RECEIVED"
                    return
                }
                
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let errorData = json["error"] as? [String: Any],
                       let message = errorData["message"] as? String {
                        // Handle Firebase errors
                        switch message {
                        case "EMAIL_EXISTS":
                            self?.errorMessage = "EMAIL ALREADY IN USE :: TRY LOGGING IN INSTEAD"
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
                        let user = User(email: email, uid: uid, idToken: token)
                        self?.saveUser(user)
                        self?.errorMessage = nil
                    }
                }
            }
        }.resume()
    }
    
    func signOut() {
        UserDefaults.standard.removeObject(forKey: "firebase_user")
        user = nil
    }
}
