import Foundation
import SwiftUI

// Modelo para elementos editáveis em um slide
struct EditableElement: Identifiable, Codable {
    enum ElementType: String, Codable {
        case text
        case image
        case subtitle
    }
    
    let id: UUID
    var type: ElementType
    var content: String // Texto ou URL da imagem
    var position: CodablePoint
    var size: CodableSize
    var fontSize: CGFloat?
    var fontWeight: String?
    var color: String? // Hex color
    var rotation: CGFloat? // Rotação em graus
    var zIndex: Int
    
    init(
        id: UUID = UUID(),
        type: ElementType,
        content: String,
        position: CodablePoint = CodablePoint(.zero),
        size: CodableSize = CodableSize(CGSize(width: 200, height: 50)),
        fontSize: CGFloat? = nil,
        fontWeight: String? = nil,
        color: String? = nil,
        rotation: CGFloat? = nil,
        zIndex: Int = 0
    ) {
        self.id = id
        self.type = type
        self.content = content
        self.position = position
        self.size = size
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.color = color
        self.rotation = rotation
        self.zIndex = zIndex
    }
}

// Modelo para slide editável
struct EditableSlide: Identifiable, Codable {
    let id: UUID
    var title: String
    var elements: [EditableElement]
    var backgroundColor: String? // Hex color
    var layout: String
    
    init(
        id: UUID = UUID(),
        title: String,
        elements: [EditableElement] = [],
        backgroundColor: String? = nil,
        layout: String = "default"
    ) {
        self.id = id
        self.title = title
        self.elements = elements
        self.backgroundColor = backgroundColor
        self.layout = layout
    }
}

// Modelo para apresentação editável
struct EditablePresentation: Identifiable, Codable {
    let id: UUID
    var title: String
    var topic: String
    var slides: [EditableSlide]
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        title: String,
        topic: String,
        slides: [EditableSlide] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.topic = topic
        self.slides = slides
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// Wrappers para serialização
struct CodablePoint: Codable {
    var x: CGFloat
    var y: CGFloat
    
    init(_ point: CGPoint) {
        self.x = point.x
        self.y = point.y
    }
    
    var cgPoint: CGPoint {
        CGPoint(x: x, y: y)
    }
}

struct CodableSize: Codable {
    var width: CGFloat
    var height: CGFloat
    
    init(_ size: CGSize) {
        self.width = size.width
        self.height = size.height
    }
    
    var cgSize: CGSize {
        CGSize(width: width, height: height)
    }
}

