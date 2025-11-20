import Foundation

struct ChatSession: Identifiable, Codable {
    let id: UUID
    var name: String
    var messages: [ChatMessage]
    let creationDate: Date
    var retentionDays: Int
    
    var expirationDate: Date {
        return Calendar.current.date(byAdding: .day, value: retentionDays, to: creationDate) ?? creationDate
    }
    
    var isExpired: Bool {
        return Date() > expirationDate
    }
    
    init(id: UUID = UUID(), name: String = "New Chat", messages: [ChatMessage] = [], creationDate: Date = Date(), retentionDays: Int = 7) {
        self.id = id
        self.name = name
        self.messages = messages
        self.creationDate = creationDate
        self.retentionDays = retentionDays
    }
}

