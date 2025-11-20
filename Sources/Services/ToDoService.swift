import Foundation
import SwiftUI

@MainActor
class ToDoService: ObservableObject {
    static let shared = ToDoService()
    
    @Published var items: [ToDoItem] = []
    
    private let fileName = "todo_list.json"
    
    private init() {
        loadItems()
    }
    
    // MARK: - File Management
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func getFileURL() -> URL {
        getDocumentsDirectory().appendingPathComponent(fileName)
    }
    
    func saveItems() {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: getFileURL())
        } catch {
            print("Error saving todos: \(error)")
        }
    }
    
    func loadItems() {
        let url = getFileURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        
        do {
            let data = try Data(contentsOf: url)
            items = try JSONDecoder().decode([ToDoItem].self, from: data)
            // Sort by created at (newest first) or completion status?
            // Let's keep user order or newest first.
            items.sort { $0.createdAt > $1.createdAt }
        } catch {
            print("Error loading todos: \(error)")
        }
    }
    
    // MARK: - Management
    
    func addItem(content: String, description: String = "") {
        let item = ToDoItem(content: content, description: description)
        items.insert(item, at: 0)
        saveItems()
    }
    
    func toggleItem(_ id: UUID) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].isCompleted.toggle()
            saveItems()
        }
    }
    
    func deleteItem(_ id: UUID) {
        items.removeAll { $0.id == id }
        saveItems()
    }
    
    func deleteItem(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        saveItems()
    }
}

