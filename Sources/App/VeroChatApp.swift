import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize AuthManager (no Firebase SDK needed)
        AuthManager.shared.setup()
        
        // Initialize UpdateService (Sparkle) após um delay para não bloquear a inicialização
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            _ = UpdateService.shared
        }
    }
}

@main
struct VeroChatApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    // Use @ObservedObject for singletons, not @StateObject
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var authManager = AuthManager.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.user != nil {
                    ContentView()
                } else {
                    LoginView()
                }
            }
            .environmentObject(settings)
            .preferredColorScheme(settings.isDarkMode ? .dark : .light)
            .background(DesignSystem.background)
        }
        .windowStyle(.hiddenTitleBar)
    }
}
