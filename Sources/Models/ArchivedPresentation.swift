import Foundation

struct ArchivedPresentation: Identifiable, Codable {
    struct Slide: Identifiable, Codable {
        let id: UUID
        var title: String
        var highlight: String?
        var content: String
        var imageURL: URL?
        var layout: String
        
        init(
            id: UUID = UUID(),
            title: String,
            highlight: String? = nil,
            content: String,
            imageURL: URL?,
            layout: String
        ) {
            self.id = id
            self.title = title
            self.highlight = highlight
            self.content = content
            self.imageURL = imageURL
            self.layout = layout
        }
    }
    
    let id: UUID
    var title: String
    var topic: String
    var createdAt: Date
    var markdown: String
    var slides: [Slide]
    
    init(
        id: UUID = UUID(),
        title: String,
        topic: String,
        createdAt: Date = Date(),
        markdown: String,
        slides: [Slide]
    ) {
        self.id = id
        self.title = title
        self.topic = topic
        self.createdAt = createdAt
        self.markdown = markdown
        self.slides = slides
    }
    
    var displaySubtitle: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
}


