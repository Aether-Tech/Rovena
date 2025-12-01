import Foundation

struct TokenUsage: Codable {
    let date: Date
    let tokensUsed: Int
    
    var dateKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

struct TokenUsageHistory: Codable {
    var dailyUsage: [String: Int] // [dateKey: tokensUsed]
    var lastSyncDate: Date?
    
    func totalTokensInLast30Days() -> Int {
        let calendar = Calendar.current
        let now = Date()
        var total = 0
        
        for (dateKey, tokens) in dailyUsage {
            if let date = parseDateKey(dateKey) {
                let daysAgo = calendar.dateComponents([.day], from: date, to: now).day ?? 0
                if daysAgo <= 30 {
                    total += tokens
                }
            }
        }
        
        return total
    }
    
    mutating func addUsage(_ tokens: Int, for date: Date = Date()) {
        let key = dateKey(for: date)
        dailyUsage[key, default: 0] += tokens
        
        // Limpar entradas antigas (mais de 30 dias)
        cleanupOldEntries()
    }
    
    mutating func cleanupOldEntries() {
        let calendar = Calendar.current
        let now = Date()
        let keysToRemove = dailyUsage.keys.filter { key in
            if let date = parseDateKey(key) {
                let daysAgo = calendar.dateComponents([.day], from: date, to: now).day ?? 0
                return daysAgo > 30
            }
            return false
        }
        
        for key in keysToRemove {
            dailyUsage.removeValue(forKey: key)
        }
    }
    
    private func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private func parseDateKey(_ key: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: key)
    }
}

