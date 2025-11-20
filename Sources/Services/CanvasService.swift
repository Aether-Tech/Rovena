import Foundation
import SwiftUI

class CanvasService: ObservableObject {
    static let shared = CanvasService()
    
    @Published var elements: [CanvasElement] = []
    
    // Undo/Redo Stack
    @Published var canUndo = false
    @Published var canRedo = false
    
    private var undoStack: [[CanvasElement]] = []
    private var redoStack: [[CanvasElement]] = []
    private let maxStackSize = 50
    
    private let fileName = "canvas_elements.json"
    
    private init() {
        loadElements()
    }
    
    // MARK: - History Management
    
    private func pushToUndo() {
        undoStack.append(elements)
        if undoStack.count > maxStackSize {
            undoStack.removeFirst()
        }
        redoStack.removeAll() // Clear redo when new action is taken
        updateHistoryState()
    }
    
    func undo() {
        guard !undoStack.isEmpty else { return }
        
        let current = elements
        redoStack.append(current)
        
        elements = undoStack.removeLast()
        saveElements()
        updateHistoryState()
    }
    
    func redo() {
        guard !redoStack.isEmpty else { return }
        
        let current = elements
        undoStack.append(current)
        
        elements = redoStack.removeLast()
        saveElements()
        updateHistoryState()
    }
    
    private func updateHistoryState() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }
    
    // MARK: - File Management
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func getFileURL() -> URL {
        getDocumentsDirectory().appendingPathComponent(fileName)
    }
    
    func saveElements() {
        do {
            let data = try JSONEncoder().encode(elements)
            try data.write(to: getFileURL())
        } catch {
            print("Error saving canvas elements: \(error)")
        }
    }
    
    func loadElements() {
        let url = getFileURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        
        do {
            let data = try Data(contentsOf: url)
            elements = try JSONDecoder().decode([CanvasElement].self, from: data)
        } catch {
            print("Error loading canvas elements: \(error)")
        }
    }
    
    // MARK: - Element Management
    
    func addElement(_ element: CanvasElement) {
        pushToUndo()
        elements.append(element)
        saveElements()
    }
    
    func updateElement(_ element: CanvasElement) {
        if let index = elements.firstIndex(where: { $0.id == element.id }) {
            // Only push to undo if actual change happened? 
            // For now, assume significant update.
            // Ideally we check diff, but simple is better for now.
            // Warning: Dragging updates frequently, might flood stack.
            // The view handles commit vs drag, so this is likely called on commit.
            pushToUndo()
            elements[index] = element
            saveElements()
        }
    }
    
    func removeElement(id: UUID) {
        pushToUndo()
        elements.removeAll { $0.id == id }
        saveElements()
    }
    
    func clearAll() {
        pushToUndo()
        elements.removeAll()
        saveElements()
    }
}


