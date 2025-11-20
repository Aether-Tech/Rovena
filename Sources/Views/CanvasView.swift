import SwiftUI

struct CanvasView: View {
    @ObservedObject var canvasService = CanvasService.shared
    @State private var currentTool: CanvasTool = .selection
    @State private var selectedColor: Color = .white
    @State private var showColorPicker = false
    
    // Viewport State
    @State private var panOffset: CGSize = .zero
    @State private var currentDragOffset: CGSize = .zero
    
    // Selection State
    @State private var selectedElementIds: Set<UUID> = []
    @State private var selectionRect: CGRect?
    
    // Interaction State
    @State private var dragStart: CGPoint?
    @State private var currentDragLocation: CGPoint?
    @State private var currentElement: CanvasElement?
    @State private var isPanning = false
    
    // Text Editing
    @State private var editingElementId: UUID?
    @State private var editText: String = ""
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Canvas Area
            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    // Grid Background (Infinite-ish)
                    GridBackground(offset: totalOffset)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // Elements
                    ForEach(canvasService.elements) { element in
                        ElementView(
                            element: element,
                            isSelected: selectedElementIds.contains(element.id),
                            currentTool: currentTool,
                            onTap: {
                                handleElementTap(element)
                            },
                            onDoubleTap: { id, text in
                                editingElementId = id
                                editText = text
                            },
                            onDragStart: {
                                if !selectedElementIds.contains(element.id) {
                                    selectedElementIds = [element.id]
                                }
                            },
                            onDrag: { offset in
                                moveSelectedElements(offset: offset)
                            },
                            onDragEnd: { offset in
                                commitMoveSelectedElements(offset: offset)
                            }
                        )
                        .offset(x: element.position.x + totalOffset.width,
                                y: element.position.y + totalOffset.height)
                    }
                    
                    // Eraser Path (Visual Feedback)
                    if currentTool == .eraser, let start = dragStart, let current = currentDragLocation {
                         Path { path in
                             path.move(to: start)
                             path.addLine(to: current)
                         }
                         .stroke(Color.red.opacity(0.5), lineWidth: 10)
                         .offset(x: totalOffset.width, y: totalOffset.height)
                    }
                    
                    // Current Drawing Element
                    if let current = currentElement {
                        ElementView(element: current, isSelected: false, currentTool: .brush, onTap: {}, onDoubleTap: {_,_ in}, onDragStart: {}, onDrag: {_ in}, onDragEnd: {_ in})
                            .offset(x: current.position.x + totalOffset.width,
                                    y: current.position.y + totalOffset.height)
                    }
                    
                    // Selection Marquee
                    if let rect = selectionRect {
                        Rectangle()
                            .fill(Color.blue.opacity(0.2))
                            .overlay(Rectangle().stroke(Color.blue, lineWidth: 1))
                            .frame(width: rect.width, height: rect.height)
                            .offset(x: rect.minX + totalOffset.width, y: rect.minY + totalOffset.height)
                    }
                }
                .background(DesignSystem.background.opacity(0.9))
                .contentShape(Rectangle()) // Capture taps on empty space
                .clipped() // Prevent drawing outside
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { value in
                            handleBackgroundDrag(value: value)
                        }
                        .onEnded { value in
                            handleBackgroundDragEnd(value: value)
                        }
                )
            }
            
            // Text Editing Overlay
            if let id = editingElementId, let index = canvasService.elements.firstIndex(where: { $0.id == id }) {
                VStack {
                    HStack {
                        TextField("Edit Text", text: $editText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 200)
                            .onSubmit {
                                commitTextEdit()
                            }
                        
                        Button("Done") {
                            commitTextEdit()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .background(DesignSystem.background)
                    .border(DesignSystem.border, width: 1)
                    .offset(y: -100) // Position above toolbar
                }
            }
            
                    HStack(spacing: 12) {
                // Undo/Redo Group
                HStack(spacing: 4) {
                    Button {
                        canvasService.undo()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 14))
                            .frame(width: 28, height: 28)
                            .foregroundColor(canvasService.canUndo ? DesignSystem.text : DesignSystem.text.opacity(0.3))
                    }
                    .disabled(!canvasService.canUndo)
                    .buttonStyle(.plain)
                    
                    Button {
                        canvasService.redo()
                    } label: {
                        Image(systemName: "arrow.uturn.forward")
                            .font(.system(size: 14))
                            .frame(width: 28, height: 28)
                            .foregroundColor(canvasService.canRedo ? DesignSystem.text : DesignSystem.text.opacity(0.3))
                    }
                    .disabled(!canvasService.canRedo)
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .background(DesignSystem.surface.opacity(0.5))
                .cornerRadius(4)
                
                Divider()
                    .frame(height: 20)
                    .background(DesignSystem.border)
                
                ForEach(CanvasTool.allCases, id: \.self) { tool in
                    Button {
                        currentTool = tool
                        selectedElementIds.removeAll() // Clear selection on tool change
                    } label: {
                        Image(systemName: tool.rawValue)
                            .font(.system(size: 16))
                            .frame(width: 32, height: 32)
                            .background(currentTool == tool ? DesignSystem.accent : Color.clear)
                            .foregroundColor(currentTool == tool ? DesignSystem.background : DesignSystem.accent)
                            .overlay(Rectangle().stroke(DesignSystem.border, lineWidth: 1))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                
                Divider()
                    .frame(height: 20)
                    .background(DesignSystem.border)
                
                // Custom Color Picker Trigger
                Button {
                    showColorPicker.toggle()
                } label: {
                    Circle()
                    .fill(selectedColor)
                    .frame(width: 24, height: 24)
                    .overlay(Circle().stroke(DesignSystem.border, lineWidth: 1))
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showColorPicker, arrowEdge: .bottom) {
                     ColorPaletteView(selectedColor: $selectedColor)
                }
                
                Divider()
                    .frame(height: 20)
                    .background(DesignSystem.border)
                
                Button {
                    if !selectedElementIds.isEmpty {
                        for id in selectedElementIds {
                            canvasService.removeElement(id: id)
                        }
                        selectedElementIds.removeAll()
                    } else {
                        canvasService.clearAll()
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundColor(.red)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(8)
            .background(DesignSystem.background)
            .overlay(Rectangle().stroke(DesignSystem.border, lineWidth: 1))
            .padding(.bottom, 16)
        }
        .background(DesignSystem.background)
        .onTapGesture {
            // Clear selection if tapping background (this might be captured by the drag gesture instead)
            if currentTool == .selection {
                selectedElementIds.removeAll()
            }
        }
    }
    
    var totalOffset: CGSize {
        CGSize(width: panOffset.width + currentDragOffset.width,
               height: panOffset.height + currentDragOffset.height)
    }
    
    // MARK: - Interaction Handlers
    
    func handleBackgroundDrag(value: DragGesture.Value) {
        if currentTool == .hand {
            currentDragOffset = value.translation
            return
        }
        
        let screenLocation = value.location
        let canvasLocation = CGPoint(x: screenLocation.x - totalOffset.width,
                                     y: screenLocation.y - totalOffset.height)
        
        currentDragLocation = canvasLocation
        
        if dragStart == nil {
            dragStart = canvasLocation
            
            // If in selection mode and clicking background, start marquee
            if currentTool == .selection {
                // Clear selection if not adding (Shift key support could be added here)
                selectedElementIds.removeAll()
            }
            
            // Eraser Start
            if currentTool == .eraser {
               handleEraser(at: canvasLocation)
            }
        }
        
        guard let start = dragStart else { return }
        
        if currentTool == .eraser {
            handleEraser(at: canvasLocation)
            return
        }
        
        if currentTool == .selection {
            // Update marquee selection rect
            let rect = CGRect(x: min(start.x, canvasLocation.x),
                              y: min(start.y, canvasLocation.y),
                              width: abs(canvasLocation.x - start.x),
                              height: abs(canvasLocation.y - start.y))
            selectionRect = rect
            
            // Update selection in real-time
            let hits = canvasService.elements.filter { element in
                let elRect = CGRect(x: element.position.x, y: element.position.y, width: element.size.width, height: element.size.height)
                return rect.intersects(elRect)
            }
            selectedElementIds = Set(hits.map { $0.id })
            
        } else {
            // Creation Logic
            let width = canvasLocation.x - start.x
            let height = canvasLocation.y - start.y
            
            switch currentTool {
            case .rectangle:
                currentElement = CanvasElement(type: .rectangle, position: start, size: CGSize(width: width, height: height), color: selectedColor, text: "RECT")
            case .circle:
                currentElement = CanvasElement(type: .circle, position: start, size: CGSize(width: width, height: height), color: selectedColor, text: "CIRCLE")
            case .line:
                currentElement = CanvasElement(type: .line, position: start, size: CGSize(width: width, height: height), color: selectedColor)
            case .brush:
                if currentElement == nil {
                    currentElement = CanvasElement(type: .brush, position: .zero, size: .zero, color: selectedColor, points: [start])
                }
                currentElement?.points?.append(canvasLocation)
            default: break
            }
        }
    }
    
    func handleBackgroundDragEnd(value: DragGesture.Value) {
        if currentTool == .hand {
            panOffset.width += value.translation.width
            panOffset.height += value.translation.height
            currentDragOffset = .zero
            return
        }
        
        if currentTool == .selection {
            selectionRect = nil
            dragStart = nil
            currentDragLocation = nil
            return
        }
        
        if currentTool == .eraser {
             dragStart = nil
             currentDragLocation = nil
             return
        }
        
        if currentTool == .text {
            let screenLocation = value.location
            let canvasLocation = CGPoint(x: screenLocation.x - totalOffset.width,
                                         y: screenLocation.y - totalOffset.height)
            
            let textEl = CanvasElement(type: .text, position: canvasLocation, size: .zero, color: selectedColor, text: "DOUBLE TAP TO EDIT")
            canvasService.addElement(textEl)
        } else if var element = currentElement {
            // Normalize size (width/height should be positive for shapes, but position might need adjustment)
            if element.type == .rectangle || element.type == .circle {
                let rect = CGRect(x: element.position.x, y: element.position.y, width: element.size.width, height: element.size.height)
                let normalized = rect.standardized
                element.position = normalized.origin
                element.size = normalized.size
            }
            
            canvasService.addElement(element)
        }
        
        currentElement = nil
        dragStart = nil
        currentDragLocation = nil
    }
    
    func handleEraser(at location: CGPoint) {
        // Simple eraser: delete elements intersecting with a small radius
        let eraserRadius: CGFloat = 10
        let eraserRect = CGRect(x: location.x - eraserRadius, y: location.y - eraserRadius, width: eraserRadius * 2, height: eraserRadius * 2)
        
        // Find elements to remove
        let idsToRemove = canvasService.elements.compactMap { element -> UUID? in
            let elementRect = CGRect(x: element.position.x, y: element.position.y, width: element.size.width, height: element.size.height)
            
            // Basic AABB collision for most shapes
            // For Brush, we should check points, but bounding box is a start
            if elementRect.intersects(eraserRect) {
                return element.id
            }
            return nil
        }
        
        for id in idsToRemove {
            canvasService.removeElement(id: id)
        }
    }
    
    func handleElementTap(_ element: CanvasElement) {
        if currentTool == .selection {
            selectedElementIds = [element.id]
        }
    }
    
    func moveSelectedElements(offset: CGSize) {
        // Visual update only, handled by ElementView offset usually, 
        // but we need to update the actual data eventually.
        // For SwiftUI performance, maybe we should just update the view state?
        // ElementView handles its own drag offset visually.
    }
    
    func commitMoveSelectedElements(offset: CGSize) {
        for id in selectedElementIds {
            if var element = canvasService.elements.first(where: { $0.id == id }) {
                element.position.x += offset.width
                element.position.y += offset.height
                canvasService.updateElement(element)
            }
        }
    }
    
    func commitTextEdit() {
        guard let id = editingElementId else { return }
        if var element = canvasService.elements.first(where: { $0.id == id }) {
            element.text = editText
            canvasService.updateElement(element)
        }
        editingElementId = nil
        editText = ""
    }
}

struct ElementView: View {
    let element: CanvasElement
    let isSelected: Bool
    let currentTool: CanvasTool
    
    var onTap: () -> Void
    var onDoubleTap: (UUID, String) -> Void
    var onDragStart: () -> Void
    var onDrag: (CGSize) -> Void
    var onDragEnd: (CGSize) -> Void
    
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    
    var body: some View {
        Group {
            switch element.type {
            case .rectangle:
                ZStack {
                    Rectangle()
                        .stroke(element.color, lineWidth: 2)
                        .background(element.color.opacity(0.1))
                    
                    if let text = element.text {
                        Text(text)
                            .font(DesignSystem.font(size: 12))
                            .foregroundColor(element.color)
                            .multilineTextAlignment(.center)
                            .allowsHitTesting(false)
                    }
                }
                .frame(width: max(1, abs(element.size.width)), height: max(1, abs(element.size.height)))
                
            case .circle:
                ZStack {
                    Circle()
                        .stroke(element.color, lineWidth: 2)
                        .background(Circle().fill(element.color.opacity(0.1)))
                    
                    if let text = element.text {
                        Text(text)
                            .font(DesignSystem.font(size: 12))
                            .foregroundColor(element.color)
                            .multilineTextAlignment(.center)
                            .allowsHitTesting(false)
                    }
                }
                .frame(width: max(1, abs(element.size.width)), height: max(1, abs(element.size.height)))
                
            case .line:
                // For line, we render it relative to its own position (0,0) in the view, 
                // because the view itself is offset.
                Path { path in
                    path.move(to: .zero)
                    path.addLine(to: CGPoint(x: element.size.width, y: element.size.height))
                }
                .stroke(element.color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: abs(element.size.width), height: abs(element.size.height))
                
            case .text:
                Text(element.text ?? "")
                    .font(.custom("Courier New", size: 16))
                    .foregroundColor(element.color)
                    .padding(4)
                    .background(DesignSystem.background.opacity(0.5))
                    .border(DesignSystem.border.opacity(0.5), width: 1)
                
            case .brush:
                if let points = element.points, !points.isEmpty {
                    // Brush points are absolute canvas coordinates.
                    // Since ElementView is offset by element.position (which is 0,0 for brush usually),
                    // we might need to handle this differently.
                    // But usually brush 'position' is 0,0.
                    Path { path in
                        path.move(to: points[0])
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(element.color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
            }
        }
        .overlay(
            isSelected ? 
                Rectangle()
                    .stroke(DesignSystem.accent, style: StrokeStyle(lineWidth: 1, dash: [5]))
                    .padding(-4)
                : nil
        )
        .contentShape(Rectangle()) // Important for hit testing
        .offset(x: isDragging ? dragOffset.width : 0, y: isDragging ? dragOffset.height : 0)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if currentTool == .selection {
                        if !isDragging {
                            onDragStart()
                            isDragging = true
                        }
                        dragOffset = value.translation
                        onDrag(value.translation)
                    }
                }
                .onEnded { value in
                    if currentTool == .selection {
                        isDragging = false
                        onDragEnd(value.translation)
                        dragOffset = .zero
                    }
                }
        )
        .onTapGesture(count: 2) {
            if currentTool == .selection {
                onDoubleTap(element.id, element.text ?? "")
            }
        }
        .onTapGesture {
            if currentTool == .selection {
                onTap()
            }
        }
    }
}

struct GridBackground: View {
    var offset: CGSize
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let step: CGFloat = 40
                
                // Calculate start points based on offset to make grid "move"
                let startX = offset.width.truncatingRemainder(dividingBy: step)
                let startY = offset.height.truncatingRemainder(dividingBy: step)
                
                // Vertical lines
                for x in stride(from: startX, to: geometry.size.width, by: step) {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                }
                
                // Horizontal lines
                for y in stride(from: startY, to: geometry.size.height, by: step) {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                }
            }
            .stroke(DesignSystem.text.opacity(0.05), lineWidth: 1)
        }
    }
}

struct ColorPaletteView: View {
    @Binding var selectedColor: Color
    
    let colors: [Color] = [
        .white, .black, .gray,
        .red, .orange, .yellow,
        .green, .blue, .purple,
        .pink, .cyan, .brown
    ]
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 30))], spacing: 8) {
            ForEach(colors, id: \.self) { color in
                Circle()
                    .fill(color)
                    .frame(width: 30, height: 30)
                    .overlay(
                        Circle()
                            .stroke(DesignSystem.border, lineWidth: 1)
                    )
                    .overlay(
                        selectedColor == color ?
                        Circle()
                            .stroke(DesignSystem.accent, lineWidth: 2)
                        : nil
                    )
                    .onTapGesture {
                        selectedColor = color
                    }
            }
        }
        .padding()
        .frame(width: 200)
        .background(DesignSystem.background)
    }
}
