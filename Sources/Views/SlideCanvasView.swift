import SwiftUI

struct SlideCanvasView: View {
    @Binding var slide: EditableSlide
    @Binding var selectedElementId: UUID?
    let onRegenerateImage: (EditableElement) -> Void
    
    @State private var draggedElementId: UUID?
    @State private var dragOffset: CGSize = .zero
    @State private var resizingElementId: UUID?
    @State private var resizeStartSize: CGSize = .zero
    @State private var resizeStartPosition: CGPoint = .zero
    
    // Tamanho do canvas (proporção 16:9)
    private let canvasWidth: CGFloat = 1280
    private let canvasHeight: CGFloat = 720
    private let scale: CGFloat = 0.6 // Escala para caber na tela
    
    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            ZStack(alignment: .topLeading) {
                // Canvas background - clicável para deselecionar
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .frame(width: canvasWidth * scale, height: canvasHeight * scale)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedElementId = nil
                    }
                
                // Slide elements (ordenados por zIndex) - cache do array ordenado para performance
                ForEach(slide.elements.sorted(by: { $0.zIndex < $1.zIndex }), id: \.id) { editableElement in
                    let elementIndex = slide.elements.firstIndex(where: { $0.id == editableElement.id }) ?? 0
                    
                    SlideElementView(
                        element: Binding(
                            get: { 
                                guard elementIndex < slide.elements.count else { return editableElement }
                                return slide.elements[elementIndex]
                            },
                            set: { newValue in
                                guard elementIndex < slide.elements.count else { return }
                                slide.elements[elementIndex] = newValue
                            }
                        ),
                        isSelected: selectedElementId == editableElement.id,
                        scale: scale,
                        onSingleTap: {
                            selectedElementId = editableElement.id
                        },
                        onDoubleTap: {
                            // Duplo clique para editar (apenas textos)
                            if editableElement.type == .text || editableElement.type == .subtitle {
                                selectedElementId = editableElement.id
                            }
                        },
                        onDrag: { offset in
                            updateElementPosition(elementId: editableElement.id, offset: offset)
                        },
                        onResize: { newSize in
                            updateElementSize(elementId: editableElement.id, newSize: newSize)
                        },
                        onRegenerateImage: {
                            onRegenerateImage(editableElement)
                        }
                    )
                }
            }
            .frame(width: canvasWidth * scale, height: canvasHeight * scale)
            .padding(40)
        }
        .background(DesignSystem.background)
    }
    
    private func updateElementPosition(elementId: UUID, offset: CGSize) {
        guard let index = slide.elements.firstIndex(where: { $0.id == elementId }) else { return }
        let currentPos = slide.elements[index].position.cgPoint
        let newX = max(0, min(canvasWidth - slide.elements[index].size.cgSize.width, currentPos.x + offset.width / scale))
        let newY = max(0, min(canvasHeight - slide.elements[index].size.cgSize.height, currentPos.y + offset.height / scale))
        slide.elements[index].position = CodablePoint(CGPoint(x: newX, y: newY))
    }
    
    private func updateElementSize(elementId: UUID, newSize: CGSize) {
        guard let index = slide.elements.firstIndex(where: { $0.id == elementId }) else { return }
        let minSize: CGFloat = 50
        let constrainedWidth = max(minSize, min(canvasWidth, newSize.width / scale))
        let constrainedHeight = max(minSize, min(canvasHeight, newSize.height / scale))
        slide.elements[index].size = CodableSize(CGSize(width: constrainedWidth, height: constrainedHeight))
    }
}

// MARK: - Slide Element View

struct SlideElementView: View {
    @Binding var element: EditableElement
    let isSelected: Bool
    let scale: CGFloat
    let onSingleTap: () -> Void
    let onDoubleTap: () -> Void
    let onDrag: (CGSize) -> Void
    let onResize: (CGSize) -> Void
    let onRegenerateImage: () -> Void
    
    @State private var isDragging = false
    @State private var dragOffset: CGSize = .zero
    @State private var isResizing = false
    @State private var resizeOffset: CGSize = .zero
    @State private var isEditing = false
    @State private var editedText: String = ""
    @State private var lastTapTime: Date = Date()
    @State private var tapCount: Int = 0
    @State private var loadedImage: NSImage?
    @State private var isLoadingImage = false
    @State private var imageLoadError = false
    
    var body: some View {
        Group {
            switch element.type {
            case .text, .subtitle:
                textElementView
            case .image:
                imageElementView
            }
        }
        .frame(
            width: element.size.cgSize.width * scale,
            height: element.size.cgSize.height * scale
        )
        .offset(
            x: element.position.cgPoint.x * scale,
            y: element.position.cgPoint.y * scale
        )
    }
    
    private var textElementView: some View {
        Group {
            if isEditing {
                TextField("", text: $editedText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(fontForElement)
                    .foregroundColor(colorForElement)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(8)
                    .background(Color.white.opacity(0.1))
                    .onSubmit {
                        finishEditing()
                    }
                    .onAppear {
                        editedText = element.content
                    }
            } else {
                Text(element.content)
                    .font(fontForElement)
                    .foregroundColor(colorForElement)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(8)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        // Duplo clique: editar
                        onDoubleTap()
                        isEditing = true
                    }
                    .highPriorityGesture(
                        TapGesture()
                            .onEnded {
                                // Clique simples: selecionar (só se não for duplo clique)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    if !isEditing {
                                        handleSingleTap()
                                    }
                                }
                            }
                    )
            }
        }
        .overlay(
            Group {
                if isSelected && !isEditing {
                    selectionOverlay
                }
            }
        )
        .gesture(
            DragGesture(minimumDistance: 5)
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                        dragOffset = .zero
                    }
                    dragOffset = value.translation
                    onDrag(value.translation)
                }
                .onEnded { _ in
                    isDragging = false
                    dragOffset = .zero
                }
        )
    }
    
    private func handleSingleTap() {
        let now = Date()
        let timeSinceLastTap = now.timeIntervalSince(lastTapTime)
        
        if timeSinceLastTap < 0.3 {
            tapCount += 1
        } else {
            tapCount = 1
        }
        
        lastTapTime = now
        
        if tapCount == 1 {
            // Primeiro clique: apenas selecionar
            onSingleTap()
        }
    }
    
    private var imageElementView: some View {
        Group {
            if let image = loadedImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else if isLoadingImage {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if imageLoadError {
                RoundedRectangle(cornerRadius: 8)
                    .fill(DesignSystem.surface)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(DesignSystem.text.opacity(0.3))
                    )
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(DesignSystem.surface)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(DesignSystem.text.opacity(0.3))
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            loadImageAsync()
        }
        .onChange(of: element.content) { oldValue, newValue in
            if oldValue != newValue {
                loadedImage = nil
                imageLoadError = false
                loadImageAsync()
            }
        }
        .overlay(
            Group {
                if isSelected {
                    selectionOverlay
                }
            }
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSingleTap()
        }
        .gesture(
            DragGesture(minimumDistance: 5)
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                    }
                    onDrag(value.translation)
                }
                .onEnded { _ in
                    isDragging = false
                }
        )
    }
    
    private func loadImageAsync() {
        guard !element.content.isEmpty else {
            imageLoadError = true
            isLoadingImage = false
            loadedImage = nil
            return
        }
        
        // Tentar primeiro como URL direto
        if let url = URL(string: element.content) {
            loadImageFromURL(url)
            return
        }
        
        // Tentar com encoding
        if let urlString = element.content.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: urlString) {
            loadImageFromURL(url)
            return
        }
        
        imageLoadError = true
        isLoadingImage = false
        loadedImage = nil
    }
    
    private func loadImageFromURL(_ url: URL) {
        // Evitar recarregar se já está carregando ou já carregou a mesma URL
        if isLoadingImage {
            return
        }
        
        // Se já carregou e a URL não mudou, não recarregar
        if let existingImage = loadedImage, !imageLoadError {
            return
        }
        
        isLoadingImage = true
        imageLoadError = false
        
        // Usar URLSession para carregamento assíncrono adequado
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                self.isLoadingImage = false
                
                if let error = error {
                    print("Error loading image from \(url.absoluteString): \(error.localizedDescription)")
                    self.imageLoadError = true
                    self.loadedImage = nil
                    return
                }
                
                guard let data = data,
                      let image = NSImage(data: data) else {
                    print("Failed to create image from data for \(url.absoluteString)")
                    self.imageLoadError = true
                    self.loadedImage = nil
                    return
                }
                
                self.loadedImage = image
                self.imageLoadError = false
            }
        }.resume()
    }
    
    private var selectionOverlay: some View {
        ZStack {
            // Border
            RoundedRectangle(cornerRadius: 4)
                .stroke(DesignSystem.accent, lineWidth: 2)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Resize handles
            if element.type == .image {
                resizeHandles
            }
            
            // Regenerate button for images
            if element.type == .image {
                VStack {
                    HStack {
                        Spacer()
                        Button(action: onRegenerateImage) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                                .padding(6)
                                .background(DesignSystem.accent)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .padding(4)
            }
        }
    }
    
    private var resizeHandles: some View {
        Group {
            // Corner resize handle
            Circle()
                .fill(DesignSystem.accent)
                .frame(width: 12, height: 12)
                .position(x: element.size.cgSize.width * scale, y: element.size.cgSize.height * scale)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let newWidth = element.size.cgSize.width + value.translation.width / scale
                            let newHeight = element.size.cgSize.height + value.translation.height / scale
                            onResize(CGSize(width: newWidth, height: newHeight))
                        }
                )
        }
    }
    
    private var fontForElement: Font {
        let size = element.fontSize ?? (element.type == .subtitle ? 20 : 24)
        let weight: Font.Weight = element.fontWeight == "bold" ? .bold : 
                                  element.fontWeight == "medium" ? .medium : .regular
        return .system(size: size * scale, weight: weight)
    }
    
    private var colorForElement: Color {
        if let colorHex = element.color {
            return Color(hex: colorHex) ?? DesignSystem.text
        }
        return DesignSystem.text
    }
    
    private func finishEditing() {
        // Atualizar conteúdo do elemento
        element.content = editedText
        isEditing = false
    }
}

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

