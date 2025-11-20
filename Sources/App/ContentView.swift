import SwiftUI

enum NavigationItem: String, CaseIterable, Identifiable {
    case dashboard = "Home"
    case chat = "Chat"
    case history = "Archives"
    case canvas = "Canvas"
    case todo = "Tasks"
    case settings = "Settings"
    case profile = "Profile"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .chat: return "message"
        case .history: return "clock"
        case .canvas: return "scribble"
        case .todo: return "checklist"
        case .settings: return "gearshape"
        case .profile: return "person.circle"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var settings: SettingsManager
    @State private var selection: NavigationItem? = .dashboard
    @State private var activeSessionId: UUID?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @ObservedObject var historyService = HistoryService.shared
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            VStack(spacing: 0) {
                // Sidebar Header / Logo
                HStack {
                    Image(systemName: "hexagon.fill") // Placeholder Logo
                        .font(.system(size: 20))
                        .foregroundColor(DesignSystem.accent)
                    
                    Text("Rovena")
                        .font(DesignSystem.font(size: 16, weight: .bold))
                        .foregroundColor(DesignSystem.text)
                        .tracking(0.5)
                    
                    Spacer()
                }
                .padding()
                .padding(.top, 8)
                
                List(selection: $selection) {
                    ForEach(NavigationItem.allCases) { item in
                        NavigationLink(value: item) {
                            HStack {
                                Image(systemName: item.icon)
                                Text(item.rawValue)
                                    .font(DesignSystem.font(size: 13))
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
                .background(DesignSystem.background)
            }
            .background(DesignSystem.background)
            .navigationSplitViewColumnWidth(min: 200, ideal: 220)
        } detail: {
            ZStack {
                DesignSystem.background.ignoresSafeArea()
                
                switch selection {
                case .dashboard:
                    HomeView(selection: $selection, activeSessionId: $activeSessionId)
                case .chat:
                    ChatView(session: activeSession)
                case .history:
                    HistoryView(selection: $selection, activeSessionId: $activeSessionId)
                case .canvas:
                    CanvasView()
                case .todo:
                    ToDoView()
                case .settings:
                    SettingsView()
                case .profile:
                    ProfileView()
                case .none:
                    Text("Select Module")
                        .font(DesignSystem.font(size: 20))
                        .foregroundColor(.gray)
                }
            }
        }
    }
    
    private var activeSession: ChatSession? {
        guard let id = activeSessionId else { return nil }
        return historyService.sessions.first(where: { $0.id == id })
    }
}
