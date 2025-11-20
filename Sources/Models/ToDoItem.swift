import Foundation

struct ToDoItem: Identifiable, Codable {
    let id: UUID
    var content: String
    var description: String
    var isCompleted: Bool
    let createdAt: Date
    
    init(id: UUID = UUID(), content: String, description: String = "", isCompleted: Bool = false, createdAt: Date = Date()) {
        self.id = id
        self.content = content
        self.description = description
        self.isCompleted = isCompleted
        self.createdAt = createdAt
    }
}

