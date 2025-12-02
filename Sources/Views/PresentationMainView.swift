import SwiftUI

enum PresentationViewState: Equatable {
    case home
    case generating
    case editing(EditablePresentation)
    
    static func == (lhs: PresentationViewState, rhs: PresentationViewState) -> Bool {
        switch (lhs, rhs) {
        case (.home, .home), (.generating, .generating):
            return true
        case (.editing(let lhsPresentation), .editing(let rhsPresentation)):
            return lhsPresentation.id == rhsPresentation.id
        default:
            return false
        }
    }
}

struct PresentationMainView: View {
    @State private var viewState: PresentationViewState = .home
    @State private var currentPresentation: EditablePresentation?
    @State private var showError = false
    @State private var errorMessage = ""
    
    @StateObject private var presentationService = PresentationService.shared
    @StateObject private var archiveService = PresentationArchiveService.shared
    
    var body: some View {
        Group {
            switch viewState {
            case .home:
                PresentationHomeView(
                    onGenerate: { prompt, imageStyle, language, styleLevel in
                        generatePresentation(prompt: prompt, imageStyle: imageStyle, language: language, styleLevel: styleLevel)
                    },
                    onOpenPresentation: { archivedPresentation in
                        openPresentationFromArchive(archivedPresentation)
                    }
                )
                
            case .generating:
                PresentationLoadingView(presentationService: presentationService)
                
            case .editing(let presentation):
                PresentationEditorViewWrapper(
                    presentation: presentation,
                    onSave: { updatedPresentation in
                        savePresentation(updatedPresentation)
                    },
                    onClose: {
                        viewState = .home
                    }
                )
            }
        }
        .onChange(of: presentationService.isGenerating) { _, isGenerating in
            if !isGenerating {
                // Aguardar um pouco para garantir que o progresso foi atualizado
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    if presentationService.generationProgress >= 1.0 && !presentationService.lastSlides.isEmpty {
                        // Geração concluída, converter para EditablePresentation
                        LogManager.shared.addLog("Presentation generation completed, converting to editable", level: .info, category: "PresentationMainView")
                        convertToEditablePresentation()
                    } else if viewState == .generating {
                        // Geração falhou ou foi cancelada, voltar para home
                        LogManager.shared.addLog("Presentation generation failed or cancelled, returning to home", level: .warning, category: "PresentationMainView")
                        viewState = .home
                    }
                }
            }
        }
        .onChange(of: presentationService.generationProgress) { oldProgress, newProgress in
            // Se o progresso voltar para 0.0 enquanto está gerando, significa que houve um erro
            if newProgress == 0.0 && oldProgress > 0.0 && !presentationService.isGenerating && viewState == .generating {
                LogManager.shared.addLog("Progress reset to 0, returning to home", level: .warning, category: "PresentationMainView")
                viewState = .home
            }
        }
        // Fallback: se ficar preso em generating por mais de 5 minutos, voltar para home
        .onAppear {
            if viewState == .generating {
                DispatchQueue.main.asyncAfter(deadline: .now() + 300) { // 5 minutos
                    if viewState == .generating && !presentationService.isGenerating {
                        LogManager.shared.addLog("Timeout: Presentation generation stuck, returning to home", level: .error, category: "PresentationMainView")
                        viewState = .home
                    }
                }
            }
        }
        .alert("Error Generating Presentation", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func generatePresentation(
        prompt: String,
        imageStyle: ImageStyleOption,
        language: PresentationLanguageOption,
        styleLevel: Double
    ) {
        viewState = .generating
        
        presentationService.generatePresentation(
            topic: prompt,
            slideCount: 5,
            languageCode: language.localeCode,
            languageName: language.promptName,
            imageStyle: imageStyle.promptDescription,
            stylizationLevel: styleLevel,
            availableCharts: ChartService.shared.charts,
            completion: { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        // A conversão será feita no onChange quando isGenerating for false e progress >= 1.0
                        break
                    case .failure(let error):
                        // Garantir que o estado seja resetado
                        presentationService.isGenerating = false
                        presentationService.generationProgress = 0.0
                        presentationService.currentStep = ""
                        
                        // Mostrar mensagem de erro ao usuário
                        errorMessage = error.localizedDescription
                        showError = true
                        
                        LogManager.shared.addLog(
                            "Presentation generation failed in MainView: \(error.localizedDescription)",
                            level: .error,
                            category: "PresentationMainView"
                        )
                        
                        // Voltar para home
                        viewState = .home
                    }
                }
            }
        )
    }
    
    private func convertToEditablePresentation() {
        // Converter PresentationService.SlideContent para EditableSlide usando layout inteligente
        let layoutService = SlideLayoutService.shared
        let editableSlides = presentationService.lastSlides.map { slide in
            let layout = slide.visualStyle ?? "default"
            let elements = layoutService.calculateElementPositions(
                title: slide.title,
                content: slide.content,
                highlight: slide.highlight,
                imageUrl: slide.imageUrl,
                layout: layout
            )
            
            return EditableSlide(
                title: slide.title,
                elements: elements,
                layout: layout
            )
        }
        
        // Usar o prompt original ou título do primeiro slide
        let topic = presentationService.lastSlides.first?.title ?? "New Presentation"
        let editablePresentation = EditablePresentation(
            title: topic,
            topic: topic,
            slides: editableSlides
        )
        
        currentPresentation = editablePresentation
        viewState = .editing(editablePresentation)
    }
    
    private func savePresentation(_ presentation: EditablePresentation) {
        // Salvar no archive service
        // Por enquanto, apenas atualizar o estado
        currentPresentation = presentation
    }
    
    private func openPresentationFromArchive(_ archived: ArchivedPresentation) {
        // Converter ArchivedPresentation para EditablePresentation
        let layoutService = SlideLayoutService.shared
        let editableSlides = archived.slides.map { archivedSlide in
            let elements = layoutService.calculateElementPositions(
                title: archivedSlide.title,
                content: archivedSlide.content,
                highlight: archivedSlide.highlight,
                imageUrl: archivedSlide.imageURL,
                layout: archivedSlide.layout
            )
            
            return EditableSlide(
                id: archivedSlide.id,
                title: archivedSlide.title,
                elements: elements,
                layout: archivedSlide.layout
            )
        }
        
        let editablePresentation = EditablePresentation(
            id: archived.id,
            title: archived.title,
            topic: archived.topic,
            slides: editableSlides,
            createdAt: archived.createdAt,
            updatedAt: Date() // Atualizar data de modificação
        )
        
        currentPresentation = editablePresentation
        viewState = .editing(editablePresentation)
        
        LogManager.shared.addLog("Opened presentation from archive: \(archived.title)", level: .info, category: "PresentationMainView")
    }
}

// MARK: - Extension para carregar apresentação do archive

extension PresentationMainView {
    static func loadFromArchive(_ archived: ArchivedPresentation) -> PresentationMainView {
        let view = PresentationMainView()
        
        // Converter ArchivedPresentation para EditablePresentation
        let layoutService = SlideLayoutService.shared
        let editableSlides = archived.slides.map { archivedSlide in
            let elements = layoutService.calculateElementPositions(
                title: archivedSlide.title,
                content: archivedSlide.content,
                highlight: archivedSlide.highlight,
                imageUrl: archivedSlide.imageURL,
                layout: archivedSlide.layout
            )
            
            return EditableSlide(
                id: archivedSlide.id,
                title: archivedSlide.title,
                elements: elements,
                layout: archivedSlide.layout
            )
        }
        
        let editablePresentation = EditablePresentation(
            id: archived.id,
            title: archived.title,
            topic: archived.topic,
            slides: editableSlides,
            createdAt: archived.createdAt,
            updatedAt: Date()
        )
        
        view.currentPresentation = editablePresentation
        view.viewState = .editing(editablePresentation)
        
        return view
    }
}

