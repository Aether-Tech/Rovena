import SwiftUI

struct PresentationHomeView: View {
    @State private var prompt: String = ""
    @State private var selectedImageStyle: ImageStyleOption = .realism
    @State private var selectedLanguage: PresentationLanguageOption = .portugueseBR
    @FocusState private var isPromptFocused: Bool
    
    @ObservedObject var presentationService = PresentationService.shared
    @ObservedObject var archiveService = PresentationArchiveService.shared
    
    var onGenerate: (String, ImageStyleOption, PresentationLanguageOption) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Input central
            VStack(spacing: 24) {
                Spacer()
                
                VStack(spacing: 16) {
                    Text("Create Presentation")
                        .font(DesignSystem.font(size: 32, weight: .bold))
                        .foregroundColor(DesignSystem.text)
                    
                    Text("Describe what you want to present")
                        .font(DesignSystem.font(size: 16))
                        .foregroundColor(DesignSystem.text.opacity(0.6))
                }
                
                VStack(spacing: 12) {
                    // Prompt input
                    TextField("Ex: Apresentação sobre inteligência artificial...", text: $prompt, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(DesignSystem.font(size: 16))
                        .foregroundColor(DesignSystem.text)
                        .padding(20)
                        .frame(minHeight: 120, maxHeight: 200)
                        .background(DesignSystem.surface)
                        .clipShape(SquircleShape())
                        .overlay(
                            SquircleShape()
                                .stroke(isPromptFocused ? DesignSystem.accent : DesignSystem.border, lineWidth: isPromptFocused ? 2 : 1)
                        )
                        .focused($isPromptFocused)
                        .onSubmit {
                            if !prompt.isEmpty {
                                generatePresentation()
                            }
                        }
                    
                    // Options
                    HStack(spacing: 16) {
                        Picker("Style", selection: $selectedImageStyle) {
                            ForEach(ImageStyleOption.allCases) { style in
                                Text(style.displayName).tag(style)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity)
                        
                        Picker("Language", selection: $selectedLanguage) {
                            ForEach(PresentationLanguageOption.allCases) { lang in
                                Text(lang.displayName).tag(lang)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity)
                    }
                    
                    // Generate button
                    Button(action: generatePresentation) {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Generate Presentation")
                                .font(DesignSystem.font(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(prompt.isEmpty ? Color.gray : DesignSystem.accent)
                        .clipShape(SquircleShape())
                    }
                    .buttonStyle(.plain)
                    .disabled(prompt.isEmpty || presentationService.isGenerating)
                }
                .frame(maxWidth: 600)
                
                Spacer()
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 60)
            
            // Últimas apresentações
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Recent Presentations")
                        .font(DesignSystem.font(size: 18, weight: .semibold))
                        .foregroundColor(DesignSystem.text)
                    
                    Spacer()
                }
                .padding(.horizontal, 40)
                
                if archiveService.presentations.isEmpty {
                    // Placeholder
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(DesignSystem.text.opacity(0.3))
                        
                        Text("Nothing to see here yet")
                            .font(DesignSystem.font(size: 16))
                            .foregroundColor(DesignSystem.text.opacity(0.5))
                        
                        Text("Create your first presentation above")
                            .font(DesignSystem.font(size: 14))
                            .foregroundColor(DesignSystem.text.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(Array(archiveService.presentations.prefix(4))) { presentation in
                                PresentationCard(presentation: presentation)
                            }
                        }
                        .padding(.horizontal, 40)
                    }
                }
            }
            .padding(.bottom, 40)
        }
        .background(DesignSystem.background)
    }
    
    private func generatePresentation() {
        guard !prompt.isEmpty else { return }
        onGenerate(prompt, selectedImageStyle, selectedLanguage)
    }
}

// MARK: - Presentation Card

struct PresentationCard: View {
    let presentation: ArchivedPresentation
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Preview
            if let firstSlide = presentation.slides.first,
               let imageURL = firstSlide.imageURL,
               let nsImage = NSImage(contentsOf: imageURL) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 240, height: 135)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(DesignSystem.surface)
                    .frame(width: 240, height: 135)
                    .overlay(
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 32))
                            .foregroundColor(DesignSystem.text.opacity(0.3))
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(presentation.title)
                    .font(DesignSystem.font(size: 14, weight: .semibold))
                    .foregroundColor(DesignSystem.text)
                    .lineLimit(2)
                
                Text("\(presentation.slides.count) slides")
                    .font(DesignSystem.font(size: 12))
                    .foregroundColor(DesignSystem.text.opacity(0.6))
                
                Text(presentation.displaySubtitle)
                    .font(DesignSystem.font(size: 11))
                    .foregroundColor(DesignSystem.text.opacity(0.5))
            }
        }
        .frame(width: 240)
        .padding(12)
        .background(DesignSystem.surface)
        .clipShape(SquircleShape())
        .overlay(
            SquircleShape()
                .stroke(DesignSystem.border.opacity(0.3), lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

