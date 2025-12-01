import SwiftUI
import PhotosUI
import PDFKit
import UniformTypeIdentifiers
import AppKit

struct ChatView: View {
    @State private var prompt: String = ""
    @State private var messages: [ChatMessage] = []
    @State private var currentSessionId: UUID?
    @State private var retentionDays: Int = 7
    @State private var selectedModel: String = "gpt-4o"
    
    // Attachments
    @State private var isImporting: Bool = false
    @State private var selectedImageData: Data?
    @State private var attachedFileContent: String?
    @State private var attachedFileName: String?
    
    @ObservedObject var aiService = AIService.shared
    @ObservedObject var historyService = HistoryService.shared
    
    // Optional: Pass a session to view history
    var session: ChatSession?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(session?.name ?? "New Chat")
                    .font(DesignSystem.font(size: 14, weight: .semibold))
                    .foregroundColor(DesignSystem.text.opacity(0.7))
                
                Spacer()
                
                // Model Selector
                Picker("Model", selection: $selectedModel) {
                    ForEach(aiService.availableModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .pickerStyle(.menu)
                .tint(DesignSystem.accent)
                .scaleEffect(0.9)
                
                // Retention Dropdown
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundColor(DesignSystem.accent)
                    
                    Menu {
                        Picker("Retention", selection: $retentionDays) {
                            Text("1 Day").tag(1)
                            Text("3 Days").tag(3)
                            Text("7 Days (Default)").tag(7)
                            Text("30 Days").tag(30)
                            Text("Permanent").tag(3650) // 10 years
                        }
                    } label: {
                        Text("\(retentionDays) Days")
                            .font(DesignSystem.font(size: 12))
                            .foregroundColor(DesignSystem.accent)
                    }
                    .menuStyle(.borderlessButton)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(DesignSystem.surface.opacity(0.5))
                .clipShape(SquircleShape())
            }
            .padding()
            .background(DesignSystem.background)
            .overlay(Rectangle().frame(height: 0.5).foregroundColor(DesignSystem.border), alignment: .bottom)
            
            // Message List
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(messages) { msg in
                            MessageBubble(message: msg)
                        }
                        
                        if aiService.isProcessing {
                            ThinkingIndicator()
                                .id("thinking_indicator")
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) {
                    if let last = messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: aiService.isProcessing) {
                    if aiService.isProcessing {
                        withAnimation {
                            proxy.scrollTo("thinking_indicator", anchor: .bottom)
                        }
                    } else if let last = messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            .background(DesignSystem.background.opacity(0.95))
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                handleDrop(providers: providers)
            }
            
            // Input Area
            VStack(spacing: 0) {
                // Attachment Preview
                if let data = selectedImageData, let nsImage = NSImage(data: data) {
                    HStack {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 60)
                            .clipShape(SquircleShape())
                            .overlay(
                                Button(action: {
                                    selectedImageData = nil
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                        .background(Color.white.clipShape(Circle()))
                                }
                                .buttonStyle(.plain)
                                .padding(2),
                                alignment: .topTrailing
                            )
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                } else if let fileName = attachedFileName {
                     HStack {
                        Image(systemName: "doc.fill")
                             .foregroundColor(DesignSystem.accent)
                        Text(fileName)
                             .font(DesignSystem.font(size: 12))
                             .foregroundColor(DesignSystem.text)
                        
                         Button(action: {
                             attachedFileName = nil
                             attachedFileContent = nil
                         }) {
                             Image(systemName: "xmark.circle.fill")
                                 .foregroundColor(.gray)
                         }
                         .buttonStyle(.plain)
                         
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                
                HStack(spacing: 12) {
                    // Attachment Button
                    Button(action: {
                        isImporting = true
                    }) {
                        Image(systemName: "paperclip")
                            .font(.system(size: 18))
                            .foregroundColor((selectedImageData == nil && attachedFileName == nil) ? DesignSystem.text.opacity(0.5) : DesignSystem.accent)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .fileImporter(
                        isPresented: $isImporting,
                        allowedContentTypes: [.image, .pdf, .plainText],
                        allowsMultipleSelection: false
                    ) { result in
                        switch result {
                        case .success(let urls):
                            guard let url = urls.first else { return }
                            handleAttachment(url: url)
                        case .failure(let error):
                            print("Error selecting file: \(error.localizedDescription)")
                        }
                    }
                    
                    TextField("Message...", text: $prompt, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(DesignSystem.font(size: 14))
                        .foregroundColor(DesignSystem.text)
                        .lineLimit(1...8)
                        .padding(8)
                        .background(DesignSystem.surface.opacity(0.5))
                        .clipShape(SquircleShape())
                        .overlay(
                            SquircleShape()
                                .stroke(DesignSystem.border.opacity(0.5), lineWidth: 1)
                        )
                        .onKeyPress { press in
                            guard press.key == .return else { return .ignored }
                            if press.modifiers.contains(.shift) {
                                // Shift+Enter: allow line break
                                return .ignored
                            }
                            // Enter: send message
                            sendMessage()
                            return .handled
                        }
                    
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(prompt.isEmpty ? DesignSystem.text.opacity(0.2) : DesignSystem.accent)
                    }
                    .buttonStyle(.plain)
                    .disabled(prompt.isEmpty && selectedImageData == nil && attachedFileContent == nil)
                }
                .padding()
                .background(DesignSystem.background)
                .overlay(Rectangle().frame(height: 0.5).foregroundColor(DesignSystem.border), alignment: .top)
            }
        }
        .onAppear {
            initializeSession()
        }
        .onChange(of: retentionDays) {
            if let id = currentSessionId {
                historyService.updateRetention(for: id, days: retentionDays)
            }
        }
    }
    
    func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                _ = provider.loadObject(ofClass: URL.self) { url, error in
                    if let url = url {
                        DispatchQueue.main.async {
                            self.handleAttachment(url: url)
                        }
                    }
                }
                return true
            }
        }
        return false
    }
    
    func handleAttachment(url: URL) {
        if url.startAccessingSecurityScopedResource() {
            defer { url.stopAccessingSecurityScopedResource() }
            
            let fileType = url.pathExtension.lowercased()
            
            if ["jpg", "jpeg", "png", "heic", "gif", "bmp", "webp"].contains(fileType) {
                if let data = try? Data(contentsOf: url) {
                    selectedImageData = data
                    attachedFileContent = nil
                    attachedFileName = nil
                }
            } else if fileType == "pdf" {
                if let pdf = PDFDocument(url: url) {
                    attachedFileContent = pdf.string
                    attachedFileName = url.lastPathComponent
                    selectedImageData = nil
                }
            } else if ["txt", "md", "swift", "json", "py", "js", "ts", "html", "css", "xml"].contains(fileType) {
                if let content = try? String(contentsOf: url, encoding: .utf8) {
                    attachedFileContent = content
                    attachedFileName = url.lastPathComponent
                    selectedImageData = nil
                }
            }
        } else {
            // For drag & drop, we might not need security scoped access
            let fileType = url.pathExtension.lowercased()
            
            if ["jpg", "jpeg", "png", "heic", "gif", "bmp", "webp"].contains(fileType) {
                if let data = try? Data(contentsOf: url) {
                    selectedImageData = data
                    attachedFileContent = nil
                    attachedFileName = nil
                }
            } else if fileType == "pdf" {
                if let pdf = PDFDocument(url: url) {
                    attachedFileContent = pdf.string
                    attachedFileName = url.lastPathComponent
                    selectedImageData = nil
                }
            } else if ["txt", "md", "swift", "json", "py", "js", "ts", "html", "css", "xml"].contains(fileType) {
                if let content = try? String(contentsOf: url, encoding: .utf8) {
                    attachedFileContent = content
                    attachedFileName = url.lastPathComponent
                    selectedImageData = nil
                }
            }
        }
    }
    
    func initializeSession() {
        if let existingSession = session {
            // Load existing session
            self.currentSessionId = existingSession.id
            self.messages = existingSession.messages
            self.retentionDays = existingSession.retentionDays
            
            // Check if the last message was from user and needs a response (e.g. Quick Start)
            if let lastMsg = messages.last, lastMsg.role == .user {
                triggerAIResponse()
            }
        } else if messages.isEmpty {
            // New clean state
            messages = [ChatMessage(role: .system, content: "How can I help you today?")]
            retentionDays = 7
            currentSessionId = nil // Will be created on first message
        }
    }
    
    func triggerAIResponse() {
        guard let sessionId = currentSessionId else { return }
        let context = messages.suffix(10).map { $0 }
        
        aiService.sendMessage(Array(context), model: selectedModel) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    let aiMsg = ChatMessage(role: .assistant, content: response)
                    self.messages.append(aiMsg)
                    self.historyService.addMessage(aiMsg, to: sessionId)
                case .failure(let error):
                    let errorMsg = ChatMessage(role: .system, content: "Error: \(error.localizedDescription)")
                    self.messages.append(errorMsg)
                    self.historyService.addMessage(errorMsg, to: sessionId)
                }
            }
        }
    }
    
    func ensureSessionExists() {
        if currentSessionId == nil {
            let newSession = historyService.createNewSession()
            currentSessionId = newSession.id
            // Update the retention immediately if it was changed before first message
            historyService.updateRetention(for: newSession.id, days: retentionDays)
        }
    }
    
    func sendMessage() {
        guard !prompt.isEmpty || selectedImageData != nil || attachedFileContent != nil else { return }
        let input = prompt // Keep only the user's text, not file content
        let imageData = selectedImageData
        let fileContent = attachedFileContent
        let fileName = attachedFileName
        
        prompt = ""
        selectedImageData = nil
        attachedFileContent = nil
        attachedFileName = nil
        
        ensureSessionExists()
        guard let sessionId = currentSessionId else { return }
        
        // Create message with file info but without file content in visible text
        let userMsg = ChatMessage(role: .user, content: input, imageData: imageData, attachedFileName: fileName, attachedFileContent: fileContent)
        messages.append(userMsg)
        historyService.addMessage(userMsg, to: sessionId)
        
        // Image Generation Command
        if input.lowercased().hasPrefix("/image ") {
            let promptText = String(input.dropFirst(7))
            aiService.generateImage(prompt: promptText) { result in
                switch result {
                case .success(let url):
                    let aiMsg = ChatMessage(role: .assistant, content: "Generated Image: \(promptText)", imageURL: url)
                    messages.append(aiMsg)
                    historyService.addMessage(aiMsg, to: sessionId)
                case .failure(let error):
                    let errorMsg = ChatMessage(role: .system, content: "Error: \(error.localizedDescription)")
                    messages.append(errorMsg)
                    historyService.addMessage(errorMsg, to: sessionId)
                }
            }
            return
        }
        
        // Standard Chat
        let context = messages.suffix(10).map { $0 }
        
        aiService.sendMessage(Array(context), model: selectedModel) { result in
            switch result {
            case .success(let response):
                let aiMsg = ChatMessage(role: .assistant, content: response)
                messages.append(aiMsg)
                historyService.addMessage(aiMsg, to: sessionId)
            case .failure(let error):
                let errorMsg = ChatMessage(role: .system, content: "Error: \(error.localizedDescription)")
                messages.append(errorMsg)
                historyService.addMessage(errorMsg, to: sessionId)
            }
        }
    }
}

struct ThinkingIndicator: View {
    @State private var animationPhase = 0
    @State private var timer: Timer?
    
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text("AI is thinking")
                .font(DesignSystem.font(size: 12))
                .foregroundColor(DesignSystem.text.opacity(0.7))
            
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(DesignSystem.accent)
                        .frame(width: 4, height: 4)
                        .opacity(animationPhase == index ? 1.0 : 0.3)
                }
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    animationPhase = (animationPhase + 1) % 3
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
}

struct MarkdownText: View {
    let content: String
    
    var body: some View {
        if #available(macOS 12.0, *) {
            Text(parseMarkdown(content))
                .multilineTextAlignment(.leading)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            // Fallback for older macOS versions
            Text(content)
                .font(DesignSystem.font(size: 14))
                .foregroundColor(DesignSystem.text)
                .multilineTextAlignment(.leading)
        }
    }
    
    @available(macOS 12.0, *)
    func parseMarkdown(_ text: String) -> AttributedString {
        // Fix: Replace single newlines with "  \n" to force Markdown line breaks
        // This solves the "wall of text" issue
        let processedText = text.replacingOccurrences(of: "\n", with: "  \n")
        
        do {
            var options = AttributedString.MarkdownParsingOptions()
            options.interpretedSyntax = .full
            
            var attributedString = try AttributedString(markdown: processedText, options: options)
            
            // 1. Apply Base Global Styling
            let baseFont = NSFont(name: DesignSystem.fontName, size: 14) ?? .systemFont(ofSize: 14)
            attributedString.font = baseFont
            attributedString.foregroundColor = DesignSystem.text
            
            // 2. Iterate through runs to apply specific styles (Headers, Bold, Code)
            for run in attributedString.runs {
                let range = run.range
                
                // --- HEADERS ---
                if let intent = run.presentationIntent {
                    for component in intent.components {
                        switch component.kind {
                        case .header(let level):
                            let size: CGFloat = level == 1 ? 22 : (level == 2 ? 18 : 16)
                            if let headerFont = NSFont(name: DesignSystem.fontName, size: size) {
                                let boldHeader = NSFont(descriptor: headerFont.fontDescriptor.withSymbolicTraits(.bold), size: size) ?? headerFont
                                attributedString[range].font = boldHeader
                                attributedString[range].foregroundColor = DesignSystem.accent
                            }
                        default: break
                        }
                    }
                }
                
                // --- INLINE CODE (Single backtick) ---
                if run.inlinePresentationIntent?.contains(.code) == true {
                    attributedString[range].backgroundColor = DesignSystem.surface.opacity(0.2)
                    attributedString[range].foregroundColor = DesignSystem.accent
                    if let codeFont = NSFont(name: "Courier New", size: 13) {
                        attributedString[range].font = codeFont
                    }
                }
                
                // --- BOLD ---
                if run.inlinePresentationIntent?.contains(.stronglyEmphasized) == true {
                    attributedString[range].foregroundColor = DesignSystem.accent
                    // Use base font converted to bold
                    let descriptor = baseFont.fontDescriptor.withSymbolicTraits(.bold)
                    let boldFont = NSFont(descriptor: descriptor, size: baseFont.pointSize) ?? baseFont
                    attributedString[range].font = boldFont
                }
                
                // --- ITALIC ---
                if run.inlinePresentationIntent?.contains(.emphasized) == true {
                    // Use base font converted to italic
                    let descriptor = baseFont.fontDescriptor.withSymbolicTraits(.italic)
                    let italicFont = NSFont(descriptor: descriptor, size: baseFont.pointSize) ?? baseFont
                    attributedString[range].font = italicFont
                }
                
                // --- LINKS ---
                if run.link != nil {
                    attributedString[range].foregroundColor = .blue
                    attributedString[range].underlineStyle = .single
                }
            }
            
            return attributedString
        } catch {
            // Fallback if parsing fails
            return AttributedString(text)
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar / Icon
            ZStack {
                Circle()
                    .fill(avatarColor.opacity(0.1))
                    .frame(width: 32, height: 32)
                
                Text(avatarInitial)
                    .font(DesignSystem.font(size: 12, weight: .bold))
                    .foregroundColor(avatarColor)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                // Username
                Text(senderName)
                    .font(DesignSystem.font(size: 12, weight: .semibold))
                    .foregroundColor(DesignSystem.text.opacity(0.7))
                
                // Content
                VStack(alignment: .leading, spacing: 12) {
                    // File Tag (if file is attached)
                    if let fileName = message.attachedFileName {
                        FileTag(fileName: fileName)
                    }
                    
                    // Uploaded Image
                    if let data = message.imageData, let nsImage = NSImage(data: data) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 300)
                            .clipShape(SquircleShape())
                            .overlay(
                                SquircleShape()
                                    .stroke(DesignSystem.border, lineWidth: 0.5)
                            )
                    }
                    
                    if !message.content.isEmpty {
                        ForEach(MessageParser.parse(message.content)) { part in
                            switch part {
                            case .text(let text):
                                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    MarkdownText(content: text)
                                }
                            case .code(let lang, let code):
                                CodeBlockView(language: lang, code: code)
                            }
                        }
                    }
                    
                    // Generated Image
                    if let url = message.imageURL {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ProgressView().scaleEffect(0.5)
                            case .success(let image):
                                image.resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: 400)
                                .clipShape(SquircleShape())
                            case .failure:
                                HStack {
                                    Image(systemName: "exclamationmark.triangle")
                                    Text("Image failed to load")
                                }
                                .foregroundColor(.red)
                                .font(DesignSystem.font(size: 12))
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    var senderName: String {
        switch message.role {
        case .user: return "You"
        case .assistant: return "Rovena AI"
        case .system: return "System"
        }
    }
    
    var avatarInitial: String {
        switch message.role {
        case .user: return "Y"
        case .assistant: return "AI"
        case .system: return "S"
        }
    }
    
    var avatarColor: Color {
        switch message.role {
        case .user: return DesignSystem.accent
        case .assistant: return .purple
        case .system: return .gray
        }
    }
}

// MARK: - Code Block Support

struct CodeBlockView: View {
    let language: String
    let code: String
    @State private var isHovering = false
    @State private var isCopied = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(language.isEmpty ? "Code" : language)
                    .font(DesignSystem.font(size: 12, weight: .medium))
                    .foregroundColor(DesignSystem.text.opacity(0.7))
                
                Spacer()
                
                Button(action: {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(code, forType: .string)
                    withAnimation {
                        isCopied = true
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            isCopied = false
                        }
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        Text(isCopied ? "Copied" : "Copy")
                    }
                    .font(DesignSystem.font(size: 11))
                    .foregroundColor(isCopied ? .green : DesignSystem.text.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(DesignSystem.surface.opacity(0.5))
            .overlay(Rectangle().frame(height: 1).foregroundColor(DesignSystem.border.opacity(0.2)), alignment: .bottom)
            
            // Code Content
            ScrollView(.horizontal, showsIndicators: true) {
                Text(code)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(DesignSystem.text)
                    .padding(12)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignSystem.background.opacity(0.5))
        }
        .clipShape(SquircleShape())
        .overlay(
            SquircleShape()
                .stroke(DesignSystem.border.opacity(0.3), lineWidth: 1)
        )
        .padding(.vertical, 4)
    }
}

enum MessagePart: Identifiable {
    case text(String)
    case code(language: String, content: String)
    
    var id: String {
        switch self {
        case .text(let content): return "text-\(content.hashValue)"
        case .code(let language, let content): return "code-\(language)-\(content.hashValue)"
        }
    }
}

struct MessageParser {
    static func parse(_ content: String) -> [MessagePart] {
        var parts: [MessagePart] = []
        
        // Simple regex to find code blocks: ```language\ncode```
        // We use a simpler approach: split by ```
        
        let components = content.components(separatedBy: "```")
        
        for (index, component) in components.enumerated() {
            if index % 2 == 0 {
                // Even indices are regular text
                if !component.isEmpty {
                    parts.append(.text(component))
                }
            } else {
                // Odd indices are code blocks
                // Try to extract language from the first line
                let lines = component.components(separatedBy: "\n")
                
                var language = ""
                var code = component
                
                if let firstLine = lines.first, !firstLine.contains(" ") {
                    // Assume first line is language if it has no spaces
                    language = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
                    code = lines.dropFirst().joined(separator: "\n")
                }
                
                // Trim leading/trailing whitespace from code
                code = code.trimmingCharacters(in: .whitespacesAndNewlines)
                
                parts.append(.code(language: language, content: code))
            }
        }
        
        return parts
    }
}

// MARK: - File Tag Component

struct FileTag: View {
    let fileName: String
    
    var body: some View {
        HStack(spacing: 5) {
            Text("@")
                .font(DesignSystem.font(size: 12, weight: .semibold))
                .foregroundColor(DesignSystem.accent.opacity(0.8))
            
            Text(fileName)
                .font(DesignSystem.font(size: 12, weight: .medium))
                .foregroundColor(DesignSystem.text.opacity(0.85))
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(DesignSystem.surface.opacity(0.5))
        .clipShape(SquircleShape())
        .overlay(
            SquircleShape()
                .stroke(DesignSystem.border.opacity(0.2), lineWidth: 0.5)
        )
    }
}
