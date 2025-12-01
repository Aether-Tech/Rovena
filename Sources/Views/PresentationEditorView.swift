import SwiftUI

struct PresentationEditorView: View {
    @Binding var presentation: EditablePresentation
    let onSave: (EditablePresentation) -> Void
    let onClose: () -> Void
    
    @State private var selectedSlideIndex: Int = 0
    @State private var selectedElementId: UUID?
    @State private var showRegenerateImageDialog = false
    @State private var imageRegeneratePrompt = ""
    @State private var elementToRegenerate: EditableElement?
    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar: Slides thumbnails
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Slides")
                        .font(DesignSystem.font(size: 16, weight: .semibold))
                        .foregroundColor(DesignSystem.text)
                    
                    Spacer()
                    
                    Button(action: addNewSlide) {
                        Image(systemName: "plus")
                            .foregroundColor(DesignSystem.accent)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(DesignSystem.surface)
                
                // Slides list
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(Array(presentation.slides.enumerated()), id: \.element.id) { index, slide in
                            SlideThumbnail(
                                slide: slide,
                                isSelected: index == selectedSlideIndex,
                                onSelect: {
                                    selectedSlideIndex = index
                                    selectedElementId = nil
                                },
                                onDelete: {
                                    deleteSlide(at: index)
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
            .frame(width: 200)
            .background(DesignSystem.background)
            .overlay(Rectangle().frame(width: 0.5).foregroundColor(DesignSystem.border), alignment: .trailing)
            
            // Main editor area
            VStack(spacing: 0) {
                // Toolbar
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .foregroundColor(DesignSystem.text)
                    }
                    .buttonStyle(.plain)
                    
                    Text(presentation.title)
                        .font(DesignSystem.font(size: 16, weight: .semibold))
                        .foregroundColor(DesignSystem.text)
                    
                    Spacer()
                    
                    // Toolbar buttons
                    HStack(spacing: 12) {
                        Button(action: addNewText) {
                            Label("Text", systemImage: "text")
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: addNewImage) {
                            Label("Image", systemImage: "photo")
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: toggleSubtitle) {
                            Label("Subtitle", systemImage: "text.below.photo")
                        }
                        .buttonStyle(.plain)
                        
                        Divider()
                            .frame(height: 20)
                        
                        Button(action: savePresentation) {
                            Label("Save", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(DesignSystem.accent)
                    }
                }
                .padding()
                .background(DesignSystem.surface)
                
                // Canvas
                if selectedSlideIndex < presentation.slides.count {
                    SlideCanvasView(
                        slide: $presentation.slides[selectedSlideIndex],
                        selectedElementId: $selectedElementId,
                        onRegenerateImage: { element in
                            elementToRegenerate = element
                            showRegenerateImageDialog = true
                        }
                    )
                }
            }
        }
        .background(DesignSystem.background)
        .sheet(isPresented: $showRegenerateImageDialog) {
            RegenerateImageDialog(
                prompt: $imageRegeneratePrompt,
                onRegenerate: {
                    regenerateImage()
                },
                onCancel: {
                    showRegenerateImageDialog = false
                    imageRegeneratePrompt = ""
                    elementToRegenerate = nil
                }
            )
        }
    }
    
    private func addNewSlide() {
        let newSlide = EditableSlide(
            title: "New Slide",
            elements: []
        )
        presentation.slides.append(newSlide)
        selectedSlideIndex = presentation.slides.count - 1
    }
    
    private func deleteSlide(at index: Int) {
        guard presentation.slides.count > 1 else { return }
        presentation.slides.remove(at: index)
        if selectedSlideIndex >= presentation.slides.count {
            selectedSlideIndex = presentation.slides.count - 1
        }
    }
    
    private func addNewText() {
        guard selectedSlideIndex < presentation.slides.count else { return }
        let newElement = EditableElement(
            type: .text,
            content: "New Text",
            position: CodablePoint(CGPoint(x: 100, y: 200)),
            size: CodableSize(CGSize(width: 300, height: 50)),
            fontSize: 24,
            zIndex: presentation.slides[selectedSlideIndex].elements.count
        )
        presentation.slides[selectedSlideIndex].elements.append(newElement)
        selectedElementId = newElement.id
    }
    
    private func addNewImage() {
        guard selectedSlideIndex < presentation.slides.count else { return }
        // Abrir seletor de arquivo ou gerar imagem
        // Por enquanto, placeholder
        let newElement = EditableElement(
            type: .image,
            content: "",
            position: CodablePoint(CGPoint(x: 200, y: 200)),
            size: CodableSize(CGSize(width: 400, height: 400)),
            zIndex: presentation.slides[selectedSlideIndex].elements.count
        )
        presentation.slides[selectedSlideIndex].elements.append(newElement)
        selectedElementId = newElement.id
    }
    
    private func toggleSubtitle() {
        guard selectedSlideIndex < presentation.slides.count else { return }
        let slide = presentation.slides[selectedSlideIndex]
        
        if let subtitleIndex = slide.elements.firstIndex(where: { $0.type == .subtitle }) {
            // Remover subtítulo
            presentation.slides[selectedSlideIndex].elements.remove(at: subtitleIndex)
        } else {
            // Adicionar subtítulo
            let subtitle = EditableElement(
                type: .subtitle,
                content: "Subtitle",
                position: CodablePoint(CGPoint(x: 50, y: 100)),
                size: CodableSize(CGSize(width: 800, height: 40)),
                fontSize: 20,
                fontWeight: "medium",
                zIndex: slide.elements.count
            )
            presentation.slides[selectedSlideIndex].elements.append(subtitle)
        }
    }
    
    private func regenerateImage() {
        guard let element = elementToRegenerate,
              selectedSlideIndex < presentation.slides.count,
              presentation.slides[selectedSlideIndex].elements.contains(where: { $0.id == element.id }) else {
            return
        }
        
        // Gerar nova imagem usando AIService
        // Por enquanto, placeholder
        showRegenerateImageDialog = false
        imageRegeneratePrompt = ""
        elementToRegenerate = nil
    }
    
    private func savePresentation() {
        presentation.updatedAt = Date()
        onSave(presentation)
    }
}

// MARK: - Slide Thumbnail

struct SlideThumbnail: View {
    let slide: EditableSlide
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // Preview
            RoundedRectangle(cornerRadius: 8)
                .fill(DesignSystem.surface)
                .frame(height: 100)
                .overlay(
                    Text(slide.title)
                        .font(DesignSystem.font(size: 10))
                        .foregroundColor(DesignSystem.text.opacity(0.7))
                        .lineLimit(2)
                        .padding(4)
                )
            
            Text("Slide \(slide.id.uuidString.prefix(8))")
                .font(DesignSystem.font(size: 10))
                .foregroundColor(DesignSystem.text.opacity(0.6))
        }
        .padding(8)
        .background(isSelected ? DesignSystem.accent.opacity(0.2) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? DesignSystem.accent : DesignSystem.border.opacity(0.3), lineWidth: isSelected ? 2 : 1)
        )
        .onTapGesture {
            onSelect()
        }
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Regenerate Image Dialog

struct RegenerateImageDialog: View {
    @Binding var prompt: String
    let onRegenerate: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Regenerate Image")
                .font(DesignSystem.font(size: 20, weight: .bold))
                .foregroundColor(DesignSystem.text)
            
            TextField("Describe the new image...", text: $prompt, axis: .vertical)
                .textFieldStyle(.plain)
                .padding()
                .frame(height: 100)
                .background(DesignSystem.surface)
                .clipShape(SquircleShape())
            
            HStack(spacing: 12) {
                Button("Cancel", action: onCancel)
                    .buttonStyle(.plain)
                    .foregroundColor(DesignSystem.text.opacity(0.7))
                
                Spacer()
                
                Button("Regenerate", action: onRegenerate)
                    .buttonStyle(.plain)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(DesignSystem.accent)
                    .clipShape(SquircleShape())
            }
        }
        .padding(30)
        .frame(width: 500)
        .background(DesignSystem.background)
    }
}

