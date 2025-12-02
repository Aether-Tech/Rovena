import SwiftUI

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
            .frame(minWidth: 1200, minHeight: 800)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 800)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize AuthManager (no Firebase SDK needed)
        AuthManager.shared.setup()
        
        // Garantir que a janela apareça
        if let window = NSApplication.shared.windows.first {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        
        // Initialize UpdateService (Sparkle)
        // O Sparkle agora é inicializado corretamente no UpdateService.init()
        // e não bloqueia a inicialização do app
        _ = UpdateService.shared
    }
}
