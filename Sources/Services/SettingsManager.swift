import Foundation

enum AppTheme: String, CaseIterable, Identifiable {
    case def = "Default"
    case terminal = "Classic (Terminal)"
    
    var id: String { self.rawValue }
}

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    @Published var openAIKey: String {
        didSet {
            UserDefaults.standard.set(openAIKey, forKey: "openAIKey")
            UserDefaults.standard.synchronize()
        }
    }
    
    @Published var anthropicKey: String {
        didSet {
            UserDefaults.standard.set(anthropicKey, forKey: "anthropicKey")
            UserDefaults.standard.synchronize()
        }
    }
    
    @Published var geminiKey: String {
        didSet {
            UserDefaults.standard.set(geminiKey, forKey: "geminiKey")
            UserDefaults.standard.synchronize()
        }
    }
    
    @Published var customEndpoint: String {
        didSet {
            UserDefaults.standard.set(customEndpoint, forKey: "customEndpoint")
            UserDefaults.standard.synchronize()
        }
    }
    
    @Published var isDarkMode: Bool {
        didSet { UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode") }
    }
    
    @Published var selectedTheme: AppTheme {
        didSet { UserDefaults.standard.set(selectedTheme.rawValue, forKey: "selectedTheme") }
    }
    
    init() {
        self.openAIKey = UserDefaults.standard.string(forKey: "openAIKey") ?? ""
        self.anthropicKey = UserDefaults.standard.string(forKey: "anthropicKey") ?? ""
        self.geminiKey = UserDefaults.standard.string(forKey: "geminiKey") ?? ""
        self.customEndpoint = UserDefaults.standard.string(forKey: "customEndpoint") ?? ""
        self.isDarkMode = UserDefaults.standard.object(forKey: "isDarkMode") as? Bool ?? true
        
        if let themeString = UserDefaults.standard.string(forKey: "selectedTheme"),
           let theme = AppTheme(rawValue: themeString) {
            self.selectedTheme = theme
        } else {
            self.selectedTheme = .def
        }
    }
    
    func saveKeys() {
        UserDefaults.standard.set(openAIKey, forKey: "openAIKey")
        UserDefaults.standard.set(anthropicKey, forKey: "anthropicKey")
        UserDefaults.standard.set(geminiKey, forKey: "geminiKey")
        UserDefaults.standard.set(customEndpoint, forKey: "customEndpoint")
        UserDefaults.standard.synchronize()
    }
}
