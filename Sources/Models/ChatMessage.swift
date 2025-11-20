import Foundation

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let role: Role
    let content: String
    let imageURL: URL? // For generated images (DALL-E) or remote
    let imageData: Data? // For user uploaded images (local)
    let timestamp: Date
    var hasAnimated: Bool = false
    
    enum Role: String, Codable {
        case user
        case assistant
        case system
    }
    
    init(role: Role, content: String, imageURL: URL? = nil, imageData: Data? = nil, hasAnimated: Bool = false) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.imageURL = imageURL
        self.imageData = imageData
        self.timestamp = Date()
        self.hasAnimated = hasAnimated
    }
}
