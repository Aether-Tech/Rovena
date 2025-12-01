import SwiftUI

enum NavigationItem: String, CaseIterable, Identifiable {
    case dashboard = "Home"
    case chat = "Chat"
    case history = "Archives"
    case canvas = "Canvas"
    case charts = "Charts"
    case presentations = "Presentations"
    case settings = "Settings"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .chat: return "message"
        case .history: return "clock"
        case .canvas: return "scribble"
        case .charts: return "chart.bar.fill"
        case .presentations: return "doc.text.fill"
        case .settings: return "gearshape"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var settings: SettingsManager
    @State private var selection: NavigationItem? = .dashboard
    @State private var activeSessionId: UUID?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @ObservedObject var historyService = HistoryService.shared
    @ObservedObject var tokenService = TokenService.shared
    @Environment(\.scenePhase) private var scenePhase
    
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
                            navigationItemView(item)
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
                case .charts:
                    ChartsView()
                case .presentations:
                    PresentationMainView()
                case .settings:
                    SettingsView()
                case .none:
                    Text("Select Module")
                        .font(DesignSystem.font(size: 20))
                        .foregroundColor(.gray)
                }
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            // Quando app volta ao foreground (usuário volta do Stripe), verificar assinatura
            if oldPhase != .active && newPhase == .active {
                if settings.useRovenaCloud {
                    tokenService.syncWithStripe(force: true)
                }
            }
        }
        .onAppear {
            // Verificar assinatura quando app abre
            if settings.useRovenaCloud {
                tokenService.syncWithStripe(force: false)
            }
        }
        .overlay(alignment: .top) {
            // Toast notification quando plano muda
            if let notification = tokenService.planChangedNotification {
                ToastView(message: notification.message)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        // Auto-dismiss após 4 segundos
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                            withAnimation {
                                tokenService.planChangedNotification = nil
                            }
                        }
                    }
            }
        }
    }
    
    private var activeSession: ChatSession? {
        guard let id = activeSessionId else { return nil }
        return historyService.sessions.first(where: { $0.id == id })
    }
    
    @ViewBuilder
    private func navigationItemView(_ item: NavigationItem) -> some View {
        HStack(spacing: 8) {
            Image(systemName: item.icon)
            
            // Para Presentations, mostrar "Presentations" + badge BETA
            if item == .presentations {
                Text("Presentations")
                    .font(DesignSystem.font(size: 13))
                
                Text("BETA")
                    .font(DesignSystem.font(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Text(item.rawValue)
                    .font(DesignSystem.font(size: 13))
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Toast View

struct ToastView: View {
    let message: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            
            Text(message)
                .font(DesignSystem.font(size: 13, weight: .medium))
                .foregroundColor(DesignSystem.text)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(DesignSystem.surface)
        .clipShape(SquircleShape())
        .overlay(
            SquircleShape()
                .stroke(DesignSystem.border.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        .padding(.top, 20)
        .padding(.horizontal, 20)
    }
}
