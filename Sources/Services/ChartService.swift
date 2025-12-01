import Foundation
import SwiftUI

class ChartService: ObservableObject {
    static let shared = ChartService()
    
    @Published private(set) var charts: [GeneratedChart] = []
    @Published var isGenerating = false
    @Published var lastErrorMessage: String?
    
    private let storageURL: URL
    private let handlePrefix = "grafico"
    
    private init() {
        let supportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let appDirectory = supportDirectory?.appendingPathComponent("Rovena", isDirectory: true)
        if let appDirectory {
            try? FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)
            storageURL = appDirectory.appendingPathComponent("charts.json")
        } else {
            storageURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("charts.json")
        }
        
        loadCharts()
    }
    
    func createChart(
        title: String,
        description: String,
        chartType: ChartType,
        unit: String,
        rawData: String,
        completion: @escaping (Result<GeneratedChart, Error>) -> Void
    ) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitizedData = rawData.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedTitle.isEmpty else {
            completion(.failure(NSError(domain: "ChartService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Informe um título para o gráfico."])))
            return
        }
        
        guard !sanitizedData.isEmpty else {
            completion(.failure(NSError(domain: "ChartService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Adicione dados no formato Categoria:Valor por linha."])))
            return
        }
        
        let points = parseDataPoints(from: sanitizedData)
        guard !points.isEmpty else {
            completion(.failure(NSError(domain: "ChartService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Não foi possível interpretar os dados. Use o formato Categoria:Valor."])))
            return
        }
        
        isGenerating = true
        
        Task { @MainActor in
            var chart = GeneratedChart(
                handle: nextHandle(),
                title: trimmedTitle,
                description: trimmedDescription.isEmpty ? "Gráfico gerado manualmente" : trimmedDescription,
                chartType: chartType,
                unit: unit,
                dataPoints: points
            )
            
            if let base64 = ChartImageRenderer.exportBase64(for: chart) {
                chart.imageBase64 = base64
            }
            
            charts.append(chart)
            saveCharts()
            isGenerating = false
            completion(.success(chart))
        }
    }
    
    func deleteChart(_ chart: GeneratedChart) {
        charts.removeAll { $0.id == chart.id }
        saveCharts()
    }
    
    @MainActor
    func pngData(for chart: GeneratedChart) -> Data? {
        if let base64 = chart.imageBase64,
           let data = Data(base64Encoded: base64) {
            return data
        }
        
        guard let regeneratedBase64 = ChartImageRenderer.exportBase64(for: chart),
              let regeneratedData = Data(base64Encoded: regeneratedBase64) else {
            return nil
        }
        
        if let index = charts.firstIndex(where: { $0.id == chart.id }) {
            charts[index].imageBase64 = regeneratedBase64
            saveCharts()
        }
        
        return regeneratedData
    }
    
    func regenerateImage(for chart: GeneratedChart, completion: @escaping (GeneratedChart?) -> Void) {
        guard let index = charts.firstIndex(where: { $0.id == chart.id }) else {
            completion(nil)
            return
        }
        
        Task { @MainActor in
            var updatedChart = chart
            updatedChart.imageBase64 = ChartImageRenderer.exportBase64(for: chart)
            charts[index] = updatedChart
            saveCharts()
            completion(updatedChart)
        }
    }
    
    func replaceMentions(in markdown: String) -> String {
        guard !charts.isEmpty else { return markdown }
        
        var processedMarkdown = markdown
        for chart in charts {
            let token = chart.mentionToken
            guard processedMarkdown.contains(token), let base64 = chart.imageBase64 else { continue }
            let safeTitle = sanitizeMarkdownText(chart.title)
            let safeDescription = sanitizeMarkdownText(chart.description)
            let imageMarkdown = "![\(safeTitle)](data:image/png;base64,\(base64))\n\n> \(safeDescription)"
            processedMarkdown = processedMarkdown.replacingOccurrences(of: token, with: imageMarkdown)
        }
        
        return processedMarkdown
    }
    
    func chart(for mention: String) -> GeneratedChart? {
        let normalized = mention.replacingOccurrences(of: "@", with: "")
        return charts.first { $0.handle == normalized }
    }
    
    private func nextHandle() -> String {
        let numbers = charts.compactMap { chart -> Int? in
            let suffix = chart.handle.replacingOccurrences(of: handlePrefix, with: "")
            return Int(suffix)
        }
        let next = (numbers.max() ?? 0) + 1
        return "\(handlePrefix)\(next)"
    }
    
    private func parseDataPoints(from raw: String) -> [ChartDataPoint] {
        let lines = raw.split(separator: "\n")
        var result: [ChartDataPoint] = []
        
        for line in lines {
            let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true)
            if parts.count == 2 {
                let label = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
                let valueString = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
                if let value = Double(valueString) {
                    result.append(ChartDataPoint(label: label, value: value))
                }
            }
        }
        
        return result
    }
    
    private func loadCharts() {
        guard let data = try? Data(contentsOf: storageURL) else { return }
        if let decoded = try? JSONDecoder().decode([GeneratedChart].self, from: data) {
            charts = decoded
        }
    }
    
    private func saveCharts() {
        if let data = try? JSONEncoder().encode(charts) {
            try? data.write(to: storageURL)
        }
    }
    
    private func sanitizeMarkdownText(_ text: String) -> String {
        var sanitized = text.replacingOccurrences(of: "</textarea>", with: "&lt;/textarea&gt;")
        sanitized = sanitized.replacingOccurrences(of: "&", with: "&amp;")
        sanitized = sanitized.replacingOccurrences(of: "<", with: "&lt;")
        sanitized = sanitized.replacingOccurrences(of: ">", with: "&gt;")
        sanitized = sanitized.replacingOccurrences(of: "\"", with: "&quot;")
        sanitized = sanitized.replacingOccurrences(of: "'", with: "&#39;")
        return sanitized
    }
}

enum ChartRendererError: Error {
    case imageFailure
}

enum ChartImageRenderer {
    @MainActor
    static func exportBase64(for chart: GeneratedChart) -> String? {
        let view = ChartPreviewCard(chart: chart)
            .frame(width: 720, height: 420)
            .padding()
            .background(Color.white)
        
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        
        #if os(macOS)
        guard let nsImage = renderer.nsImage,
              let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }
        return pngData.base64EncodedString()
        #else
        return nil
        #endif
    }
}



