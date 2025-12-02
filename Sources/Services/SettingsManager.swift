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
            LogManager.shared.addLog("ROVENA_DEFAULT_API_KEY loaded from .env file (length: \(envKey.count))", level: .debug, category: "SettingsManager")
            return envKey.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // 2. Depois tenta variável de ambiente do sistema (útil para builds/CI)
        if let envKey = ProcessInfo.processInfo.environment["ROVENA_DEFAULT_API_KEY"], !envKey.isEmpty {
            LogManager.shared.addLog("ROVENA_DEFAULT_API_KEY loaded from environment variable (length: \(envKey.count))", level: .debug, category: "SettingsManager")
            return envKey.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // 3. Por último tenta ler de Config.plist (fallback)
        if let configPath = Bundle.main.path(forResource: "Config", ofType: "plist") {
            print("🔍 [SettingsManager] Config.plist found at: \(configPath)")
            LogManager.shared.addLog("Config.plist found at: \(configPath)", level: .info, category: "SettingsManager")
            
            if let configDict = NSDictionary(contentsOfFile: configPath) {
                let allKeys = configDict.allKeys as? [String] ?? []
                print("🔑 [SettingsManager] Config.plist keys: \(allKeys.joined(separator: ", "))")
                LogManager.shared.addLog("Config.plist keys: \(allKeys.joined(separator: ", "))", level: .info, category: "SettingsManager")
                
                if let apiKey = configDict["ROVENA_DEFAULT_API_KEY"] as? String, !apiKey.isEmpty {
                    let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                    print("✅ [SettingsManager] ROVENA_DEFAULT_API_KEY loaded from Config.plist (length: \(trimmedKey.count), prefix: \(trimmedKey.prefix(10)))")
                    LogManager.shared.addLog("✅ ROVENA_DEFAULT_API_KEY loaded from Config.plist (length: \(trimmedKey.count), prefix: \(trimmedKey.prefix(10)))", level: .info, category: "SettingsManager")
                    
                    // Validar formato básico da chave
                    if !trimmedKey.hasPrefix("sk-") {
                        print("⚠️ [SettingsManager] WARNING: API key doesn't start with 'sk-' - may be invalid")
                        LogManager.shared.addLog("⚠️ WARNING: API key doesn't start with 'sk-' - may be invalid", level: .warning, category: "SettingsManager")
                    }
                    
                    return trimmedKey
                } else {
                    print("⚠️ [SettingsManager] ROVENA_DEFAULT_API_KEY not found in Config.plist or is empty")
                    LogManager.shared.addLog("⚠️ ROVENA_DEFAULT_API_KEY not found in Config.plist or is empty", level: .warning, category: "SettingsManager")
                    if let value = configDict["ROVENA_DEFAULT_API_KEY"] {
                        print("🔍 [SettingsManager] Value type: \(type(of: value)), Value preview: \(String(describing: value).prefix(20))...")
                        LogManager.shared.addLog("Value type: \(type(of: value)), Value preview: \(String(describing: value).prefix(20))...", level: .debug, category: "SettingsManager")
                    }
                }
            } else {
                print("❌ [SettingsManager] Failed to read Config.plist as NSDictionary")
                LogManager.shared.addLog("❌ Failed to read Config.plist as NSDictionary", level: .error, category: "SettingsManager")
            }
        } else {
            print("⚠️ [SettingsManager] Config.plist not found in bundle")
            if let resourcePath = Bundle.main.resourcePath {
                print("📁 [SettingsManager] Bundle resource path: \(resourcePath)")
                if let contents = try? FileManager.default.contentsOfDirectory(atPath: resourcePath) {
                    print("📁 [SettingsManager] Bundle contents: \(contents.joined(separator: ", "))")
                }
            }
            LogManager.shared.addLog("⚠️ Config.plist not found in bundle", level: .warning, category: "SettingsManager")
        }
        
        // Fallback: retorna string vazia (vai dar erro, mas é melhor que expor chave no código)
        LogManager.shared.addLog("❌ ROVENA_DEFAULT_API_KEY não encontrada. Configure em: .env, variável de ambiente ou Config.plist", level: .error, category: "SettingsManager")
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
