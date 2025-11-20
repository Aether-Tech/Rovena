import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize AuthManager (no Firebase SDK needed)
        AuthManager.shared.setup()
    }
}

@main
struct VeroChatApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    @StateObject private var settings = SettingsManager.shared
    @StateObject private var authManager = AuthManager.shared

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
