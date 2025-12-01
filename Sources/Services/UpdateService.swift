import Foundation
import Sparkle
import SwiftUI

// Delegate para fornecer URL do appcast dinamicamente
class UpdateServiceDelegate: NSObject, SPUUpdaterDelegate {
    // URL do appcast (feed de atualizações)
    private let appcastURL = "https://raw.githubusercontent.com/Aether-Tech/Rovena/main/appcast.xml"
    
    func feedURLString(for updater: SPUUpdater) -> String? {
        return appcastURL
    }
}

class UpdateService: ObservableObject {
    static let shared = UpdateService()
    
    private let updaterController: SPUStandardUpdaterController
    private let updaterDelegate = UpdateServiceDelegate()
    
    @Published var isCheckingForUpdates = false
    @Published var updateStatus: String?
    
    var updater: SPUUpdater {
        updaterController.updater
    }
    
    private init() {
        // Configurar Sparkle com delegate para URL dinâmica
        // startingUpdater: false inicialmente para evitar erros se appcast não existir
        updaterController = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: updaterDelegate,
            userDriverDelegate: nil
        )
        
        // Iniciar updater após um pequeno delay para garantir que tudo está pronto
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.updaterController.startUpdater()
        }
    }
    
    /// Verifica atualizações manualmente
    func checkForUpdates() {
        isCheckingForUpdates = true
        updateStatus = "Verificando atualizações..."
        
        updater.checkForUpdates()
        
        // Resetar status após alguns segundos
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.isCheckingForUpdates = false
            if self.updateStatus == "Verificando atualizações..." {
                self.updateStatus = nil
            }
        }
    }
    
    /// Retorna a versão atual do app
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    /// Retorna o build number atual
    var currentBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    /// Retorna a versão completa (versão + build)
    var fullVersion: String {
        "\(currentVersion) (\(currentBuild))"
    }
}

