import Foundation

class PresentationArchiveService: ObservableObject {
    static let shared = PresentationArchiveService()
    
    @Published private(set) var presentations: [ArchivedPresentation] = []
    
    private let fileName = "presentations_history.json"
    private let queue = DispatchQueue(label: "presentation.archive.queue", qos: .utility)
    
    private init() {
        loadFromDisk()
    }
    
    // MARK: - Public API
    
    func archivePresentation(
        topic: String,
        markdown: String,
        slides: [PresentationService.SlideContent]
    ) {
        let sanitizedTopic = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayTitle = slides.first?.title.trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty ?? sanitizedTopic.nilIfEmpty ?? "Apresentação \(Date().formatted(date: .numeric, time: .shortened))"
        
        let archivedSlides = slides.map { slide in
            ArchivedPresentation.Slide(
                title: slide.title,
                highlight: slide.highlight,
                content: slide.content,
                imageURL: slide.imageUrl,
                layout: slide.visualStyle ?? PresentationService.SlideLayout.random().rawValue
            )
        }
        
        let presentation = ArchivedPresentation(
            title: displayTitle,
            topic: sanitizedTopic.isEmpty ? displayTitle : sanitizedTopic,
            markdown: markdown,
            slides: archivedSlides
        )
        
        DispatchQueue.main.async {
            self.presentations.insert(presentation, at: 0)
            self.persist()
        }
    }
    
    func deletePresentation(_ id: UUID) {
        guard let index = presentations.firstIndex(where: { $0.id == id }) else { return }
        presentations.remove(at: index)
        persist()
    }
    
    func deleteSlide(presentationId: UUID, slideId: UUID) {
        guard let presentationIndex = presentations.firstIndex(where: { $0.id == presentationId }) else { return }
        
        var presentation = presentations[presentationIndex]
        presentation.slides.removeAll { $0.id == slideId }
        
        if presentation.slides.isEmpty {
            presentations.remove(at: presentationIndex)
        } else {
            presentations[presentationIndex] = presentation
        }
        
        persist()
    }
    
    func updateSlideImage(
        presentationId: UUID,
        slideId: UUID,
        imageURL: URL?
    ) {
        guard let presentationIndex = presentations.firstIndex(where: { $0.id == presentationId }) else { return }
        var presentation = presentations[presentationIndex]
        
        if let slideIndex = presentation.slides.firstIndex(where: { $0.id == slideId }) {
            presentation.slides[slideIndex].imageURL = imageURL
            presentations[presentationIndex] = presentation
            persist()
        }
    }
    
    // MARK: - Persistence
    
    private func documentsURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func storageURL() -> URL {
        documentsURL().appendingPathComponent(fileName)
    }
    
    private func loadFromDisk() {
        queue.async {
            let url = self.storageURL()
            guard FileManager.default.fileExists(atPath: url.path) else { return }
            
            do {
                let data = try Data(contentsOf: url)
                let decoded = try JSONDecoder().decode([ArchivedPresentation].self, from: data)
                DispatchQueue.main.async {
                    self.presentations = decoded
                }
            } catch {
                print("Failed to load presentation history: \(error)")
            }
        }
    }
    
    private func persist() {
        let dataTask = {
            do {
                let data = try JSONEncoder().encode(self.presentations)
                try data.write(to: self.storageURL())
            } catch {
                print("Failed to persist presentation history: \(error)")
            }
        }
        
        queue.async(execute: dataTask)
    }
}

private extension String {
    var nilIfEmpty: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}


