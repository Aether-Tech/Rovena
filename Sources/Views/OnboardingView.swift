import SwiftUI

struct OnboardingView: View {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var tokenService = TokenService.shared
    @State private var currentPage = 0
    @State private var appearAnimation = false
    @AppStorage("onboarding_completed") private var onboardingCompleted = false
    @Environment(\.scenePhase) private var scenePhase
    
    let subscriptionURL = "https://buy.stripe.com/eVqeV6fIa4Ri0pQ5f2eZ203"
    
    var body: some View {
        ZStack {
            DesignSystem.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Content
                ZStack {
                    // Page 1: Welcome
                    if currentPage == 0 {
                        OnboardingPage(
                            icon: "sparkles",
                            title: "Welcome to Rovena",
                            description: "Your intelligent platform for creating presentations, charts, and visualizations with the power of AI.",
                            color: DesignSystem.accent
                        )
                        .transition(.opacity.combined(with: .scale))
                    }
                    
                    // Page 2: Features
                    if currentPage == 1 {
                        OnboardingPage(
                            icon: "message.bubble",
                            title: "Intelligent Chat",
                            description: "Chat with AI to generate content, create presentations, and get instant insights about your data.",
                            color: DesignSystem.accent
                        )
                        .transition(.opacity.combined(with: .scale))
                    }
                    
                    // Page 3: Canvas
                    if currentPage == 2 {
                        OnboardingPage(
                            icon: "scribble",
                            title: "Interactive Canvas",
                            description: "Create and edit elements visually on an intuitive canvas. Drag, resize, and customize everything.",
                            color: DesignSystem.accent
                        )
                        .transition(.opacity.combined(with: .scale))
                    }
                    
                    // Page 4: Charts & Presentations
                    if currentPage == 3 {
                        OnboardingPage(
                            icon: "chart.pie",
                            title: "Charts & Presentations",
                            description: "Generate professional charts and complete presentations automatically from your data.",
                            color: DesignSystem.accent
                        )
                        .transition(.opacity.combined(with: .scale))
                    }
                    
                    // Page 5: Subscription
                    if currentPage == 4 {
                        SubscriptionPage(
                            subscriptionURL: subscriptionURL,
                            onSkip: completeOnboarding
                        )
                        .transition(.opacity.combined(with: .scale))
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: currentPage)
                
                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<5) { index in
                        Circle()
                            .fill(index == currentPage ? DesignSystem.accent : DesignSystem.text.opacity(0.2))
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut, value: currentPage)
                    }
                }
                .padding(.top, 40)
                
                // Navigation buttons
                HStack(spacing: 16) {
                    if currentPage > 0 {
                        Button(action: {
                            withAnimation {
                                currentPage -= 1
                            }
                        }) {
                            Text("Previous")
                                .font(DesignSystem.font(size: 14, weight: .medium))
                                .foregroundColor(DesignSystem.text)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(DesignSystem.surface.opacity(0.5))
                                .clipShape(SquircleShape())
                                .overlay(
                                    SquircleShape()
                                        .stroke(DesignSystem.border, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Spacer()
                    
                    if currentPage < 4 {
                        Button(action: {
                            withAnimation {
                                currentPage += 1
                            }
                        }) {
                            Text("Next")
                                .font(DesignSystem.font(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(DesignSystem.accent)
                                .clipShape(SquircleShape())
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button(action: completeOnboarding) {
                            Text("Get Started")
                                .font(DesignSystem.font(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(DesignSystem.accent)
                                .clipShape(SquircleShape())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
                
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                appearAnimation = true
            }
            // Verificar assinatura quando onboarding aparece
            if SettingsManager.shared.useRovenaCloud {
                tokenService.syncWithStripe(force: true)
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            // Quando usuário volta do Stripe checkout, verificar assinatura
            if oldPhase != .active && newPhase == .active {
                if SettingsManager.shared.useRovenaCloud {
                    tokenService.syncWithStripe(force: true)
                }
            }
        }
    }
    
    func completeOnboarding() {
        onboardingCompleted = true
        // Verificar assinatura uma última vez antes de completar onboarding
        if SettingsManager.shared.useRovenaCloud {
            tokenService.syncWithStripe(force: true)
        }
        // The app will automatically update to show ContentView
    }
}

struct OnboardingPage: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 32) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 72))
                .foregroundColor(color)
                .symbolEffect(.pulse, options: .repeating)
                .padding(.bottom, 20)
            
            // Title
            Text(title)
                .font(DesignSystem.font(size: 32, weight: .bold))
                .foregroundColor(DesignSystem.text)
                .multilineTextAlignment(.center)
            
            // Description
            Text(description)
                .font(DesignSystem.font(size: 16))
                .foregroundColor(DesignSystem.text.opacity(0.7))
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .padding(.horizontal, 60)
                .frame(maxWidth: 600)
        }
        .padding(40)
    }
}

struct SubscriptionPage: View {
    let subscriptionURL: String
    let onSkip: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            // Icon
            Image(systemName: "star.fill")
                .font(.system(size: 72))
                .foregroundColor(DesignSystem.accent)
                .symbolEffect(.pulse, options: .repeating)
                .padding(.bottom, 20)
            
            // Title
            Text("Subscribe Now")
                .font(DesignSystem.font(size: 32, weight: .bold))
                .foregroundColor(DesignSystem.text)
            
            // Description
            Text("Unlock the full potential of Rovena with a subscription. Access premium features, more tokens, and priority support.")
                .font(DesignSystem.font(size: 16))
                .foregroundColor(DesignSystem.text.opacity(0.7))
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .padding(.horizontal, 60)
                .frame(maxWidth: 600)
            
            // Subscription Button
            Button(action: {
                if let url = URL(string: subscriptionURL) {
                    NSWorkspace.shared.open(url)
                }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "creditcard.fill")
                    Text("Subscribe Now")
                        .font(DesignSystem.font(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(DesignSystem.accent)
                .clipShape(SquircleShape())
            }
            .buttonStyle(.plain)
            .padding(.top, 10)
            
            // Skip option
            Button(action: onSkip) {
                Text("Skip for now")
                    .font(DesignSystem.font(size: 13))
                    .foregroundColor(DesignSystem.text.opacity(0.6))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .padding(40)
    }
}

