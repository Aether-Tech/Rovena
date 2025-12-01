import Foundation

// LogManager está definido em LogsView.swift, mas precisamos acessá-lo
// Vamos usar print por enquanto e depois ajustar se necessário

class StripeService {
    static let shared = StripeService()
    
    // Product ID da assinatura Rovena+
    private let ROVENA_PLUS_PRODUCT_ID = "prod_TV9GzjLJOU202c"
    
    // Stripe Secret Key (deve ser configurada nas Settings ou Config.plist)
    private var stripeSecretKey: String {
        // Primeiro tenta variável de ambiente
        if let envKey = ProcessInfo.processInfo.environment["STRIPE_SECRET_KEY"], !envKey.isEmpty {
            print("[StripeService] Stripe key loaded from environment variable")
            return envKey
        }
        
        // Depois tenta Config.plist
        if let configPath = Bundle.main.path(forResource: "Config", ofType: "plist") {
            print("[StripeService] Config.plist found at: \(configPath)")
            
            if let configDict = NSDictionary(contentsOfFile: configPath) {
                let allKeys = configDict.allKeys as? [String] ?? []
                print("[StripeService] Config.plist keys: \(allKeys.joined(separator: ", "))")
                
                if let apiKey = configDict["STRIPE_SECRET_KEY"] as? String, !apiKey.isEmpty {
                    print("[StripeService] ✅ Stripe key loaded from Config.plist (length: \(apiKey.count))")
                    return apiKey
                } else {
                    print("[StripeService] ⚠️ STRIPE_SECRET_KEY not found in Config.plist or is empty")
                    // Debug: mostrar o que tem no dict
                    if let value = configDict["STRIPE_SECRET_KEY"] {
                        print("[StripeService] Value type: \(type(of: value)), Value: \(value)")
                    }
                }
            } else {
                print("[StripeService] ❌ Failed to read Config.plist as NSDictionary")
            }
        } else {
            print("[StripeService] ⚠️ Config.plist not found in bundle")
            // Listar todos os recursos do bundle para debug
            if let resourcePath = Bundle.main.resourcePath {
                print("[StripeService] Bundle resource path: \(resourcePath)")
                if let contents = try? FileManager.default.contentsOfDirectory(atPath: resourcePath) {
                    print("[StripeService] Bundle contents: \(contents.joined(separator: ", "))")
                }
            }
        }
        
        print("[StripeService] ❌ Stripe Secret Key not configured")
        return ""
    }
    
    private init() {}
    
    /// Verifica assinatura ativa no Stripe pelo email
    func checkSubscription(email: String, completion: @escaping (Result<SubscriptionInfo, Error>) -> Void) {
        guard !stripeSecretKey.isEmpty else {
            completion(.failure(NSError(domain: "StripeService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Stripe Secret Key not configured"])))
            return
        }
        
        // Buscar customer pelo email
        findCustomerByEmail(email: email) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let customerId):
                // Buscar assinaturas do customer
                self.findActiveSubscription(customerId: customerId, completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    private func findCustomerByEmail(email: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard !stripeSecretKey.isEmpty else {
            completion(.failure(NSError(domain: "StripeService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Stripe Secret Key not configured"])))
            return
        }
        
        let url = URL(string: "https://api.stripe.com/v1/customers?email=\(email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? email)&limit=1")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(stripeSecretKey)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let customers = json["data"] as? [[String: Any]],
                  let firstCustomer = customers.first,
                  let customerId = firstCustomer["id"] as? String else {
                completion(.failure(NSError(domain: "StripeService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Customer not found"])))
                return
            }
            
            completion(.success(customerId))
        }.resume()
    }
    
    private func findActiveSubscription(customerId: String, completion: @escaping (Result<SubscriptionInfo, Error>) -> Void) {
        guard !stripeSecretKey.isEmpty else {
            completion(.failure(NSError(domain: "StripeService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Stripe Secret Key not configured"])))
            return
        }
        
        let url = URL(string: "https://api.stripe.com/v1/subscriptions?customer=\(customerId)&status=all&limit=10")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(stripeSecretKey)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let subscriptions = json["data"] as? [[String: Any]] else {
                completion(.failure(NSError(domain: "StripeService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                return
            }
            
            // Buscar assinatura ativa do Rovena+
            for subData in subscriptions {
                guard let status = subData["status"] as? String,
                      (status == "active" || status == "trialing"),
                      let items = subData["items"] as? [String: Any],
                      let itemsData = items["data"] as? [[String: Any]] else {
                    continue
                }
                
                // Verificar se tem item do produto Rovena+
                for item in itemsData {
                    guard let price = item["price"] as? [String: Any],
                          let productId = price["product"] as? String,
                          productId == self.ROVENA_PLUS_PRODUCT_ID else {
                        continue
                    }
                    
                    let priceId = price["id"] as? String ?? ""
                    let priceAmount = price["unit_amount"] as? Int ?? 0
                    let priceNickname = price["nickname"] as? String ?? ""
                    
                    // Mapear para plano
                    let plan = self.mapToPlan(priceId: priceId, amount: priceAmount, nickname: priceNickname)
                    
                    let subscriptionInfo = SubscriptionInfo(
                        subscriptionId: subData["id"] as? String ?? "",
                        customerId: customerId,
                        plan: plan,
                        status: status,
                        priceId: priceId,
                        amount: priceAmount
                    )
                    
                    completion(.success(subscriptionInfo))
                    return
                }
            }
            
            // Nenhuma assinatura ativa encontrada
            completion(.failure(NSError(domain: "StripeService", code: 404, userInfo: [NSLocalizedDescriptionKey: "No active subscription found"])))
        }.resume()
    }
    
    private func mapToPlan(priceId: String, amount: Int, nickname: String) -> String {
        // Mapear por valor (em centavos)
        let amountInReais = Double(amount) / 100.0
        
        if amountInReais >= 299 {
            return "ENTERPRISE"
        } else if amountInReais >= 90 { // R$ 90+ = PRO (R$ 100)
            return "PRO"
        } else if amountInReais >= 25 { // R$ 25+ = BASIC (R$ 29-39)
            return "BASIC"
        }
        
        // Verificar por priceId
        let priceIdLower = priceId.lowercased()
        if priceIdLower.contains("enterprise") {
            return "ENTERPRISE"
        } else if priceIdLower.contains("pro") || priceIdLower.contains("100") {
            return "PRO"
        } else if priceIdLower.contains("basic") || priceIdLower.contains("29") || priceIdLower.contains("39") {
            return "BASIC"
        }
        
        // Verificar por nickname
        let nicknameLower = nickname.lowercased()
        if nicknameLower.contains("enterprise") {
            return "ENTERPRISE"
        } else if nicknameLower.contains("pro") {
            return "PRO"
        } else if nicknameLower.contains("basic") {
            return "BASIC"
        }
        
        // Default
        return "BASIC"
    }
    
    /// Cancela assinatura no Stripe
    func cancelSubscription(subscriptionId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard !stripeSecretKey.isEmpty else {
            completion(.failure(NSError(domain: "StripeService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Stripe Secret Key not configured"])))
            return
        }
        
        let url = URL(string: "https://api.stripe.com/v1/subscriptions/\(subscriptionId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.addValue("Bearer \(stripeSecretKey)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(NSError(domain: "StripeService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to cancel subscription"])))
                return
            }
            
            completion(.success(()))
        }.resume()
    }
}

struct SubscriptionInfo {
    let subscriptionId: String
    let customerId: String
    let plan: String
    let status: String
    let priceId: String
    let amount: Int // em centavos
}

