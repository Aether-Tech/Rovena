import Foundation

enum AppTheme: String, CaseIterable, Identifiable {
    case def = "Default"
    case terminal = "Classic (Terminal)"
    
    var id: String { self.rawValue }
}

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    // Chave de API padrão do Rovena Cloud
    // Lê na seguinte ordem: .env > variável de ambiente > Config.plist
    static var defaultRovenaAPIKey: String {
        // 1. Primeiro tenta ler de arquivo .env (mais seguro, não commitado)
        if let envKey = EnvLoader.getEnv("ROVENA_DEFAULT_API_KEY"), !envKey.isEmpty {
            return envKey
        }
        
        // 2. Depois tenta variável de ambiente do sistema (útil para builds/CI)
        if let envKey = ProcessInfo.processInfo.environment["ROVENA_DEFAULT_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        
        // 3. Por último tenta ler de Config.plist (fallback)
        if let configPath = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let configDict = NSDictionary(contentsOfFile: configPath),
           let apiKey = configDict["ROVENA_DEFAULT_API_KEY"] as? String, !apiKey.isEmpty {
            return apiKey
        }
        
        // Fallback: retorna string vazia (vai dar erro, mas é melhor que expor chave no código)
        print("⚠️ [SettingsManager] ROVENA_DEFAULT_API_KEY não encontrada.")
        print("   Configure em: .env, variável de ambiente ou Config.plist")
        return ""
    }
    
    // When true, Rovena uses the default API key instead of user's own keys.
    @Published var useRovenaCloud: Bool {
        didSet {
            UserDefaults.standard.set(useRovenaCloud, forKey: "useRovenaCloud")
        }
    }
    
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
    
    @Published var selectedLanguage: AppLanguage {
        didSet { 
            UserDefaults.standard.set(selectedLanguage.rawValue, forKey: "app_language")
            LocalizationService.shared.currentLanguage = selectedLanguage
        }
    }
    
    init() {
        self.useRovenaCloud = UserDefaults.standard.object(forKey: "useRovenaCloud") as? Bool ?? true
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
        
        if let languageString = UserDefaults.standard.string(forKey: "app_language"),
           let language = AppLanguage(rawValue: languageString) {
            self.selectedLanguage = language
            LocalizationService.shared.currentLanguage = language
        } else {
            self.selectedLanguage = .portuguese // Default: Português Brasileiro
            LocalizationService.shared.currentLanguage = .portuguese
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
