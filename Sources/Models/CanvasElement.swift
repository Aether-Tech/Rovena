import SwiftUI

enum CanvasTool: String, CaseIterable {
    case selection = "cursorarrow"
    case hand = "hand.raised"
    case brush = "paintbrush"
    case eraser = "eraser"
    case line = "line.diagonal"
    case rectangle = "rectangle"
    case circle = "circle"
    case text = "text.cursor"
}

struct CodableColor: Codable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double
    
    init(color: Color) {
        // Simplified color extraction for SwiftUI Color
        // Note: This works best with standard RGB colors. 
        // For production, use UIColor/NSColor bridge for robust extraction.
        // Here we use a simple fallback or mapping if possible, 
        // but SwiftUI Color doesn't easily expose components without NSColor/UIColor.
        
        // Using NSColor for macOS (VeroChat is macOS)
        if let nsColor = NSColor(color).usingColorSpace(.sRGB) {
            self.red = nsColor.redComponent
            self.green = nsColor.greenComponent
            self.blue = nsColor.blueComponent
            self.alpha = nsColor.alphaComponent
        } else {
            // Fallback to white
            self.red = 1
            self.green = 1
            self.blue = 1
            self.alpha = 1
        }
    }
    
    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }
}

struct CanvasElement: Identifiable, Codable {
    let id: UUID
    var type: ElementType
    var position: CGPoint
    var size: CGSize
    var codableColor: CodableColor
    var text: String?
    var points: [CGPoint]? // For brush
    
    var color: Color {
        get { codableColor.color }
        set { codableColor = CodableColor(color: newValue) }
    }
    
    init(type: ElementType, position: CGPoint = .zero, size: CGSize = CGSize(width: 100, height: 100), color: Color = .white, text: String? = nil, points: [CGPoint]? = nil) {
        self.id = UUID()
        self.type = type
        self.position = position
        self.size = size
        self.codableColor = CodableColor(color: color)
        self.text = text
        self.points = points
    }
    
    enum ElementType: String, Codable {
        case rectangle
        case circle
        case text
        case brush
        case line
    }
}
