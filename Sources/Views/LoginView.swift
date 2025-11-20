import SwiftUI

struct LoginView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var isLoginMode = true
    @State private var email = ""
    @State private var password = ""
    
    // Cyber Aesthetic Animations
    @State private var appearAnimation = false
    
    var body: some View {
        ZStack {
            DesignSystem.background.ignoresSafeArea()
            
            // Background Matrix/Glitch effect hint
            VStack {
                HStack {
                    Text("SECURE_CONNECTION // ESTABLISHING...")
                        .font(DesignSystem.font(size: 10))
                        .foregroundColor(DesignSystem.text.opacity(0.3))
                    Spacer()
                    Text("V.2.0.1")
                        .font(DesignSystem.font(size: 10))
                        .foregroundColor(DesignSystem.text.opacity(0.3))
                }
                .padding()
                Spacer()
            }
            
            VStack(spacing: 30) {
                // Logo / Header
                VStack(spacing: 10) {
                    Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                        .resizable()
                        .frame(width: 80, height: 80)
                        .cornerRadius(16)
                        .shadow(color: DesignSystem.accent.opacity(0.5), radius: 10)
                    
                    Text("Rovena")
                        .font(DesignSystem.font(size: 40))
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.text)
                        .tracking(2)
                    
                    Text(isLoginMode ? "IDENTITY_VERIFICATION" : "NEW_USER_REGISTRATION")
                        .font(DesignSystem.font(size: 12))
                        .foregroundColor(DesignSystem.text.opacity(0.7))
                        .tracking(4)
                        .blinking()
                }
                .offset(y: appearAnimation ? 0 : -50)
                .opacity(appearAnimation ? 1 : 0)
                
                // Form
                VStack(spacing: 20) {
                    CyberTextField(icon: "person", placeholder: "USER_EMAIL", text: $email)
                    CyberTextField(icon: "key", placeholder: "ACCESS_CODE", text: $password, isSecure: true)
                    
                    if let error = authManager.errorMessage {
                        ScrollView {
                            Text(error)
                                .font(DesignSystem.font(size: 9))
                                .foregroundColor(.red)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: 350)
                                .padding(8)
                                .background(Color.red.opacity(0.1))
                                .border(Color.red.opacity(0.5), width: 1)
                        }
                        .frame(maxHeight: 150)
                    }
                    
                    Button(action: handleAction) {
                        HStack {
                            if authManager.isLoading {
                                ProgressView()
                                    .scaleEffect(0.5)
                                    .tint(DesignSystem.background)
                            }
                            Text(isLoginMode ? "AUTHENTICATE" : "INITIALIZE_USER")
                                .font(DesignSystem.font(size: 14))
                                .fontWeight(.bold)
                                .tracking(1)
                        }
                        .foregroundColor(DesignSystem.background)
                        .frame(width: 250, height: 50)
                        .background(DesignSystem.accent)
                        .overlay(
                            Rectangle()
                                .stroke(DesignSystem.text, lineWidth: 1)
                                .offset(x: 4, y: 4)
                                .opacity(0.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(authManager.isLoading)
                }
                .offset(y: appearAnimation ? 0 : 50)
                .opacity(appearAnimation ? 1 : 0)
                
                // Toggle Mode
                Button(action: {
                    withAnimation {
                        isLoginMode.toggle()
                        authManager.errorMessage = nil
                    }
                }) {
                    Text(isLoginMode ? "CREATE_NEW_UPLINK >>" : "<< RETURN_TO_LOGIN")
                        .font(DesignSystem.font(size: 12))
                        .foregroundColor(DesignSystem.accent)
                        .underline()
                }
                .buttonStyle(.plain)
                .padding(.top, 20)
                .opacity(appearAnimation ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                appearAnimation = true
            }
        }
    }
    
    func handleAction() {
        if isLoginMode {
            authManager.signIn(email: email, pass: password)
        } else {
            authManager.signUp(email: email, pass: password)
        }
    }
}

struct CyberTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    @State private var isFocused = false
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(isFocused ? DesignSystem.accent : DesignSystem.text.opacity(0.5))
                .frame(width: 20)
            
            if isSecure {
                SecureField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .font(DesignSystem.font(size: 14))
            } else {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .font(DesignSystem.font(size: 14))
            }
        }
        .foregroundColor(DesignSystem.text)
        .padding()
        .frame(width: 300)
        .background(DesignSystem.surface.opacity(0.05))
        .border(isFocused ? DesignSystem.accent : DesignSystem.border, width: 1)
        .onTapGesture { isFocused = true }
    }
}

