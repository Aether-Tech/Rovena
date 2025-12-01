import SwiftUI

struct HomeView: View {
    @Binding var selection: NavigationItem?
    @Binding var activeSessionId: UUID?
    
    @State private var inputText: String = ""
    @FocusState private var isInputFocused: Bool
    @ObservedObject var historyService = HistoryService.shared
    @ObservedObject var todoService = ToDoService.shared
    @ObservedObject var tokenService = TokenService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 40) {
            // Header Section
            VStack(alignment: .leading, spacing: 10) {
                Text(welcomeMessage)
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
                
                // Token counter - sempre mostra se useRovenaCloud estiver ativo
                if SettingsManager.shared.useRovenaCloud {
                    TokenStatCard()
                }
            }
            .padding(.horizontal)
            
            // Upgrade Button for FREE users
            if SettingsManager.shared.useRovenaCloud && tokenService.currentPlan == "FREE" {
                Button(action: {
                    let subscriptionURL = "https://buy.stripe.com/eVqeV6fIa4Ri0pQ5f2eZ203"
                    if let url = URL(string: subscriptionURL) {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 16))
                        Text("Upgrade to Rovena+")
                            .font(DesignSystem.font(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [DesignSystem.accent, DesignSystem.accent.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(SquircleShape())
                    .shadow(color: DesignSystem.accent.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            }
            
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
                            .onKeyPress { press in
                                guard press.key == .return else { return .ignored }
                                if press.modifiers.contains(.shift) {
                                    // Shift+Enter: allow default behavior (though TextField doesn't support line breaks)
                                    return .ignored
                                }
                                // Enter: start new session
                                startNewSession()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    isInputFocused = true
                                }
                                return .handled
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
            // Sincronizar tokens ao abrir home
            if SettingsManager.shared.useRovenaCloud {
                tokenService.syncWithStripe()
            }
        }
    }
    
    private var totalMessages: Int {
        historyService.sessions.reduce(0) { $0 + $1.messages.count }
    }
    
    private var archivedCount: Int {
        historyService.sessions.filter { $0.creationDate < Date().addingTimeInterval(-86400) }.count
    }
    
    private var welcomeMessage: String {
        if let userName = AuthManager.shared.userName, !userName.isEmpty {
            return "Bem vindo de volta, \(userName)"
        }
        return "Welcome back"
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
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(DesignSystem.font(size: 12))
                .foregroundColor(DesignSystem.text.opacity(0.6))
                .lineLimit(1)
            
            Text(value)
                .font(DesignSystem.font(size: 24, weight: .bold))
                .foregroundColor(DesignSystem.text)
                .lineLimit(1)
            
            Spacer(minLength: 0)
        }
        .padding()
        .frame(minWidth: 160, maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
        .elementStyle()
    }
}

struct TokenStatCard: View {
    @ObservedObject var tokenService = TokenService.shared
    
    private var usageColor: Color {
        guard tokenService.monthlyLimit > 0 else { return DesignSystem.accent }
        let usage = tokenService.usagePercentage()
        if usage >= 0.9 {
            return .red
        } else if usage >= 0.7 {
            return .orange
        } else {
            return DesignSystem.accent
        }
    }
    
    private var remainingPercentage: Double {
        guard tokenService.monthlyLimit > 0 else { return 100.0 }
        return tokenService.remainingPercentage() * 100
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Tokens")
                    .font(DesignSystem.font(size: 12))
                    .foregroundColor(DesignSystem.text.opacity(0.6))
                    .lineLimit(1)
                
                Spacer()
                
                Text(tokenService.currentPlan)
                    .font(DesignSystem.font(size: 10, weight: .medium))
                    .foregroundColor(planColor(tokenService.currentPlan))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(planColor(tokenService.currentPlan).opacity(0.15))
                    .clipShape(SquircleShape())
                    .lineLimit(1)
            }
            
            if tokenService.monthlyLimit > 0 {
                VStack(alignment: .leading, spacing: 6) {
                    // Porcentagem restante grande
                    Text("\(String(format: "%.0f", remainingPercentage))%")
                        .font(DesignSystem.font(size: 24, weight: .bold))
                        .foregroundColor(usageColor)
                        .lineLimit(1)
                    
                    Text("remaining")
                        .font(DesignSystem.font(size: 11))
                        .foregroundColor(DesignSystem.text.opacity(0.6))
                        .lineLimit(1)
                    
                    // Barra de progresso (mostra restante)
                    TokenProgressBar(
                        remaining: remainingPercentage,
                        color: usageColor
                    )
                    .frame(height: 8)
                    
                    // Info adicional
                    HStack(spacing: 4) {
                        Text("\(formatTokenCount(tokenService.remainingTokens())) left")
                            .font(DesignSystem.font(size: 10))
                            .foregroundColor(DesignSystem.text.opacity(0.5))
                            .lineLimit(1)
                        
                        Text("•")
                            .font(DesignSystem.font(size: 10))
                            .foregroundColor(DesignSystem.text.opacity(0.3))
                        
                        Text("\(formatTokenCount(tokenService.tokensUsedLast30Days))/\(formatTokenCount(tokenService.monthlyLimit)) used")
                            .font(DesignSystem.font(size: 10))
                            .foregroundColor(DesignSystem.text.opacity(0.5))
                            .lineLimit(1)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("∞")
                        .font(DesignSystem.font(size: 24, weight: .bold))
                        .foregroundColor(DesignSystem.accent)
                        .lineLimit(1)
                    
                    Text("Unlimited")
                        .font(DesignSystem.font(size: 11))
                        .foregroundColor(DesignSystem.text.opacity(0.6))
                        .lineLimit(1)
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding()
        .frame(minWidth: 200, maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .elementStyle()
    }
    
    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000.0)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000.0)
        } else {
            return "\(count)"
        }
    }
    
    private func planColor(_ plan: String) -> Color {
        switch plan.uppercased() {
        case "FREE": return .gray
        case "BASIC": return .blue
        case "PRO": return DesignSystem.accent
        case "ENTERPRISE": return .purple
        default: return DesignSystem.accent
        }
    }
}

// Componente reutilizável de barra de progresso de tokens
struct TokenProgressBar: View {
    let remaining: Double // Porcentagem restante (0-100)
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Fundo
                Rectangle()
                    .fill(DesignSystem.text.opacity(0.1))
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipShape(SquircleShape())
                
                // Barra de progresso (mostra restante)
                Rectangle()
                    .fill(color)
                    .frame(
                        width: max(0, min(geometry.size.width, geometry.size.width * CGFloat(remaining / 100.0))),
                        height: geometry.size.height
                    )
                    .clipShape(SquircleShape())
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: remaining)
            }
        }
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
                    .clipShape(SquircleShape())
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
