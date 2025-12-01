import SwiftUI

enum PresentationViewState {
    case home
    case generating
    case editing(EditablePresentation)
}

struct PresentationMainView: View {
    @State private var viewState: PresentationViewState = .home
    @State private var currentPresentation: EditablePresentation?
    
    @StateObject private var presentationService = PresentationService.shared
    @StateObject private var archiveService = PresentationArchiveService.shared
    
    var body: some View {
        Group {
            switch viewState {
            case .home:
                PresentationHomeView { prompt, imageStyle, language in
                    generatePresentation(prompt: prompt, imageStyle: imageStyle, language: language)
                }
                
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
            if !isGenerating && presentationService.generationProgress >= 1.0 {
                // Geração concluída, converter para EditablePresentation
                convertToEditablePresentation()
            }
        }
    }
    
    private func generatePresentation(
        prompt: String,
        imageStyle: ImageStyleOption,
        language: PresentationLanguageOption
    ) {
        viewState = .generating
        
        presentationService.generatePresentation(
            topic: prompt,
            slideCount: 5,
            languageCode: language.localeCode,
            languageName: language.promptName,
            imageStyle: imageStyle.promptDescription,
            availableCharts: ChartService.shared.charts,
            completion: { result in
                switch result {
                case .success:
                    // A conversão será feita no onChange
                    break
                case .failure(let error):
                    print("Error generating presentation: \(error)")
                    viewState = .home
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

