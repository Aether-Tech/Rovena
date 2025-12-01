import Foundation

struct ChartDataPoint: Identifiable, Codable {
    let id: UUID
    var label: String
    var value: Double
    
    init(id: UUID = UUID(), label: String, value: Double) {
        self.id = id
        self.label = label
        self.value = value
    }
}

enum ChartType: String, CaseIterable, Codable, Identifiable {
    case bar
    case line
    case area
    case pie
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .bar: return "Barras"
        case .line: return "Linha"
        case .area: return "Área"
        case .pie: return "Pizza"
        }
    }
}

struct GeneratedChart: Identifiable, Codable {
    let id: UUID
    var handle: String
    var title: String
    var description: String
    var chartType: ChartType
    var unit: String
    var dataPoints: [ChartDataPoint]
    var imageBase64: String?
    
    init(
        id: UUID = UUID(),
        handle: String,
        title: String,
        description: String,
        chartType: ChartType,
        unit: String = "",
        dataPoints: [ChartDataPoint],
        imageBase64: String? = nil
    ) {
        self.id = id
        self.handle = handle
        self.title = title
        self.description = description
        self.chartType = chartType
        self.unit = unit
        self.dataPoints = dataPoints
        self.imageBase64 = imageBase64
    }
    
    var mentionToken: String {
        "@\(handle)"
    }
    
    var isRenderable: Bool {
        imageBase64 != nil && !imageBase64!.isEmpty
    }
}



