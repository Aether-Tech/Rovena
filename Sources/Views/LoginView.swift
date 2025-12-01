import SwiftUI

struct LoginView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var isLoginMode = true
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var acceptedTerms = false
    @State private var showTerms = false
    
    var body: some View {
        ZStack {
            DesignSystem.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 40) {
                    // Logo / Header
                    VStack(spacing: 16) {
                        Image(systemName: "hexagon.fill")
                            .font(.system(size: 80))
                            .foregroundColor(DesignSystem.accent)
                            .shadow(color: DesignSystem.accent.opacity(0.3), radius: 20, x: 0, y: 10)
                        
                        Text("Rovena")
                            .font(DesignSystem.font(size: 36, weight: .bold))
                            .foregroundColor(DesignSystem.text)
                        
                        Text(isLoginMode ? "Welcome back" : "Create your account")
                            .font(DesignSystem.font(size: 16))
                            .foregroundColor(DesignSystem.text.opacity(0.6))
                    }
                    
                    // Form Card
                    VStack(spacing: 20) {
                        // Name field (only in signup mode)
                        if !isLoginMode {
                            ModernTextField(icon: "person", placeholder: "Name", text: $name)
                        }
                        
                        ModernTextField(icon: "envelope", placeholder: "Email", text: $email)
                        ModernTextField(icon: "lock", placeholder: "Password", text: $password, isSecure: true)
                        
                        // Terms and Conditions Checkbox (only show in signup mode)
                        if !isLoginMode {
                            HStack(spacing: 10) {
                                Button(action: {
                                    acceptedTerms.toggle()
                                }) {
                                    Image(systemName: acceptedTerms ? "checkmark.square.fill" : "square")
                                        .foregroundColor(acceptedTerms ? DesignSystem.accent : DesignSystem.text.opacity(0.4))
                                        .font(.system(size: 16))
                                }
                                .buttonStyle(.plain)
                                
                                HStack(spacing: 4) {
                                    Text("I agree to the")
                                        .font(DesignSystem.font(size: 12))
                                        .foregroundColor(DesignSystem.text.opacity(0.7))
                                    
                                    Button(action: {
                                        showTerms = true
                                    }) {
                                        Text("Terms and Conditions")
                                            .font(DesignSystem.font(size: 12, weight: .medium))
                                            .foregroundColor(DesignSystem.accent)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .frame(maxWidth: 400, alignment: .leading)
                            .padding(.vertical, 4)
                        }
                        
                        if let error = authManager.errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.red)
                                Text(error)
                                    .font(DesignSystem.font(size: 12))
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.leading)
                            }
                            .frame(maxWidth: 400, alignment: .leading)
                            .padding(12)
                            .background(Color.red.opacity(0.1))
                            .clipShape(SquircleShape())
                            .overlay(
                                SquircleShape()
                                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                            )
                        }
                        
                        Button(action: handleAction) {
                            HStack(spacing: 8) {
                                if authManager.isLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(.white)
                                }
                                Text(isLoginMode ? "Sign In" : "Create Account")
                                    .font(DesignSystem.font(size: 15, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: 400)
                            .frame(height: 50)
                            .background(canProceed ? DesignSystem.accent : DesignSystem.accent.opacity(0.5))
                            .clipShape(SquircleShape())
                        }
                        .buttonStyle(.plain)
                        .disabled(authManager.isLoading || !canProceed)
                        
                        // Toggle Mode
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isLoginMode.toggle()
                                authManager.errorMessage = nil
                                acceptedTerms = false
                                name = "" // Reset name when switching modes
                            }
                        }) {
                            Text(isLoginMode ? "Don't have an account? Sign up" : "Already have an account? Sign in")
                                .font(DesignSystem.font(size: 13))
                                .foregroundColor(DesignSystem.accent)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                    }
                    .padding(32)
                    .frame(maxWidth: 450)
                    .elementStyle()
                }
                .padding(40)
                
                Spacer()
            }
        }
        .sheet(isPresented: $showTerms) {
            TermsAndConditionsView()
        }
    }
    
    private var canProceed: Bool {
        if isLoginMode {
            return !email.isEmpty && !password.isEmpty
        } else {
            return !name.isEmpty && !email.isEmpty && !password.isEmpty && acceptedTerms
        }
    }
    
    func handleAction() {
        if isLoginMode {
            authManager.signIn(email: email, pass: password)
        } else {
            guard !name.isEmpty else {
                authManager.errorMessage = "Name is required"
                return
            }
            guard acceptedTerms else {
                authManager.errorMessage = "You must accept the Terms and Conditions to create an account"
                return
            }
            authManager.signUp(email: email, pass: password, name: name)
        }
    }
}

struct ModernTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(isFocused ? DesignSystem.accent : DesignSystem.text.opacity(0.4))
                .frame(width: 20)
                .font(.system(size: 14))
            
            if isSecure {
                SecureField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .font(DesignSystem.font(size: 14))
                    .focused($isFocused)
            } else {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .font(DesignSystem.font(size: 14))
                    .focused($isFocused)
            }
        }
        .foregroundColor(DesignSystem.text)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(DesignSystem.surface.opacity(0.5))
        .clipShape(SquircleShape())
        .overlay(
            SquircleShape()
                .stroke(isFocused ? DesignSystem.accent : DesignSystem.border, lineWidth: isFocused ? 2 : 1)
        )
    }
}

