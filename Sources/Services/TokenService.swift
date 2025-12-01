import Foundation
import SwiftUI

class TokenService: ObservableObject {
    static let shared = TokenService()
    
    @Published var monthlyLimit: Int = 0 // Limite mensal do usuário
    @Published var tokensUsedLast30Days: Int = 0
    @Published var lastSyncDate: Date?
    @Published var currentPlan: String = "FREE" // Plano atual do usuário
    @Published var subscriptionStatus: String? // Status da assinatura (active, canceled, etc)
    @Published var isCancelingSubscription = false
    @Published var planChangedNotification: PlanChangeNotification? // Notificação quando plano muda
    
    private var usageHistory: TokenUsageHistory {
        didSet {
            saveUsageHistory()
            tokensUsedLast30Days = usageHistory.totalTokensInLast30Days()
        }
    }
    
    private let usageHistoryKey = "token_usage_history"
    private let monthlyLimitKey = "token_monthly_limit"
    private let lastSyncKey = "token_last_sync"
    
    private init() {
        // Carregar histórico salvo
        if let data = UserDefaults.standard.data(forKey: usageHistoryKey),
           let history = try? JSONDecoder().decode(TokenUsageHistory.self, from: data) {
            self.usageHistory = history
            self.tokensUsedLast30Days = history.totalTokensInLast30Days()
            self.lastSyncDate = history.lastSyncDate
        } else {
            self.usageHistory = TokenUsageHistory(dailyUsage: [:], lastSyncDate: nil)
        }
        
        // Carregar limite salvo
        self.monthlyLimit = UserDefaults.standard.integer(forKey: monthlyLimitKey)
        
        // Carregar plano salvo
        self.currentPlan = UserDefaults.standard.string(forKey: "token_current_plan") ?? "FREE"
        
        // Carregar limite baseado no plano
        if self.monthlyLimit == 0 {
            self.monthlyLimit = getLimitForPlan(self.currentPlan)
        }
        
        // Carregar status da assinatura
        if let status = UserDefaults.standard.string(forKey: "subscription_status") {
            self.subscriptionStatus = status
        }
        
        // Sincronizar com Stripe se necessário (a cada 5 minutos ou na inicialização)
        syncWithStripe()
    }
    
    // MARK: - Verificação de Limite
    
    /// Verifica se o usuário pode usar tokens adicionais
    func canUseTokens(_ estimatedTokens: Int = 0) -> Bool {
        guard monthlyLimit > 0 else {
            // Se não tem limite definido, permite (pode ser plano ilimitado ou ainda não sincronizado)
            return true
        }
        
        let currentUsage = tokensUsedLast30Days
        return (currentUsage + estimatedTokens) <= monthlyLimit
    }
    
    /// Retorna quantos tokens ainda podem ser usados
    func remainingTokens() -> Int {
        guard monthlyLimit > 0 else { return Int.max }
        return max(0, monthlyLimit - tokensUsedLast30Days)
    }
    
    /// Retorna a porcentagem de uso (0.0 a 1.0)
    func usagePercentage() -> Double {
        guard monthlyLimit > 0 else { return 0.0 }
        return min(1.0, Double(tokensUsedLast30Days) / Double(monthlyLimit))
    }
    
    /// Retorna a porcentagem restante (0.0 a 1.0)
    func remainingPercentage() -> Double {
        return max(0.0, 1.0 - usagePercentage())
    }
    
    // MARK: - Registro de Uso
    
    /// Registra uso de tokens localmente
    func recordTokenUsage(_ tokens: Int, for date: Date = Date()) {
        // Limpar entradas antigas antes de calcular (garante reset de 30 dias)
        var updatedHistory = usageHistory
        updatedHistory.cleanupOldEntries()
        usageHistory = updatedHistory
        
        let oldUsage = tokensUsedLast30Days
        usageHistory.addUsage(tokens, for: date)
        
        // Log quando registra uso
        LogManager.shared.addLog(
            "Recorded \(tokens) tokens (Total last 30 days: \(tokensUsedLast30Days)/\(monthlyLimit))",
            level: .debug,
            category: "TokenService"
        )
        
        // Verificar se atingiu o limite
        if monthlyLimit > 0 && tokensUsedLast30Days >= monthlyLimit && oldUsage < monthlyLimit {
            LogManager.shared.addLog(
                "⚠️ Token limit reached! Used: \(tokensUsedLast30Days)/\(monthlyLimit). Further requests will be blocked until reset (30 days from first usage).",
                level: .warning,
                category: "TokenService"
            )
        }
    }
    
    /// Registra uso de tokens a partir da resposta da API
    func recordUsageFromAPIResponse(_ response: [String: Any]) {
        // Tentar extrair usage da resposta OpenAI
        if let usage = response["usage"] as? [String: Any],
           let totalTokens = usage["total_tokens"] as? Int {
            recordTokenUsage(totalTokens)
        } else if let usage = response["usage"] as? [String: Any],
                  let totalTokens = usage["totalTokens"] as? Int {
            // Formato alternativo
            recordTokenUsage(totalTokens)
        }
    }
    
    // MARK: - Limites por Plano (Local)
    
    private func getLimitForPlan(_ plan: String) -> Int {
        switch plan.uppercased() {
        case "FREE":
            return 10_000 // 10k tokens/mês
        case "BASIC":
            return 500_000 // 500k tokens/mês
        case "PRO":
            return 3_000_000 // 3M tokens/mês
        case "ENTERPRISE":
            return -1 // Ilimitado
        default:
            return 10_000 // Default: FREE
        }
    }
    
    // MARK: - Sincronização Local (Stripe)
    
    /// Sincroniza plano e limite verificando assinatura no Stripe
    func syncWithStripe(force: Bool = false) {
        guard let email = AuthManager.shared.user?.email else {
            LogManager.shared.addLog("Cannot sync: No user email", level: .warning, category: "TokenService")
            return
        }
        
        LogManager.shared.addLog("Starting Stripe sync (force: \(force))", level: .info, category: "TokenService")
        
        // Não sincronizar muito frequentemente (a cada 5 minutos)
        if !force, let lastSync = lastSyncDate {
            let timeSinceLastSync = Date().timeIntervalSince(lastSync)
            if timeSinceLastSync < 300 { // 5 minutos
                return
            }
        }
        
        StripeService.shared.checkSubscription(email: email) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                switch result {
                case .success(let subscriptionInfo):
                    let oldPlan = self.currentPlan
                    let newPlan = subscriptionInfo.plan
                    let newLimit = self.getLimitForPlan(newPlan)
                    
                    // Atualizar plano
                    self.currentPlan = newPlan
                    self.monthlyLimit = newLimit
                    self.subscriptionStatus = subscriptionInfo.status
                    
                    // Salvar
                    UserDefaults.standard.set(newPlan, forKey: "token_current_plan")
                    UserDefaults.standard.set(newLimit, forKey: self.monthlyLimitKey)
                    UserDefaults.standard.set(subscriptionInfo.subscriptionId, forKey: "stripe_subscription_id")
                    UserDefaults.standard.set(subscriptionInfo.customerId, forKey: "stripe_customer_id")
                    
                    if oldPlan != newPlan {
                        LogManager.shared.addLog("Plan changed: \(oldPlan) → \(newPlan)", level: .info, category: "TokenService")
                        // Notificar mudança de plano para mostrar feedback ao usuário
                        self.planChangedNotification = PlanChangeNotification(
                            oldPlan: oldPlan,
                            newPlan: newPlan,
                            timestamp: Date()
                        )
                    }
                    
                    LogManager.shared.addLog(
                        "Stripe sync completed - Plan: \(newPlan), Limit: \(newLimit), Status: \(subscriptionInfo.status)",
                        level: .info,
                        category: "TokenService"
                    )
                    
                    self.lastSyncDate = Date()
                    self.usageHistory.lastSyncDate = Date()
                    self.saveUsageHistory()
                    
                case .failure(let error):
                    // Se não encontrou assinatura, manter plano atual ou definir como FREE
                    if (error as NSError).code == 404 {
                        // Nenhuma assinatura encontrada - manter plano atual ou FREE
                        if self.currentPlan == "FREE" {
                            LogManager.shared.addLog("No subscription found, keeping FREE plan", level: .info, category: "TokenService")
                        } else {
                            LogManager.shared.addLog("No active subscription found, but keeping current plan: \(self.currentPlan)", level: .warning, category: "TokenService")
                        }
                    } else {
                        let errorMsg = "Stripe sync error: \(error.localizedDescription)"
                        LogManager.shared.addLog(errorMsg, level: .error, category: "TokenService")
                    }
                }
            }
        }
    }
    
    // MARK: - Sincronização (Compatibilidade - mantém método antigo mas usa Stripe)
    
    /// Sincroniza limite e uso (agora usa Stripe diretamente)
    func syncWithAPI(force: Bool = false) {
        // Usar sincronização local com Stripe
        syncWithStripe(force: force)
    }
    
    // MARK: - Gerenciamento de Assinatura
    
    /// Cancela a assinatura do usuário (usando Stripe diretamente)
    func cancelSubscription(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let subscriptionId = UserDefaults.standard.string(forKey: "stripe_subscription_id"), !subscriptionId.isEmpty else {
            completion(.failure(NSError(domain: "TokenService", code: 404, userInfo: [NSLocalizedDescriptionKey: "No subscription found"])))
            return
        }
        
        isCancelingSubscription = true
        LogManager.shared.addLog("Canceling subscription: \(subscriptionId)", level: .info, category: "TokenService")
        
        StripeService.shared.cancelSubscription(subscriptionId: subscriptionId) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isCancelingSubscription = false
            }
            
            switch result {
            case .success:
                // Atualizar para FREE e sincronizar
                DispatchQueue.main.async {
                    self.currentPlan = "FREE"
                    self.monthlyLimit = self.getLimitForPlan("FREE")
                    self.subscriptionStatus = "canceled"
                    
                    UserDefaults.standard.set("FREE", forKey: "token_current_plan")
                    UserDefaults.standard.set(self.monthlyLimit, forKey: self.monthlyLimitKey)
                    
                    LogManager.shared.addLog("Subscription canceled successfully", level: .info, category: "TokenService")
                }
                completion(.success(()))
                
            case .failure(let error):
                let errorMsg = "Failed to cancel subscription: \(error.localizedDescription)"
                LogManager.shared.addLog(errorMsg, level: .error, category: "TokenService")
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Persistência
    
    private func saveUsageHistory() {
        if let data = try? JSONEncoder().encode(usageHistory) {
            UserDefaults.standard.set(data, forKey: usageHistoryKey)
        }
    }
    
    /// Limpa histórico quando usuário faz logout
    func clearOnLogout() {
        usageHistory = TokenUsageHistory(dailyUsage: [:], lastSyncDate: nil)
        monthlyLimit = 0
        tokensUsedLast30Days = 0
        lastSyncDate = nil
        currentPlan = "FREE"
        UserDefaults.standard.removeObject(forKey: usageHistoryKey)
        UserDefaults.standard.removeObject(forKey: monthlyLimitKey)
        UserDefaults.standard.removeObject(forKey: lastSyncKey)
        UserDefaults.standard.removeObject(forKey: "token_current_plan")
    }
}

// MARK: - Plan Change Notification

struct PlanChangeNotification: Identifiable {
    let id = UUID()
    let oldPlan: String
    let newPlan: String
    let timestamp: Date
    
    var message: String {
        if oldPlan == "FREE" {
            return "🎉 Welcome to \(newPlan)! Your subscription is now active."
        } else {
            return "✅ Plan updated: \(oldPlan) → \(newPlan)"
        }
    }
}

