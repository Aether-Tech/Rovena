import SwiftUI
import WebKit
import AppKit

enum ImageStyleOption: String, CaseIterable, Identifiable {
    case realism
    case cinematic
    case watercolor
    case modernMinimal
    case cyberpunk
    case collage
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .realism: return "Realismo fotográfico"
        case .cinematic: return "Cinemático"
        case .watercolor: return "Aquarela artística"
        case .modernMinimal: return "Minimalista moderno"
        case .cyberpunk: return "Cyberpunk neon"
        case .collage: return "Colagem editorial"
        }
    }
    
    var promptDescription: String {
        switch self {
        case .realism: return "realistic photography with natural lighting and authentic people"
        case .cinematic: return "cinematic still with dramatic lighting and shallow depth of field"
        case .watercolor: return "watercolor illustration with soft gradients and paper texture"
        case .modernMinimal: return "minimalist flat illustration, clean vector shapes, muted palette"
        case .cyberpunk: return "futuristic cyberpunk aesthetic, neon lights, high contrast, moody atmosphere"
        case .collage: return "editorial collage mixing photography and graphic shapes with bold typography"
        }
    }
}

enum PresentationLanguageOption: String, CaseIterable, Identifiable {
    case portugueseBR = "pt-BR"
    case englishUS = "en-US"
    case spanish = "es-ES"
    case french = "fr-FR"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .portugueseBR: return "Português (Brasil)"
        case .englishUS: return "Inglês (EUA)"
        case .spanish: return "Espanhol"
        case .french: return "Francês"
        }
    }
    
    var promptName: String {
        switch self {
        case .portugueseBR: return "Português brasileiro"
        case .englishUS: return "English (United States)"
        case .spanish: return "Español"
        case .french: return "Français"
        }
    }
    
    var localeCode: String { rawValue }
}

// MARK: - Legacy PresentationView (mantido para compatibilidade)
// Nova implementação está em PresentationMainView

struct PresentationView: View {
    @State private var prompt: String = ""
    @State private var generatedMarkdown: String?
    @State private var editableSlides: [PresentationService.SlideContent] = []
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var debugLog: String = ""
    @State private var showDebugLog = false
    @State private var selectedImageStyle: ImageStyleOption = .realism
    @State private var selectedLanguage: PresentationLanguageOption = .portugueseBR
    @State private var mentionQuery: String?
    
    @ObservedObject var presentationService = PresentationService.shared
    @ObservedObject var chartService = ChartService.shared
    
    var body: some View {
        HStack(spacing: 0) {
            // Left Panel: Input & Editor
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Presentation Generator")
                        .font(DesignSystem.font(size: 14, weight: .semibold))
                        .foregroundColor(DesignSystem.text.opacity(0.7))
                    
                    Spacer()
                    
                    if generatedMarkdown != nil {
                        Button(action: {
                            generatedMarkdown = nil
                            editableSlides.removeAll()
                        }) {
                            Image(systemName: "plus.circle")
                            Text("New")
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(DesignSystem.accent)
                    }
                    
                    Button(action: { showDebugLog.toggle() }) {
                        Image(systemName: showDebugLog ? "eye.slash" : "eye")
                        Text("Debug")
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(DesignSystem.text.opacity(0.5))
                }
                .padding()
                .background(DesignSystem.background)
                .overlay(Rectangle().frame(height: 0.5).foregroundColor(DesignSystem.border), alignment: .bottom)
                
                // Content
                if generatedMarkdown == nil {
                    inputView
                } else {
                    editorView
                }
            }
            .frame(maxWidth: 400)
            .background(DesignSystem.background)
            .overlay(Rectangle().frame(width: 0.5).foregroundColor(DesignSystem.border), alignment: .trailing)
            
            // Right Panel: Preview or Debug Log
            VStack(spacing: 0) {
                // Preview Header
                HStack {
                    Text(showDebugLog ? "Debug Log" : "Preview")
                        .font(DesignSystem.font(size: 14, weight: .semibold))
                        .foregroundColor(DesignSystem.text.opacity(0.7))
                    Spacer()
                    
                    if !showDebugLog {
                        Button(action: exportPDF) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Export PDF")
                            }
                            .padding(6)
                            .background(DesignSystem.accent)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        .disabled(generatedMarkdown == nil)
                        .opacity(generatedMarkdown == nil ? 0.5 : 1)
                    }
                }
                .padding()
                .background(DesignSystem.surface)
                .overlay(Rectangle().frame(height: 0.5).foregroundColor(DesignSystem.border), alignment: .bottom)
                
                // Preview or Debug Content
                if showDebugLog {
                    ScrollView {
                        Text(debugLog.isEmpty ? "No logs yet. Try generating a presentation." : debugLog)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(DesignSystem.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .textSelection(.enabled)
                    }
                    .background(DesignSystem.background)
                } else if let markdown = generatedMarkdown {
                    MarpPreview(markdown: chartService.replaceMentions(in: markdown))
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "doc.richtext")
                            .font(.system(size: 48))
                            .foregroundColor(DesignSystem.text.opacity(0.2))
                        Text("Your presentation slides will appear here")
                            .font(DesignSystem.font(size: 14))
                            .foregroundColor(DesignSystem.text.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DesignSystem.surface.opacity(0.5))
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    var inputView: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .font(.system(size: 40))
                        .foregroundColor(DesignSystem.accent)
                        .padding()
                        .background(DesignSystem.accent.opacity(0.1))
                        .clipShape(Circle())
                    
                    Text("AI Presentation Builder")
                        .font(DesignSystem.font(size: 20, weight: .bold))
                        .foregroundColor(DesignSystem.text)
                    
                    Text("Describe your topic, and I'll generate the structure, content, and images for you.")
                        .font(DesignSystem.font(size: 14))
                        .foregroundColor(DesignSystem.text.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 20)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Topic")
                        .font(DesignSystem.font(size: 12, weight: .medium))
                        .foregroundColor(DesignSystem.text.opacity(0.7))
                    
                    TextEditor(text: $prompt)
                        .font(DesignSystem.font(size: 14))
                        .foregroundColor(DesignSystem.text)
                        .frame(height: 100)
                        .padding(8)
                        .background(DesignSystem.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(DesignSystem.border.opacity(0.5), lineWidth: 1)
                        )
                        .scrollContentBackground(.hidden)
                        .onChange(of: prompt) { _, newValue in
                            updatePromptMentionState(with: newValue)
                        }
                    
                    mentionSuggestionMenu
                    
                    mentionTagSection
                }
                .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Preferências")
                        .font(DesignSystem.font(size: 12, weight: .medium))
                        .foregroundColor(DesignSystem.text.opacity(0.7))
                        .padding(.leading)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Estilo das imagens")
                                .font(DesignSystem.font(size: 12))
                                .foregroundColor(DesignSystem.text.opacity(0.7))
                            Spacer()
                            Picker("Estilo das imagens", selection: $selectedImageStyle) {
                                ForEach(ImageStyleOption.allCases) { option in
                                    Text(option.displayName).tag(option)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                        }
                        
                        HStack {
                            Text("Idioma")
                                .font(DesignSystem.font(size: 12))
                                .foregroundColor(DesignSystem.text.opacity(0.7))
                            Spacer()
                            Picker("Idioma", selection: $selectedLanguage) {
                                ForEach(PresentationLanguageOption.allCases) { option in
                                    Text(option.displayName).tag(option)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                        }
                    }
                    .padding(12)
                    .background(DesignSystem.surface.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal)
                }
                
                ChartGeneratorView()
                    .padding(.horizontal)
                
                Button(action: generatePresentation) {
                    HStack {
                        if presentationService.isGenerating {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        } else {
                            Image(systemName: "wand.and.stars")
                        }
                        Text(presentationService.isGenerating ? "Generating..." : "Create Slides")
                    }
                    .font(DesignSystem.font(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(prompt.isEmpty ? Color.gray : DesignSystem.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(radius: 2)
                }
                .buttonStyle(.plain)
                .disabled(prompt.isEmpty || presentationService.isGenerating)
                .padding(.horizontal)
                
                if presentationService.isGenerating {
                    VStack(spacing: 8) {
                        Text(presentationService.currentStep)
                            .font(DesignSystem.font(size: 12))
                            .foregroundColor(DesignSystem.text.opacity(0.7))
                        
                        ProgressView(value: presentationService.generationProgress)
                            .progressViewStyle(.linear)
                            .padding(.horizontal)
                    }
                    .transition(.opacity)
                }
            }
            .padding()
        }
    }
    
    var editorView: some View {
        ScrollView {
            VStack(spacing: 20) {
                slideEditorSection
                ChartMentionHelperView()
                ChartGeneratorView()
            }
            .padding()
        }
        .background(DesignSystem.background)
    }
    
    @ViewBuilder
    private var slideEditorSection: some View {
        if editableSlides.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "rectangle.stack.badge.play")
                    .font(.system(size: 36))
                    .foregroundColor(DesignSystem.text.opacity(0.2))
                Text("Os blocos de slides aparecerão aqui para edição.")
                    .font(DesignSystem.font(size: 13))
                    .foregroundColor(DesignSystem.text.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
        } else {
            LazyVStack(spacing: 16) {
                ForEach(editableSlides.indices, id: \.self) { index in
                    SlideEditorCard(
                        slide: $editableSlides[index],
                        slideIndex: index + 1,
                        onChange: refreshMarkdownFromSlides
                    )
                }
            }
        }
    }
    
    func generatePresentation() {
        presentationService.generatePresentation(
            topic: prompt,
            languageCode: selectedLanguage.localeCode,
            languageName: selectedLanguage.promptName,
            imageStyle: selectedImageStyle.promptDescription
        ) { result in
            DispatchQueue.main.async {
                self.debugLog = self.presentationService.debugLog
                
                switch result {
                case .success(let markdown):
                    withAnimation {
                        generatedMarkdown = markdown
                        editableSlides = presentationService.lastSlides
                    }
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    func exportPDF() {
        guard let markdown = generatedMarkdown else { return }
        let resolvedMarkdown = chartService.replaceMentions(in: markdown)
        let markdownData = resolvedMarkdown.data(using: .utf8) ?? Data()
        let base64Markdown = markdownData.base64EncodedString()
        
        // Create a temporary HTML file with Marp loaded
        let html = """
        <!DOCTYPE html>
        <html><body>
        <script src="https://cdn.jsdelivr.net/npm/@marp-team/marp-core/browser.js"></script>
        <textarea id="markdown" style="display:none"></textarea>
        <div id="preview"></div>
        <script>
          const encodedMarkdown = "\(base64Markdown)";
          const decodedMarkdown = atob(encodedMarkdown);
          document.getElementById('markdown').value = decodedMarkdown;
          const marp = new Marp.Marp()
          const { html, css } = marp.render(document.getElementById('markdown').value)
          document.getElementById('preview').innerHTML = html
          const style = document.createElement('style')
          style.textContent = css
          document.body.appendChild(style)
        </script>
        </body></html>
        """
        
        // In a real app, we would use a hidden WebView to print to PDF.
        // For now, we can save the markdown or a basic HTML file.
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.html]
        savePanel.nameFieldStringValue = "presentation.html"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                try? html.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
    
    private func refreshMarkdownFromSlides() {
        guard !editableSlides.isEmpty else { return }
        generatedMarkdown = presentationService.assembleMarkdown(slides: editableSlides)
    }
    
    private func updatePromptMentionState(with text: String) {
        guard !text.isEmpty else {
            mentionQuery = nil
            return
        }
        
        let pattern = #"@([A-Za-z0-9\-]*)$"#
        if let range = text.range(of: pattern, options: .regularExpression) {
            let token = text[range]
            mentionQuery = String(token.dropFirst())
        } else {
            mentionQuery = nil
        }
    }
    
    private func insertMention(_ chart: GeneratedChart) {
        guard let range = prompt.range(of: #"@([A-Za-z0-9\-]*)$"#, options: .regularExpression) else {
            mentionQuery = nil
            return
        }
        
        prompt.replaceSubrange(range, with: "\(chart.mentionToken) ")
        mentionQuery = nil
    }
    
    private var promptMentions: [GeneratedChart] {
        chartService.charts.filter { prompt.localizedCaseInsensitiveContains($0.mentionToken) }
    }
    
    private var mentionSuggestions: [GeneratedChart] {
        guard let query = mentionQuery else { return [] }
        let normalized = query.lowercased()
        if normalized.isEmpty {
            return chartService.charts
        }
        return chartService.charts.filter {
            $0.handle.lowercased().contains(normalized) ||
            $0.title.lowercased().contains(normalized)
        }
    }
    
    private var shouldShowMentionMenu: Bool {
        mentionQuery != nil && !mentionSuggestions.isEmpty
    }
    
    @ViewBuilder
    private var mentionSuggestionMenu: some View {
        if shouldShowMentionMenu {
            VStack(alignment: .leading, spacing: 6) {
                Label("Mencionar gráfico", systemImage: "at")
                    .font(DesignSystem.font(size: 11, weight: .medium))
                    .foregroundColor(DesignSystem.text.opacity(0.7))
                
                ForEach(mentionSuggestions) { chart in
                    Button {
                        insertMention(chart)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(chart.mentionToken)
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundColor(DesignSystem.accent)
                            Text(chart.title)
                                .font(DesignSystem.font(size: 12))
                                .foregroundColor(DesignSystem.text.opacity(0.8))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(DesignSystem.surface.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(DesignSystem.background)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(DesignSystem.border.opacity(0.4), lineWidth: 1)
            )
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
    
    @ViewBuilder
    private var mentionTagSection: some View {
        if !promptMentions.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Label("Menções detectadas", systemImage: "tag")
                    .font(DesignSystem.font(size: 11, weight: .medium))
                    .foregroundColor(DesignSystem.text.opacity(0.7))
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(promptMentions) { chart in
                        HStack(spacing: 8) {
                            MentionTag(mention: chart.mentionToken)
                            Text(chart.title)
                                .font(DesignSystem.font(size: 11))
                                .foregroundColor(DesignSystem.text.opacity(0.7))
                                .lineLimit(1)
                        }
                        .padding(8)
                        .background(DesignSystem.surface.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .padding(10)
            .background(DesignSystem.surface.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}

private struct SlideEditorCard: View {
    @Binding var slide: PresentationService.SlideContent
    let slideIndex: Int
    let onChange: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Slide \(slideIndex)")
                    .font(DesignSystem.font(size: 13, weight: .semibold))
                    .foregroundColor(DesignSystem.text)
                Spacer()
                if let style = slide.visualStyle {
                    Text(style.replacingOccurrences(of: "-", with: " ").capitalized)
                        .font(DesignSystem.font(size: 11, weight: .medium))
                        .foregroundColor(DesignSystem.text.opacity(0.6))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(DesignSystem.surface.opacity(0.5))
                        .clipShape(Capsule())
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Título")
                    .font(DesignSystem.font(size: 11, weight: .medium))
                    .foregroundColor(DesignSystem.text.opacity(0.7))
                TextField("Título do slide", text: $slide.title)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: slide.title) { _, _ in onChange() }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Highlight")
                    .font(DesignSystem.font(size: 11, weight: .medium))
                    .foregroundColor(DesignSystem.text.opacity(0.7))
                TextField("Resumo/insight do slide", text: Binding(
                    get: { slide.highlight ?? "" },
                    set: {
                        slide.highlight = $0.isEmpty ? nil : $0
                        onChange()
                    }
                ))
                .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Conteúdo (bullets)")
                    .font(DesignSystem.font(size: 11, weight: .medium))
                    .foregroundColor(DesignSystem.text.opacity(0.7))
                TextEditor(text: $slide.content)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(DesignSystem.text)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(DesignSystem.surface.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(DesignSystem.border.opacity(0.4), lineWidth: 1)
                    )
                    .onChange(of: slide.content) { _, _ in onChange() }
            }
            
            if let url = slide.imageUrl {
                HStack(spacing: 6) {
                    Image(systemName: "photo")
                        .font(.system(size: 12))
                    Text(url.absoluteString)
                        .font(DesignSystem.font(size: 11))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .foregroundColor(DesignSystem.text.opacity(0.5))
            }
        }
        .padding(14)
        .background(DesignSystem.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(DesignSystem.border.opacity(0.6), lineWidth: 1)
        )
    }
}

private struct ChartMentionHelperView: View {
    @ObservedObject private var chartService = ChartService.shared
    @State private var copyFeedback: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Gráficos disponíveis", systemImage: "chart.bar.doc.horizontal")
                    .font(DesignSystem.font(size: 13, weight: .semibold))
                    .foregroundColor(DesignSystem.text.opacity(0.8))
                Spacer()
                if let copyFeedback {
                    Text(copyFeedback)
                        .font(DesignSystem.font(size: 11, weight: .medium))
                        .foregroundColor(DesignSystem.accent)
                        .transition(.opacity)
                }
            }
            
            Text("Digite o handle (ex: @grafico1) em qualquer slide para injetar automaticamente o gráfico renderizado no preview e na exportação.")
                .font(DesignSystem.font(size: 12))
                .foregroundColor(DesignSystem.text.opacity(0.65))
            
            if chartService.charts.isEmpty {
                Text("Nenhum gráfico salvo ainda. Gere um abaixo e utilize o handle @graficoX nos campos de conteúdo.")
                    .font(DesignSystem.font(size: 12))
                    .foregroundColor(DesignSystem.text.opacity(0.5))
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 12) {
                    ForEach(chartService.charts) { chart in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(chart.mentionToken)
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .foregroundColor(DesignSystem.accent)
                                Spacer()
                                Button {
                                    copyMention(chart.mentionToken)
                                } label: {
                                    Label("Copiar", systemImage: "doc.on.doc")
                                        .labelStyle(.iconOnly)
                                }
                                .buttonStyle(.plain)
                                .help("Copiar \(chart.mentionToken)")
                            }
                            
                            Text(chart.title)
                                .font(DesignSystem.font(size: 12, weight: .medium))
                                .foregroundColor(DesignSystem.text)
                            
                            if let base64 = chart.imageBase64,
                               let data = Data(base64Encoded: base64),
                               let nsImage = NSImage(data: data) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: 140)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            } else {
                                Text("Prévia indisponível. Regere o gráfico para visualizar.")
                                    .font(DesignSystem.font(size: 11))
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(12)
                        .background(DesignSystem.surface.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(DesignSystem.border.opacity(0.4), lineWidth: 1)
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(DesignSystem.surface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .animation(.easeInOut(duration: 0.2), value: copyFeedback)
    }
    
    private func copyMention(_ mention: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(mention, forType: .string)
        withAnimation {
            copyFeedback = "\(mention) copiado!"
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                copyFeedback = nil
            }
        }
    }
}

// Simple Preview without Marp dependency
struct MarpPreview: NSViewRepresentable {
    let markdown: String
    
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsMagnification = false
        webView.allowsBackForwardNavigationGestures = false
        
        // Load empty page initially
        webView.loadHTMLString("<html><body></body></html>", baseURL: nil)
        
        return webView
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Only update if markdown changed to avoid unnecessary re-rendering
        guard context.coordinator.lastMarkdown != markdown, !markdown.isEmpty else {
            return
        }
        
        context.coordinator.lastMarkdown = markdown
        
        // Process markdown on background thread
        let markdownToProcess = markdown
        DispatchQueue.global(qos: .userInitiated).async {
            let htmlContent = self.processMarkdown(markdownToProcess)
            
            DispatchQueue.main.async {
                nsView.loadHTMLString(htmlContent, baseURL: nil)
            }
        }
    }
    
    private func processMarkdown(_ markdown: String) -> String {
        // Remove front-matter
        var bodyMarkdown = markdown
        if bodyMarkdown.hasPrefix("---") {
            if let closingRange = bodyMarkdown.range(of: "\n---", options: .literal, range: bodyMarkdown.index(bodyMarkdown.startIndex, offsetBy: 3)..<bodyMarkdown.endIndex) {
                bodyMarkdown = String(bodyMarkdown[closingRange.upperBound...])
            }
        }
        
        // Parse markdown manually for preview
        let slides = bodyMarkdown.components(separatedBy: "\n---\n")
        let accentPalette = ["#EEF2FF", "#FFF7ED", "#ECFDF3", "#FDF2F8", "#F0F9FF", "#E0F2FE", "#FEF3C7"]
        
        var htmlSlides = ""
        for (index, slide) in slides.enumerated() {
            if slide.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continue }
            
            var slideContent = slide
            var imageUrl: String?
            var imageSide: String?
            var backgroundUrl: String?
            
            let mutableContent = NSMutableString(string: slideContent)
            
            if let pattern = try? NSRegularExpression(pattern: #"!\[bg\s+(left|right):\d+%\]\((https://[^\)]+)\)"#),
               let match = pattern.firstMatch(in: slideContent, range: NSRange(slideContent.startIndex..., in: slideContent)),
               let sideRange = Range(match.range(at: 1), in: slideContent),
               let urlRange = Range(match.range(at: 2), in: slideContent) {
                imageSide = String(slideContent[sideRange])
                imageUrl = String(slideContent[urlRange])
                mutableContent.deleteCharacters(in: match.range)
            } else if let pattern = try? NSRegularExpression(pattern: #"!\[bg\]\((https://[^\)]+)\)"#),
                      let match = pattern.firstMatch(in: slideContent, range: NSRange(slideContent.startIndex..., in: slideContent)),
                      let urlRange = Range(match.range(at: 1), in: slideContent) {
                backgroundUrl = String(slideContent[urlRange])
                mutableContent.deleteCharacters(in: match.range)
            }
            
            slideContent = mutableContent as String
            
            // Convert markdown to simple HTML
            let html = convertMarkdownToHTML(slideContent)
            
            let accentColor = accentPalette[index % accentPalette.count]
            var slideClasses = ["slide"]
            if let side = imageSide {
                slideClasses.append("image-\(side)")
            }
            if backgroundUrl != nil {
                slideClasses.append("full-bleed")
            }
            
            var slideStyle = "--accent:\(accentColor);"
            if let bg = backgroundUrl {
                slideStyle += "background-image: linear-gradient(120deg, rgba(0,0,0,0.45), rgba(0,0,0,0.65)), url(\(bg));background-size: cover;background-position: center;color:#fff;"
            }
            
            let imageBlock: String
            if let url = imageUrl, backgroundUrl == nil {
                imageBlock = "<div class=\"image\"><img src=\"\(url)\" /></div>"
            } else {
                imageBlock = ""
            }
            
            htmlSlides += """
            <div class="\(slideClasses.joined(separator: " "))" data-slide="\(index + 1)" style="\(slideStyle)">
                <div class="content">
                    \(html)
                </div>
                \(imageBlock)
            </div>
            """
        }
        
        let htmlContent = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <style>
                body {
                    margin: 0;
                    padding: 20px;
                    background: #f5f5f5;
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif;
                }
                .slide {
                    background: var(--accent, white);
                    margin: 20px auto;
                    padding: 40px;
                    max-width: 960px;
                    min-height: 540px;
                    box-shadow: 0 4px 10px rgba(0,0,0,0.1);
                    border-radius: 12px;
                    display: flex;
                    gap: 40px;
                    position: relative;
                }
                .slide::before {
                    content: "Slide " attr(data-slide);
                    position: absolute;
                    top: 10px;
                    right: 20px;
                    font-size: 12px;
                    color: #999;
                }
                .content {
                    flex: 1;
                }
                .slide.image-left {
                    flex-direction: row-reverse;
                }
                .slide.full-bleed .content {
                    background: rgba(0,0,0,0.25);
                    padding: 20px;
                    border-radius: 12px;
                }
                .slide.full-bleed .content h1,
                .slide.full-bleed .content h2,
                .slide.full-bleed .content li,
                .slide.full-bleed .content p,
                .slide.full-bleed .content strong {
                    color: #fff;
                }
                .image {
                    width: 35%;
                    display: flex;
                    align-items: center;
                }
                .image img {
                    width: 100%;
                    border-radius: 8px;
                    box-shadow: 0 8px 20px rgba(0,0,0,0.15);
                }
                h1 {
                    font-size: 32px;
                    margin: 0 0 20px 0;
                    color: #1f2937;
                }
                h2 {
                    font-size: 24px;
                    margin: 0 0 15px 0;
                    color: #374151;
                }
                ul {
                    list-style: none;
                    padding: 0;
                    margin: 20px 0;
                }
                li {
                    padding: 8px 0;
                    color: #4b5563;
                    font-size: 16px;
                    position: relative;
                    padding-left: 20px;
                }
                li::before {
                    content: "•";
                    position: absolute;
                    left: 0;
                    color: #6366f1;
                }
                .highlight {
                    padding: 12px 16px;
                    background: rgba(255,255,255,0.85);
                    border-left: 4px solid #4338ca;
                    border-radius: 8px;
                    margin: 16px 0;
                    font-weight: 600;
                }
                .slide.full-bleed .highlight {
                    background: rgba(0,0,0,0.35);
                    border-color: #fff;
                    color: #fff;
                }
            </style>
        </head>
        <body>
            \(htmlSlides)
        </body>
        </html>
        """
        return htmlContent
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var lastMarkdown: String = ""
    }
    
    private func convertMarkdownToHTML(_ text: String) -> String {
        var htmlParts: [String] = []
        var listItems: [String] = []
        
        func flushList() {
            guard !listItems.isEmpty else { return }
            let items = listItems
                .map { "<li>\($0)</li>" }
                .joined()
            htmlParts.append("<ul>\(items)</ul>")
            listItems.removeAll()
        }
        
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                flushList()
                continue
            }
            
            if trimmed.hasPrefix("# ") {
                flushList()
                let content = String(trimmed.dropFirst(2))
                htmlParts.append("<h1>\(applyInlineFormatting(content))</h1>")
            } else if trimmed.hasPrefix("## ") {
                flushList()
                let content = String(trimmed.dropFirst(3))
                htmlParts.append("<h2>\(applyInlineFormatting(content))</h2>")
            } else if trimmed.hasPrefix("> ") {
                flushList()
                let content = String(trimmed.dropFirst(2))
                htmlParts.append("<p class=\"highlight\">\(applyInlineFormatting(content))</p>")
            } else if trimmed.hasPrefix("- ") {
                let content = String(trimmed.dropFirst(2))
                listItems.append(applyInlineFormatting(content))
            } else {
                flushList()
                htmlParts.append("<p>\(applyInlineFormatting(trimmed))</p>")
            }
        }
        
        flushList()
        return htmlParts.joined()
    }
    
    private func applyInlineFormatting(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: #"\*\*(.+?)\*\*"#, with: "<strong>$1</strong>", options: .regularExpression)
        result = result.replacingOccurrences(of: #"_([^_]+)_"#, with: "<em>$1</em>", options: .regularExpression)
        return result
    }
}

// MARK: - Mention Tag Component

struct MentionTag: View {
    let mention: String
    
    var body: some View {
        Text(mention)
            .font(DesignSystem.font(size: 11, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(DesignSystem.accent)
            .clipShape(SquircleShape())
    }
}
