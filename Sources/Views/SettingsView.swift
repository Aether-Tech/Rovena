import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject var authManager = AuthManager.shared
    @ObservedObject private var tokenService = TokenService.shared
    @ObservedObject private var updateService = UpdateService.shared
    @State private var showLogoutAlert = false
    @State private var showCancelSubscriptionAlert = false
    @State private var cancelSubscriptionError: String?
    @State private var showLogsView = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Configuration")
                .font(DesignSystem.font(size: 24, weight: .bold))
                .foregroundColor(DesignSystem.text)
            
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Profile")
                                .font(DesignSystem.font(size: 14, weight: .medium))
                                .foregroundColor(DesignSystem.text.opacity(0.7))
                                .padding(.leading, 4)
                            
                            Spacer()
                            
                            // Logout Button (Small & Right Aligned)
                            Button(action: { showLogoutAlert = true }) {
                                HStack(spacing: 6) {
                                    Text("Sign Out")
                                        .font(DesignSystem.font(size: 12))
                                    Image(systemName: "power")
                                        .font(.system(size: 12))
                                }
                                .foregroundColor(.red)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.red.opacity(0.1))
                                .clipShape(SquircleShape())
                                .overlay(SquircleShape().stroke(Color.red.opacity(0.3), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .confirmationDialog("Are you sure you want to logout?", isPresented: $showLogoutAlert) {
                                Button("Sign Out", role: .destructive) {
                                    authManager.signOut()
                                }
                                Button("Cancel", role: .cancel) { }
                            } message: {
                                Text("This will end your current session.")
                            }
                        }
                        
                        HStack(spacing: 16) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(DesignSystem.accent)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(authManager.user?.email.uppercased() ?? "UNKNOWN_USER")
                                    .font(DesignSystem.font(size: 16))
                                    .foregroundColor(DesignSystem.text)
                                
                                HStack(spacing: 8) {
                                    Text("ID: \(authManager.user?.uid ?? "N/A")")
                                        .font(DesignSystem.font(size: 10))
                                        .foregroundColor(DesignSystem.text.opacity(0.5))
                                    
                                    // Plan Badge (only if using Rovena Cloud)
                                    if settings.useRovenaCloud {
                                        Text(tokenService.currentPlan)
                                            .font(DesignSystem.font(size: 9, weight: .semibold))
                                            .foregroundColor(planColor(tokenService.currentPlan))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(planColor(tokenService.currentPlan).opacity(0.15))
                                            .clipShape(SquircleShape())
                                    }
                                }
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .elementStyle()
                    }
                    
                    // Appearance Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Appearance")
                            .font(DesignSystem.font(size: 14, weight: .medium))
                            .foregroundColor(DesignSystem.text.opacity(0.7))
                            .padding(.leading, 4)
                        
                        VStack(spacing: 0) {
                            // Dark Mode Toggle
                            Toggle("Dark Mode", isOn: $settings.isDarkMode)
                                .toggleStyle(.switch)
                                .font(DesignSystem.font(size: 14))
                                .foregroundColor(DesignSystem.text)
                                .padding()
                            
                            Divider().opacity(0.5)
                            
                            // Theme Selector
                            HStack {
                                Text("Theme")
                                    .font(DesignSystem.font(size: 14))
                                    .foregroundColor(DesignSystem.text)
                                
                                Spacer()
                                
                                Picker("", selection: $settings.selectedTheme) {
                                    ForEach(AppTheme.allCases) { theme in
                                        Text(theme.rawValue).tag(theme)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 200)
                            }
                            .padding()
                            
                            Divider().opacity(0.5)
                            
                            // Language Selector
                            HStack {
                                Text("Language")
                                    .font(DesignSystem.font(size: 14))
                                    .foregroundColor(DesignSystem.text)
                                
                                Spacer()
                                
                                Picker("", selection: $settings.selectedLanguage) {
                                    ForEach(AppLanguage.allCases) { language in
                                        Text(language.displayName).tag(language)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 200)
                            }
                            .padding()
                        }
                        .elementStyle()
                    }
                    
                    // Subscription Management Section (only show if using Rovena Cloud)
                    if settings.useRovenaCloud && tokenService.currentPlan != "FREE" {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Subscription Management")
                                .font(DesignSystem.font(size: 14, weight: .medium))
                                .foregroundColor(DesignSystem.text.opacity(0.7))
                                .padding(.leading, 4)
                            
                            VStack(spacing: 16) {
                                // Current Plan Info
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Current Plan")
                                            .font(DesignSystem.font(size: 13))
                                            .foregroundColor(DesignSystem.text)
                                        
                                        Spacer()
                                        
                                        Text(tokenService.currentPlan)
                                            .font(DesignSystem.font(size: 13, weight: .semibold))
                                            .foregroundColor(DesignSystem.accent)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(DesignSystem.accent.opacity(0.1))
                                            .clipShape(SquircleShape())
                                    }
                                    
                                    if let status = tokenService.subscriptionStatus {
                                        HStack {
                                            Text("Status")
                                                .font(DesignSystem.font(size: 12))
                                                .foregroundColor(DesignSystem.text.opacity(0.7))
                                            
                                            Spacer()
                                            
                                            Text(status.capitalized)
                                                .font(DesignSystem.font(size: 12, weight: .medium))
                                                .foregroundColor(statusColor(status))
                                        }
                                    }
                                }
                                
                                Divider().opacity(0.5)
                                
                                // Cancel Subscription Button
                                Button(action: {
                                    showCancelSubscriptionAlert = true
                                }) {
                                    HStack {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 14))
                                        Text("Cancel Subscription")
                                            .font(DesignSystem.font(size: 13, weight: .medium))
                                    }
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.red.opacity(0.1))
                                    .clipShape(SquircleShape())
                                    .overlay(
                                        SquircleShape()
                                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                .disabled(tokenService.isCancelingSubscription)
                            }
                            .padding()
                            .elementStyle()
                        }
                    }
                    
                    // Token Usage Section (only show if using Rovena Cloud)
                    if settings.useRovenaCloud {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Token Usage")
                                    .font(DesignSystem.font(size: 14, weight: .medium))
                                    .foregroundColor(DesignSystem.text.opacity(0.7))
                                
                                Spacer()
                                
                                // Plan Badge
                                Text(tokenService.currentPlan)
                                    .font(DesignSystem.font(size: 11, weight: .semibold))
                                    .foregroundColor(planColor(tokenService.currentPlan))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(planColor(tokenService.currentPlan).opacity(0.15))
                                    .clipShape(SquircleShape())
                            }
                            .padding(.leading, 4)
                            
                            VStack(spacing: 16) {
                                // Progress Bar
                                VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Last 30 Days")
                                            .font(DesignSystem.font(size: 13))
                                            .foregroundColor(DesignSystem.text)
                                        
                                        if tokenService.monthlyLimit > 0 {
                                            let percentage = tokenService.usagePercentage() * 100
                                            Text("\(String(format: "%.1f", percentage))% used")
                                                .font(DesignSystem.font(size: 11))
                                                .foregroundColor(DesignSystem.text.opacity(0.6))
                                        } else {
                                            Text("Unlimited")
                                                .font(DesignSystem.font(size: 11))
                                                .foregroundColor(DesignSystem.text.opacity(0.6))
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if tokenService.monthlyLimit > 0 {
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text("\(tokenService.tokensUsedLast30Days) / \(tokenService.monthlyLimit)")
                                                .font(DesignSystem.font(size: 13, weight: .medium))
                                                .foregroundColor(DesignSystem.text)
                                            
                                            let remaining = tokenService.remainingPercentage() * 100
                                            Text("\(String(format: "%.1f", remaining))% remaining")
                                                .font(DesignSystem.font(size: 10))
                                                .foregroundColor(DesignSystem.text.opacity(0.5))
                                        }
                                    } else {
                                        Text("\(tokenService.tokensUsedLast30Days) tokens")
                                            .font(DesignSystem.font(size: 13, weight: .medium))
                                            .foregroundColor(DesignSystem.text)
                                    }
                                }
                                    
                                    if tokenService.monthlyLimit > 0 {
                                        // Barra de progresso mostrando tokens restantes
                                        VStack(alignment: .leading, spacing: 6) {
                                            // Porcentagem restante grande
                                            HStack {
                                                Text("\(String(format: "%.0f", tokenService.remainingPercentage() * 100))%")
                                                    .font(DesignSystem.font(size: 24, weight: .bold))
                                                    .foregroundColor(usageColor)
                                                
                                                Text("remaining")
                                                    .font(DesignSystem.font(size: 12))
                                                    .foregroundColor(DesignSystem.text.opacity(0.6))
                                                
                                                Spacer()
                                            }
                                            
                                            // Barra de progresso visual
                                            TokenProgressBar(
                                                remaining: tokenService.remainingPercentage() * 100,
                                                color: usageColor
                                            )
                                            .frame(height: 16)
                                        }
                                        
                                        HStack {
                                            Text("Remaining: \(tokenService.remainingTokens()) tokens")
                                                .font(DesignSystem.font(size: 11))
                                                .foregroundColor(DesignSystem.text.opacity(0.6))
                                            
                                            Spacer()
                                            
                                            Button {
                                                tokenService.syncWithStripe(force: true)
                                            } label: {
                                                HStack(spacing: 4) {
                                                    Image(systemName: "arrow.clockwise")
                                                        .font(.system(size: 10))
                                                    Text("Sync")
                                                        .font(DesignSystem.font(size: 11))
                                                }
                                                .foregroundColor(DesignSystem.accent)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    } else {
                                        Text("Syncing limit from server...")
                                            .font(DesignSystem.font(size: 11))
                                            .foregroundColor(DesignSystem.text.opacity(0.6))
                                    }
                                }
                            }
                            .padding()
                            .elementStyle()
                            
                            // Upgrade Button for FREE users
                            if tokenService.currentPlan == "FREE" {
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
                                .padding(.top, 8)
                            }
                        }
                    }
                    
                    // Developer / Debug Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Developer")
                            .font(DesignSystem.font(size: 14, weight: .medium))
                            .foregroundColor(DesignSystem.text.opacity(0.7))
                            .padding(.leading, 4)
                        
                        Button(action: {
                            showLogsView = true
                        }) {
                            HStack {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 14))
                                    .foregroundColor(DesignSystem.accent)
                                
                                Text("View Logs")
                                    .font(DesignSystem.font(size: 13))
                                    .foregroundColor(DesignSystem.text)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10))
                                    .foregroundColor(DesignSystem.text.opacity(0.3))
                            }
                            .padding()
                            .background(DesignSystem.surface.opacity(0.5))
                            .clipShape(SquircleShape())
                        }
                        .buttonStyle(.plain)
                    }
                    .sheet(isPresented: $showLogsView) {
                        LogsView()
                    }
                    
                    // AI Configuration Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Text("AI Configuration")
                                .font(DesignSystem.font(size: 14, weight: .medium))
                                .foregroundColor(DesignSystem.text.opacity(0.7))
                            
                            Spacer()
                            
                            Menu {
                                Text("O que é uma API Key?")
                                    .font(DesignSystem.font(size: 12, weight: .bold))
                                Text("Imagine que a API Key é como uma 'chave mágica' que permite o Rovena conversar com modelos externos (OpenAI, Anthropic, Gemini).")
                                    .font(DesignSystem.font(size: 11))
                                Text("Sem essa chave eles não sabem quem somos e bloqueiam o acesso.")
                                    .font(DesignSystem.font(size: 11))
                                
                                Divider()
                                
                                Link("Obter chave OpenAI", destination: URL(string: "https://platform.openai.com/api-keys")!)
                                Link("Obter chave Anthropic", destination: URL(string: "https://console.anthropic.com/")!)
                                Link("Obter chave Gemini", destination: URL(string: "https://makersuite.google.com/app/apikey")!)
                            } label: {
                                Image(systemName: "questionmark.circle")
                                    .foregroundColor(DesignSystem.accent)
                            }
                            .menuStyle(.borderlessButton)
                        }
                        .padding(.leading, 4)
                        
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(alignment: .top, spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Use Rovena Cloud (recommended)")
                                        .font(DesignSystem.font(size: 13, weight: .medium))
                                        .foregroundColor(DesignSystem.text)
                                        .lineLimit(2)
                                    Text("Usa a chave de API padrão do Rovena. Desligue para usar suas próprias chaves.")
                                        .font(DesignSystem.font(size: 11))
                                        .foregroundColor(DesignSystem.text.opacity(0.6))
                                        .lineLimit(3)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Toggle("", isOn: $settings.useRovenaCloud)
                                    .toggleStyle(.switch)
                                    .labelsHidden()
                                    .padding(.top, 2) // Alinha com o texto
                            }
                            
                            if !settings.useRovenaCloud {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Advanced: Bring your own API keys")
                                        .font(DesignSystem.font(size: 12, weight: .medium))
                                        .foregroundColor(DesignSystem.text.opacity(0.7))
                                    
                                    KeyField(title: "OpenAI API Key", value: $settings.openAIKey)
                                    KeyField(title: "Anthropic API Key", value: $settings.anthropicKey)
                                    KeyField(title: "Gemini API Key", value: $settings.geminiKey)
                                    KeyField(title: "Custom Endpoint", value: $settings.customEndpoint)
                                    
                                    if settings.customEndpoint.isEmpty {
                                        Text("💡 Configure o endpoint do backend (ex: http://localhost:8787/api/chat)")
                                            .font(DesignSystem.font(size: 10))
                                            .foregroundColor(DesignSystem.text.opacity(0.6))
                                            .padding(.top, -8)
                                    }
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            } else {
                                // Mostrar Custom Endpoint mesmo quando usa Rovena Cloud (para debug)
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Backend Configuration")
                                        .font(DesignSystem.font(size: 12, weight: .medium))
                                        .foregroundColor(DesignSystem.text.opacity(0.7))
                                    
                                    KeyField(title: "Custom Endpoint (override)", value: $settings.customEndpoint)
                                    
                                    if settings.customEndpoint.isEmpty {
                                        Text("Usando endpoint padrão: https://api.rovena.app")
                                            .font(DesignSystem.font(size: 10))
                                            .foregroundColor(DesignSystem.text.opacity(0.6))
                                    } else {
                                        Text("⚠️ Usando endpoint customizado: \(settings.customEndpoint)")
                                            .font(DesignSystem.font(size: 10))
                                            .foregroundColor(.orange)
                                    }
                                }
                                .padding(.top, 8)
                            }
                        }
                        .padding(EdgeInsets(top: 18, leading: 20, bottom: 18, trailing: 20))
                        .elementStyle()
                    }
                    
                    // Updates Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Updates")
                            .font(DesignSystem.font(size: 14, weight: .medium))
                            .foregroundColor(DesignSystem.text.opacity(0.7))
                            .padding(.leading, 4)
                        
                        VStack(spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Current Version")
                                        .font(DesignSystem.font(size: 12))
                                        .foregroundColor(DesignSystem.text.opacity(0.7))
                                    Text(updateService.fullVersion)
                                        .font(DesignSystem.font(size: 14, weight: .medium))
                                        .foregroundColor(DesignSystem.text)
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    updateService.checkForUpdates()
                                }) {
                                    HStack(spacing: 6) {
                                        if updateService.isCheckingForUpdates {
                                            ProgressView()
                                                .scaleEffect(0.7)
                                                .tint(DesignSystem.background)
                                        } else {
                                            Image(systemName: "arrow.clockwise")
                                        }
                                        Text("Check for Updates")
                                            .font(DesignSystem.font(size: 12, weight: .medium))
                                    }
                                    .foregroundColor(DesignSystem.background)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(DesignSystem.accent)
                                    .clipShape(SquircleShape())
                                }
                                .buttonStyle(.plain)
                                .disabled(updateService.isCheckingForUpdates)
                            }
                            
                            if let status = updateService.updateStatus {
                                Text(status)
                                    .font(DesignSystem.font(size: 11))
                                    .foregroundColor(DesignSystem.text.opacity(0.6))
                            }
                        }
                        .padding(EdgeInsets(top: 18, leading: 20, bottom: 18, trailing: 20))
                        .elementStyle()
                    }
                }
                .padding()
            }
            
            Spacer()
        }
        .padding()
        .background(DesignSystem.background)
        .onAppear {
            // Sincronizar tokens ao abrir settings (força sincronização para buscar assinatura atualizada)
            if settings.useRovenaCloud {
                tokenService.syncWithStripe(force: true)
            }
        }
        .alert("Cancel Subscription", isPresented: $showCancelSubscriptionAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Confirm", role: .destructive) {
                cancelSubscription()
            }
        } message: {
            Text("Are you sure you want to cancel your subscription? Your plan will be downgraded to FREE at the end of the current billing period.")
        }
        .alert("Error", isPresented: Binding(
            get: { cancelSubscriptionError != nil },
            set: { if !$0 { cancelSubscriptionError = nil } }
        )) {
            Button("OK") {
                cancelSubscriptionError = nil
            }
        } message: {
            if let error = cancelSubscriptionError {
                Text(error)
            }
        }
    }
    
    private func cancelSubscription() {
        tokenService.cancelSubscription { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // Success - sync will update the plan automatically
                    break
                case .failure(let error):
                    cancelSubscriptionError = error.localizedDescription
                }
            }
        }
    }
    
    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "active":
            return .green
        case "canceled":
            return .red
        case "past_due":
            return .orange
        case "trialing":
            return .blue
        default:
            return DesignSystem.text.opacity(0.7)
        }
    }
    
    private func planColor(_ plan: String) -> Color {
        switch plan.uppercased() {
        case "FREE":
            return .gray
        case "BASIC":
            return .blue
        case "PRO":
            return DesignSystem.accent
        case "ENTERPRISE":
            return .purple
        default:
            return DesignSystem.accent
        }
    }
    
    private var usageColor: Color {
        let usage = tokenService.monthlyLimit > 0 
            ? Double(tokenService.tokensUsedLast30Days) / Double(tokenService.monthlyLimit)
            : 0.0
        
        if usage >= 0.9 {
            return .red
        } else if usage >= 0.7 {
            return .orange
        } else {
            return DesignSystem.accent
        }
    }
    
    private func progressWidth(in totalWidth: CGFloat) -> CGFloat {
        guard tokenService.monthlyLimit > 0 else { return 0 }
        let progress = min(1.0, Double(tokenService.tokensUsedLast30Days) / Double(tokenService.monthlyLimit))
        return totalWidth * CGFloat(progress)
    }
}

struct KeyField: View {
    let title: String
    @Binding var value: String
    @State private var isVisible = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(DesignSystem.font(size: 13))
                .foregroundColor(DesignSystem.text)
            
            HStack {
                if isVisible {
                    TextField("Enter Key", text: $value)
                        .textFieldStyle(.plain)
                        .font(DesignSystem.font(size: 14))
                        .foregroundColor(DesignSystem.text)
                        .onSubmit {
                            SettingsManager.shared.saveKeys()
                        }
                        .onChange(of: value) {
                            SettingsManager.shared.saveKeys()
                        }
                } else {
                    SecureField("Enter Key", text: $value)
                        .textFieldStyle(.plain)
                        .font(DesignSystem.font(size: 14))
                        .foregroundColor(DesignSystem.text)
                        .onSubmit {
                            SettingsManager.shared.saveKeys()
                        }
                        .onChange(of: value) {
                            SettingsManager.shared.saveKeys()
                        }
                }
                
                Button {
                    isVisible.toggle()
                } label: {
                    Image(systemName: isVisible ? "eye.slash" : "eye")
                        .foregroundColor(DesignSystem.text.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .elementStyle()
        }
    }
}
