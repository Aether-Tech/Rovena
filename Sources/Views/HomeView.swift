import SwiftUI

struct HomeView: View {
    @Binding var selection: NavigationItem?
    @Binding var activeSessionId: UUID?
    
    @State private var inputText: String = ""
    @FocusState private var isInputFocused: Bool
    @ObservedObject var historyService = HistoryService.shared
    @ObservedObject var todoService = ToDoService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 40) {
            // Header Section
            VStack(alignment: .leading, spacing: 10) {
                Text("Welcome back")
                    .font(DesignSystem.font(size: 32, weight: .bold))
                    .foregroundColor(DesignSystem.text)
                
                HStack {
                    Text("Personal AI Workspace")
                        .font(DesignSystem.font(size: 14))
                        .foregroundColor(DesignSystem.text.opacity(0.6))
                    
                    Spacer()
                    
                    Text(Date().formatted(date: .complete, time: .omitted))
                        .font(DesignSystem.font(size: 14))
                        .foregroundColor(DesignSystem.text.opacity(0.6))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .elementStyle()
                }
            }
            .padding(.horizontal)
            
            // Usage Stats
            HStack(spacing: 20) {
                StatCard(title: "Total Sessions", value: "\(historyService.sessions.count)")
                StatCard(title: "Total Messages", value: "\(totalMessages)")
                StatCard(title: "Archived", value: "\(archivedCount)")
            }
            .padding(.horizontal)
            
            // Dashboard Grid
            VStack(alignment: .leading, spacing: 20) {
                // Quick Action Input (Top)
                VStack(alignment: .leading, spacing: 12) {
                    Text("New Session")
                        .font(DesignSystem.font(size: 14, weight: .semibold))
                        .foregroundColor(DesignSystem.text)
                    
                    HStack {
                        TextField("Ask anything...", text: $inputText)
                            .textFieldStyle(.plain)
                            .font(DesignSystem.font(size: 16))
                            .foregroundColor(DesignSystem.text)
                            .focused($isInputFocused)
                            .onSubmit {
                                startNewSession()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    isInputFocused = true
                                }
                            }
                        
                        Button {
                            startNewSession()
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(DesignSystem.accent)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding()
                    .elementStyle()
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                
                // ToDo Widget (Bottom - Full Width)
                HomeToDoWidget()
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding(.vertical, 40)
        .background(DesignSystem.background)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isInputFocused = true
            }
        }
    }
    
    private var totalMessages: Int {
        historyService.sessions.reduce(0) { $0 + $1.messages.count }
    }
    
    private var archivedCount: Int {
        historyService.sessions.filter { $0.creationDate < Date().addingTimeInterval(-86400) }.count
    }
    
    private func startNewSession() {
        guard !inputText.isEmpty else { return }
        
        let session = historyService.createNewSession()
        let message = ChatMessage(role: .user, content: inputText)
        historyService.addMessage(message, to: session.id)
        
        // Update State to navigate
        activeSessionId = session.id
        selection = .chat
        inputText = ""
    }
}

struct StatCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(DesignSystem.font(size: 12))
                .foregroundColor(DesignSystem.text.opacity(0.6))
            
            Text(value)
                .font(DesignSystem.font(size: 24, weight: .bold))
                .foregroundColor(DesignSystem.text)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .elementStyle()
    }
}

struct HomeToDoWidget: View {
    @ObservedObject var todoService = ToDoService.shared
    @State private var showAddTaskSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Tasks (\(todoService.items.filter { !$0.isCompleted }.count) pending)")
                    .font(DesignSystem.font(size: 14, weight: .semibold))
                    .foregroundColor(DesignSystem.text)
                
                Spacer()
                
                // Simple visual indicator
                Circle()
                    .fill(DesignSystem.accent)
                    .frame(width: 6, height: 6)
                    .opacity(todoService.items.isEmpty ? 0.2 : 1.0)
            }
            
            VStack(spacing: 0) {
                // Task List
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(todoService.items) { item in
                            ToDoRow(item: item)
                                .padding(.horizontal, 8)
                        }
                    }
                }
                .frame(height: 300)
                .elementStyle()
                
                // Footer Action
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
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cornerRadius))
                    .shadow(radius: 2)
                }
                .buttonStyle(.plain)
                .padding(.top, 12)
            }
        }
        .sheet(isPresented: $showAddTaskSheet) {
            AddTaskView(isPresented: $showAddTaskSheet)
        }
    }
}
