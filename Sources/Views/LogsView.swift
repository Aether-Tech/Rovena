import SwiftUI
import AppKit

class LogManager: ObservableObject {
    static let shared = LogManager()
    
    @Published var logs: [LogEntry] = []
    private var logBuffer: [LogEntry] = []
    private let maxLogs = 1000
    
    private init() {
        // Capturar logs do sistema
        setupLogCapture()
    }
    
    func addLog(_ message: String, level: LogLevel = .info, category: String = "App") {
        let entry = LogEntry(
            timestamp: Date(),
            message: message,
            level: level,
            category: category
        )
        
        DispatchQueue.main.async {
            self.logs.append(entry)
            self.logBuffer.append(entry)
            
            // Manter apenas os últimos N logs
            if self.logs.count > self.maxLogs {
                self.logs.removeFirst()
            }
            if self.logBuffer.count > self.maxLogs {
                self.logBuffer.removeFirst()
            }
        }
        
        // Também imprimir no console
        print("[\(category)] [\(level.rawValue)] \(message)")
    }
    
    func exportLogs() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        let logText = logBuffer.map { entry in
            let timestamp = dateFormatter.string(from: entry.timestamp)
            return "[\(timestamp)] [\(entry.level.rawValue.uppercased())] [\(entry.category)] \(entry.message)"
        }.joined(separator: "\n")
        
        return """
        === ROVENA APP LOGS ===
        Generated: \(Date().formatted(date: .complete, time: .complete))
        Total Logs: \(logBuffer.count)
        
        === LOGS ===
        \(logText)
        """
    }
    
    func copyLogsToClipboard() {
        let logText = exportLogs()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(logText, forType: .string)
    }
    
    func clearLogs() {
        DispatchQueue.main.async {
            self.logs.removeAll()
            self.logBuffer.removeAll()
        }
    }
    
    private func setupLogCapture() {
        // Adicionar log inicial
        addLog("LogManager initialized", level: .info, category: "System")
    }
}

struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String
    let level: LogLevel
    let category: String
}

enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    
    var color: Color {
        switch self {
        case .debug: return .gray
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }
}

struct LogsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var logManager = LogManager.shared
    @State private var selectedLevel: LogLevel? = nil
    @State private var searchText: String = ""
    @State private var showExportAlert = false
    @State private var exportMessage = ""
    
    var filteredLogs: [LogEntry] {
        var logs = logManager.logs
        
        // Filtrar por nível
        if let level = selectedLevel {
            logs = logs.filter { $0.level == level }
        }
        
        // Filtrar por busca
        if !searchText.isEmpty {
            logs = logs.filter {
                $0.message.localizedCaseInsensitiveContains(searchText) ||
                $0.category.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return logs.reversed() // Mais recentes primeiro
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Logs")
                    .font(DesignSystem.font(size: 24, weight: .bold))
                    .foregroundColor(DesignSystem.text)
                
                Spacer()
                
                // Actions
                HStack(spacing: 12) {
                    // Close Button
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(DesignSystem.text.opacity(0.6))
                            .background(DesignSystem.background)
                    }
                    .buttonStyle(.plain)
                    .help("Close (Esc)")
                    
                    // Search
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(DesignSystem.text.opacity(0.5))
                        TextField("Search logs...", text: $searchText)
                            .textFieldStyle(.plain)
                            .font(DesignSystem.font(size: 12))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(DesignSystem.surface.opacity(0.5))
                    .clipShape(SquircleShape())
                    .frame(width: 200)
                    
                    // Level Filter
                    Menu {
                        Button("All Levels") {
                            selectedLevel = nil
                        }
                        Divider()
                        ForEach([LogLevel.debug, .info, .warning, .error], id: \.self) { level in
                            Button(level.rawValue) {
                                selectedLevel = level
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                            Text(selectedLevel?.rawValue ?? "All")
                        }
                        .font(DesignSystem.font(size: 12))
                        .foregroundColor(DesignSystem.text)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(DesignSystem.surface.opacity(0.5))
                        .clipShape(SquircleShape())
                    }
                    
                    // Clear
                    Button(action: {
                        logManager.clearLogs()
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .padding(8)
                            .background(Color.red.opacity(0.1))
                            .clipShape(SquircleShape())
                    }
                    .buttonStyle(.plain)
                    
                    // Copy
                    Button(action: {
                        logManager.copyLogsToClipboard()
                        exportMessage = "Logs copied to clipboard!"
                        showExportAlert = true
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 14))
                            .foregroundColor(DesignSystem.accent)
                            .padding(8)
                            .background(DesignSystem.accent.opacity(0.1))
                            .clipShape(SquircleShape())
                    }
                    .buttonStyle(.plain)
                    
                    // Export
                    Button(action: {
                        exportLogs()
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14))
                            .foregroundColor(DesignSystem.accent)
                            .padding(8)
                            .background(DesignSystem.accent.opacity(0.1))
                            .clipShape(SquircleShape())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(DesignSystem.background)
            .overlay(Rectangle().frame(height: 0.5).foregroundColor(DesignSystem.border), alignment: .bottom)
            
            // Logs List
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    if filteredLogs.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 48))
                                .foregroundColor(DesignSystem.text.opacity(0.3))
                            Text("No logs found")
                                .font(DesignSystem.font(size: 14))
                                .foregroundColor(DesignSystem.text.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 100)
                    } else {
                        ForEach(filteredLogs) { entry in
                            LogRow(entry: entry)
                        }
                    }
                }
                .padding()
            }
            .background(DesignSystem.background.opacity(0.95))
        }
        .background(DesignSystem.background)
        .alert("Export", isPresented: $showExportAlert) {
            Button("OK") { }
        } message: {
            Text(exportMessage)
        }
        .onAppear {
            // Adicionar log de abertura
            logManager.addLog("LogsView opened", level: .info, category: "UI")
        }
    }
    
    private func exportLogs() {
        let logText = logManager.exportLogs()
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "rovena-logs-\(Date().formatted(date: .numeric, time: .omitted)).txt"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try logText.write(to: url, atomically: true, encoding: .utf8)
                    DispatchQueue.main.async {
                        exportMessage = "Logs exported to \(url.lastPathComponent)"
                        showExportAlert = true
                    }
                } catch {
                    DispatchQueue.main.async {
                        exportMessage = "Error exporting logs: \(error.localizedDescription)"
                        showExportAlert = true
                    }
                }
            }
        }
    }
}

struct LogRow: View {
    let entry: LogEntry
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Timestamp
            Text(dateFormatter.string(from: entry.timestamp))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(DesignSystem.text.opacity(0.5))
                .frame(width: 70, alignment: .leading)
            
            // Level Badge
            Text(entry.level.rawValue)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(entry.level.color)
                .clipShape(SquircleShape())
                .frame(width: 60)
            
            // Category
            Text("[\(entry.category)]")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(DesignSystem.accent)
                .frame(width: 100, alignment: .leading)
            
            // Message
            Text(entry.message)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(DesignSystem.text)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(entry.level == .error ? Color.red.opacity(0.05) : Color.clear)
    }
}


