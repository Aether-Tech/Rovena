import SwiftUI
#if os(macOS)
import AppKit
#endif

enum ResizeHandle {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
}

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
                        onResize: { handle, translation in
                            resizeElement(elementId: editableElement.id, handle: handle, translation: translation)
                        },
                        onResizeEnd: {
                            endResizing()
                        },
                        onRegenerateImage: {
                            onRegenerateImage(editableElement)
                        },
                        onRotate: {
                            rotateElement(elementId: editableElement.id)
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
    
    private func resizeElement(elementId: UUID, handle: ResizeHandle, translation: CGSize) {
        guard let index = slide.elements.firstIndex(where: { $0.id == elementId }) else { return }
        
        // Inicializar estado de resize no começo do gesto
        if resizingElementId != elementId {
            resizingElementId = elementId
            resizeStartSize = slide.elements[index].size.cgSize
            resizeStartPosition = slide.elements[index].position.cgPoint
        }
        
        let dx = translation.width / scale
        let dy = translation.height / scale
        let minSize: CGFloat = 50
        
        var newSize = resizeStartSize
        var newPosition = resizeStartPosition
        
        switch handle {
        case .topLeft:
            newPosition.x = resizeStartPosition.x + dx
            newPosition.y = resizeStartPosition.y + dy
            newSize.width = resizeStartSize.width - dx
            newSize.height = resizeStartSize.height - dy
        case .topRight:
            newPosition.y = resizeStartPosition.y + dy
            newSize.width = resizeStartSize.width + dx
            newSize.height = resizeStartSize.height - dy
        case .bottomLeft:
            newPosition.x = resizeStartPosition.x + dx
            newSize.width = resizeStartSize.width - dx
            newSize.height = resizeStartSize.height + dy
        case .bottomRight:
            newSize.width = resizeStartSize.width + dx
            newSize.height = resizeStartSize.height + dy
        }
        
        // Garantir tamanho mínimo
        newSize.width = max(minSize, newSize.width)
        newSize.height = max(minSize, newSize.height)
        
        slide.elements[index].position = CodablePoint(CGPoint(x: newPosition.x, y: newPosition.y))
        slide.elements[index].size = CodableSize(newSize)
    }
    
    private func endResizing() {
        resizingElementId = nil
    }
    
    private func rotateElement(elementId: UUID) {
        guard let index = slide.elements.firstIndex(where: { $0.id == elementId }) else { return }
        let currentRotation = slide.elements[index].rotation ?? 0
        let newRotation = (currentRotation + 90).truncatingRemainder(dividingBy: 360)
        slide.elements[index].rotation = newRotation
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
    let onResize: (ResizeHandle, CGSize) -> Void
    let onResizeEnd: () -> Void
    let onRegenerateImage: () -> Void
    let onRotate: () -> Void
    
    @State private var isDragging = false
    @State private var dragOffset: CGSize = .zero
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
                    .frame(
                        width: element.size.cgSize.width * scale,
                        height: element.size.cgSize.height * scale
                    )
            }
        }
        .clipped() // Garantir que o conteúdo seja cortado no frame
        .rotationEffect(.degrees(element.rotation ?? 0))
        .offset(
            x: element.position.cgPoint.x * scale,
            y: element.position.cgPoint.y * scale
        )
        .onChange(of: isSelected) { oldValue, newValue in
            if !newValue && isEditing {
                finishEditing()
            }
        }
    }
    
    private var textElementView: some View {
        Group {
            if isEditing {
                TextEditor(text: $editedText)
                    .font(fontForElement)
                    .foregroundColor(colorForElement)
                    .padding(8)
                    .background(Color.white.opacity(0.1))
                    .onAppear {
                        editedText = element.content
                    }
                    .onChange(of: editedText) { oldValue, newValue in
                        element.content = newValue
                    }
                    .background(textSizeReader)
            } else {
                Text(element.content)
                    .font(fontForElement)
                    .foregroundColor(colorForElement)
                    .shadow(color: .white.opacity(0.8), radius: 2, x: 0, y: 0) // Sombra branca para destacar em fundos escuros
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1) // Sombra preta para destacar em fundos claros
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(8)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        // Duplo clique: editar
                        onDoubleTap()
                        isEditing = true
                        editedText = element.content
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
                    .background(textSizeReader)
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
            DragGesture(minimumDistance: 8) // Aumentar distância mínima para evitar drag acidental
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
        GeometryReader { geometry in
            Group {
                if let image = loadedImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } else if isLoadingImage {
                    ProgressView()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                } else if imageLoadError {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(DesignSystem.surface)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(DesignSystem.text.opacity(0.3))
                        )
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(DesignSystem.surface)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(DesignSystem.text.opacity(0.3))
                        )
                }
            }
        }
        .frame(width: element.size.cgSize.width * scale, height: element.size.cgSize.height * scale)
        .contentShape(Rectangle())
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
            DragGesture(minimumDistance: 8) // Aumentar distância mínima para evitar drag acidental
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
        if loadedImage != nil && !imageLoadError {
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
            
            // Action buttons for images
            if element.type == .image {
                VStack {
                    HStack {
                        Spacer()
                        // Rotate button
                        Button(action: onRotate) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                                .padding(6)
                                .background(DesignSystem.accent)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Rotate image")
                        
                        // Regenerate button
                        Button(action: onRegenerateImage) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                                .padding(6)
                                .background(Color.orange)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Regenerate image")
                    }
                    Spacer()
                }
                .padding(4)
            }
        }
    }
    
    private var resizeHandles: some View {
        let handleSize: CGFloat = 16
        let minDragDistance: CGFloat = 5
        let elementWidth = element.size.cgSize.width * scale
        let elementHeight = element.size.cgSize.height * scale
        
        func handleCursor() -> some ViewModifier {
            // Helper vazio para iOS; cursor só em macOS
            struct EmptyMod: ViewModifier {
                func body(content: Content) -> some View { content }
            }
            #if os(macOS)
            struct CursorMod: ViewModifier {
                let cursor: NSCursor
                func body(content: Content) -> some View {
                    content.onHover { hovering in
                        if hovering {
                            cursor.set()
                        } else {
                            NSCursor.arrow.set()
                        }
                    }
                }
            }
            return CursorMod(cursor: NSCursor.crosshair)
            #else
            return EmptyMod()
            #endif
        }
        
        return ZStack {
            // Handle canto superior esquerdo
            Circle()
                .fill(DesignSystem.accent)
                .frame(width: handleSize, height: handleSize)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
                .position(x: 0, y: 0)
                .modifier(handleCursor())
                .gesture(
                    DragGesture(minimumDistance: minDragDistance)
                        .onChanged { value in
                            onResize(.topLeft, value.translation)
                        }
                        .onEnded { _ in
                            onResizeEnd()
                        }
                )
            
            // Handle canto superior direito
            Circle()
                .fill(DesignSystem.accent)
                .frame(width: handleSize, height: handleSize)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
                .position(x: elementWidth, y: 0)
                .modifier(handleCursor())
                .gesture(
                    DragGesture(minimumDistance: minDragDistance)
                        .onChanged { value in
                            onResize(.topRight, value.translation)
                        }
                        .onEnded { _ in
                            onResizeEnd()
                        }
                )
            
            // Handle canto inferior esquerdo
            Circle()
                .fill(DesignSystem.accent)
                .frame(width: handleSize, height: handleSize)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
                .position(x: 0, y: elementHeight)
                .modifier(handleCursor())
                .gesture(
                    DragGesture(minimumDistance: minDragDistance)
                        .onChanged { value in
                            onResize(.bottomLeft, value.translation)
                        }
                        .onEnded { _ in
                            onResizeEnd()
                        }
                )
            
            // Handle canto inferior direito
            Circle()
                .fill(DesignSystem.accent)
                .frame(width: handleSize, height: handleSize)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
                .position(x: elementWidth, y: elementHeight)
                .modifier(handleCursor())
                .gesture(
                    DragGesture(minimumDistance: minDragDistance)
                        .onChanged { value in
                            onResize(.bottomRight, value.translation)
                        }
                        .onEnded { _ in
                            onResizeEnd()
                        }
                )
        }
        .frame(width: elementWidth, height: elementHeight)
    }
    
    private var fontForElement: Font {
        let size = element.fontSize ?? (element.type == .subtitle ? 20 : 24)
        let weight: Font.Weight = element.fontWeight == "bold" ? .bold : 
                                  element.fontWeight == "medium" ? .medium : .regular
        return .system(size: size * scale, weight: weight)
    }
    
    private var colorForElement: Color {
        // Se o elemento tem uma cor definida, usar ela
        if let colorHex = element.color {
            return Color(hex: colorHex) ?? getContrastingTextColor()
        }
        
        // Caso contrário, usar cor que contrasta com o fundo
        return getContrastingTextColor()
    }
    
    private func getContrastingTextColor() -> Color {
        // Por padrão, o canvas tem fundo branco, então usar texto escuro
        // Se houver imagem de fundo ou fundo escuro, usar texto claro
        // Por enquanto, vamos usar uma cor escura que funciona bem em fundos claros
        // e adicionar sombra para funcionar em qualquer fundo
        
        // Cor escura com boa legibilidade
        return Color(red: 0.1, green: 0.1, blue: 0.15) // Quase preto com leve tom azul
    }
    
    private var textSizeReader: some View {
        GeometryReader { geo in
            Color.clear
                .onAppear {
                    updateTextSizeIfNeeded(geo.size)
                }
                .onChange(of: geo.size) { oldValue, newValue in
                    updateTextSizeIfNeeded(newValue)
                }
        }
    }
    
    private func updateTextSizeIfNeeded(_ size: CGSize) {
        // Converter tamanho da view (já escalada) para coordenadas do canvas
        let contentWidth = size.width / scale
        let contentHeight = size.height / scale
        let minWidth: CGFloat = 50
        let minHeight: CGFloat = 30
        let newWidth = max(minWidth, contentWidth)
        let newHeight = max(minHeight, contentHeight)
        
        let currentSize = element.size.cgSize
        if abs(currentSize.width - newWidth) > 0.5 || abs(currentSize.height - newHeight) > 0.5 {
            element.size = CodableSize(CGSize(width: newWidth, height: newHeight))
        }
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

