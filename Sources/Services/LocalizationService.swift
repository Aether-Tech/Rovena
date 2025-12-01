import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case portuguese = "pt-BR"
    case english = "en-US"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .portuguese: return "Português (Brasil)"
        case .english: return "English (US)"
        }
    }
    
    var locale: Locale {
        Locale(identifier: self.rawValue)
    }
}

class LocalizationService: ObservableObject {
    static let shared = LocalizationService()
    
    @Published var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "app_language")
        }
    }
    
    private init() {
        if let savedLanguage = UserDefaults.standard.string(forKey: "app_language"),
           let language = AppLanguage(rawValue: savedLanguage) {
            self.currentLanguage = language
        } else {
            // Default: Português Brasileiro
            self.currentLanguage = .portuguese
        }
    }
    
    func localized(_ key: String) -> String {
        // Por enquanto, retorna a chave. Pode ser expandido para usar arquivos de localização
        return key
    }
}

