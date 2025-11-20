import SwiftUI

struct ProfileView: View {
    @ObservedObject var authManager = AuthManager.shared
    @State private var showLogoutAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("USER_PROFILE // IDENTITY")
                .font(DesignSystem.font(size: 20))
                .foregroundColor(DesignSystem.accent)
                .tracking(1.5)
            
            ScrollView {
                VStack(spacing: 24) {
                    // User Info Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("CREDENTIALS")
                            .font(DesignSystem.font(size: 14))
                            .foregroundColor(DesignSystem.text.opacity(0.7))
                        
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(DesignSystem.accent)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(authManager.user?.email.uppercased() ?? "UNKNOWN_USER")
                                    .font(DesignSystem.font(size: 16))
                                    .foregroundColor(DesignSystem.text)
                                
                                Text("ID: \(authManager.user?.uid ?? "N/A")")
                                    .font(DesignSystem.font(size: 10))
                                    .foregroundColor(DesignSystem.text.opacity(0.5))
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(DesignSystem.surface.opacity(0.05))
                        .overlay(
                            Rectangle()
                                .stroke(DesignSystem.border, lineWidth: 1)
                        )
                    }
                    
                    // Future Stats or Info could go here
                    VStack(alignment: .leading, spacing: 10) {
                        Text("STATISTICS")
                            .font(DesignSystem.font(size: 14))
                            .foregroundColor(DesignSystem.text.opacity(0.7))
                        
                        HStack(spacing: 10) {
                            StatCard(title: "SESSION_TIME", value: "00:00:00")
                            StatCard(title: "COMMANDS", value: "0")
                        }
                    }
                    
                    Spacer()
                        .frame(height: 40)
                    
                    // Logout Action
                    Button(action: { showLogoutAlert = true }) {
                        HStack {
                            Image(systemName: "power")
                            Text("Sign Out")
                        }
                        .font(DesignSystem.font(size: 14))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(DesignSystem.surface)
                        .cornerRadius(DesignSystem.cornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        )
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
                .padding()
            }
            .cyberStyle()
            
            Spacer()
        }
        .padding()
        .background(DesignSystem.background)
    }
}

