import SwiftUI

struct ToDoView: View {
    @ObservedObject var todoService = ToDoService.shared
    @State private var showAddTaskSheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Tasks")
                    .font(DesignSystem.font(size: 14, weight: .semibold))
                    .foregroundColor(DesignSystem.text.opacity(0.7))
                
                Spacer()
                
                Text("\(todoService.items.filter { !$0.isCompleted }.count) pending")
                    .font(DesignSystem.font(size: 12))
                    .foregroundColor(DesignSystem.text.opacity(0.5))
            }
            .padding()
            .background(DesignSystem.background)
            .overlay(Rectangle().frame(height: 0.5).foregroundColor(DesignSystem.border), alignment: .bottom)
            
            // List
            List {
                ForEach(todoService.items) { item in
                    ToDoRow(item: item)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .onDelete(perform: todoService.deleteItem)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(DesignSystem.background)
            
            // Footer Action
            VStack {
                Button(action: { showAddTaskSheet = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("New Task")
                    }
                    .font(DesignSystem.font(size: 14, weight: .medium))
                    .foregroundColor(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(DesignSystem.accent)
                    .clipShape(SquircleShape())
                    .shadow(radius: 2)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(DesignSystem.background)
            .overlay(Rectangle().frame(height: 0.5).foregroundColor(DesignSystem.border), alignment: .top)
        }
        .sheet(isPresented: $showAddTaskSheet) {
            AddTaskView(isPresented: $showAddTaskSheet)
        }
    }
}

struct AddTaskView: View {
    @Binding var isPresented: Bool
    @State private var title: String = ""
    @State private var description: String = ""
    @FocusState private var isTitleFocused: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Text("New Task")
                .font(DesignSystem.font(size: 18, weight: .bold))
                .foregroundColor(DesignSystem.text)
                .padding(.top)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Title")
                    .font(DesignSystem.font(size: 12, weight: .medium))
                    .foregroundColor(DesignSystem.text.opacity(0.7))
                
                TextField("What needs to be done?", text: $title)
                    .textFieldStyle(.plain)
                    .font(DesignSystem.font(size: 14))
                    .foregroundColor(DesignSystem.text)
                    .padding(10)
                    .background(DesignSystem.surface.opacity(0.5))
                    .clipShape(SquircleShape())
                    .overlay(
                        SquircleShape()
                            .stroke(DesignSystem.border.opacity(0.5), lineWidth: 1)
                    )
                    .focused($isTitleFocused)
                    .onKeyPress { press in
                        guard press.key == .return else { return .ignored }
                        if press.modifiers.contains(.shift) {
                            // Shift+Enter: allow default behavior (though TextField doesn't support line breaks)
                            return .ignored
                        }
                        // Enter: create task
                        if !title.isEmpty {
                            saveTask()
                        }
                        return .handled
                    }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Description")
                    .font(DesignSystem.font(size: 12, weight: .medium))
                    .foregroundColor(DesignSystem.text.opacity(0.7))
                
                TextEditor(text: $description)
                    .font(DesignSystem.font(size: 14))
                    .foregroundColor(DesignSystem.text)
                    .frame(height: 100)
                    .padding(4)
                    .background(DesignSystem.surface.opacity(0.5))
                    .clipShape(SquircleShape())
                    .overlay(
                        SquircleShape()
                            .stroke(DesignSystem.border.opacity(0.5), lineWidth: 1)
                    )
                    .scrollContentBackground(.hidden)
                    .onKeyPress { press in
                        guard press.key == .return else { return .ignored }
                        if press.modifiers.contains(.shift) {
                            // Shift+Enter: allow line break (default behavior)
                            return .ignored
                        }
                        // Enter: create task
                        if !title.isEmpty {
                            saveTask()
                        }
                        return .handled
                    }
            }
            
            HStack(spacing: 16) {
                Button(action: {
                    isPresented = false
                }) {
                    Text("Cancel")
                        .font(DesignSystem.font(size: 13, weight: .medium))
                        .foregroundColor(DesignSystem.text.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .background(DesignSystem.surface.opacity(0.5))
                        .clipShape(SquircleShape())
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    saveTask()
                }) {
                    Text("Create Task")
                        .font(DesignSystem.font(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .background(title.isEmpty ? Color.gray : DesignSystem.accent)
                        .clipShape(SquircleShape())
                }
                .buttonStyle(.plain)
                .disabled(title.isEmpty)
            }
            .padding(.top, 10)
            
            Spacer()
        }
        .padding()
        .frame(width: 400, height: 400)
        .background(DesignSystem.background)
        .onAppear {
            isTitleFocused = true
        }
    }
    
    func saveTask() {
        guard !title.isEmpty else { return }
        // Force UI update by performing on main thread
        DispatchQueue.main.async {
            ToDoService.shared.addItem(content: title, description: description)
            isPresented = false
        }
    }
}

struct ToDoRow: View {
    let item: ToDoItem
    @State private var isExpanded = false
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                Button(action: {
                    DispatchQueue.main.async {
                        ToDoService.shared.toggleItem(item.id)
                    }
                }) {
                    Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(item.isCompleted ? .green : DesignSystem.text.opacity(0.5))
                        .font(.system(size: 20))
                }
                .buttonStyle(.plain)
                
                Text(item.content)
                    .font(DesignSystem.font(size: 15))
                    .foregroundColor(item.isCompleted ? .gray : DesignSystem.text)
                    .strikethrough(item.isCompleted)
                
                Spacer()
                
                // Delete Icon on Hover
                if isHovered {
                    Button(action: {
                        DispatchQueue.main.async {
                            ToDoService.shared.deleteItem(item.id)
                        }
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundColor(.red.opacity(0.8))
                            .frame(width: 30, height: 30)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                
                if !item.description.isEmpty {
                    Button(action: {
                         withAnimation {
                             isExpanded.toggle()
                         }
                    }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(DesignSystem.text.opacity(0.5))
                            .frame(width: 30, height: 30)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if isExpanded && !item.description.isEmpty {
                Text(item.description)
                    .font(DesignSystem.font(size: 13))
                    .foregroundColor(DesignSystem.text.opacity(0.7))
                    .padding(.leading, 32)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
            }
        }
        .padding()
        .background(isHovered ? DesignSystem.surface.opacity(0.5) : Color.clear)
        .clipShape(SquircleShape())
        .contentShape(SquircleShape())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}
