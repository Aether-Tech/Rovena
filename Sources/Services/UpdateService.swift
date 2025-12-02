import Foundation
import SwiftUI
#if canImport(Sparkle)
import Sparkle
#endif

/// Serviço de atualização usando Sparkle
///
/// - Usa o `SUFeedURL` definido no Info.plist gerado pelo workflow de release:
///   https://github.com/Aether-Tech/Rovena/releases/latest/download/appcast.xml
/// - Em builds de desenvolvimento (sem Info.plist customizado) você ainda pode
///   configurar um feed alternativo definindo a chave no Info.plist local.
class UpdateService: ObservableObject {
    static let shared = UpdateService()
    
    @Published var isCheckingForUpdates = false
    @Published var updateStatus: String?
    
    #if canImport(Sparkle)
    /// Controlador padrão do Sparkle 2 (cuida de checagens automáticas + UI)
    /// Segundo a documentação do Sparkle, o SPUStandardUpdaterController inicia
    /// automaticamente e gerencia as checagens de atualização em background.
    private var updaterController: SPUStandardUpdaterController?
    #endif
    
    private init() {
        #if canImport(Sparkle)
        // Inicializa o Sparkle updater controller
        // O parâmetro padrão startingUpdater: true inicia automaticamente
        // e gerencia as checagens automáticas de atualização
        updaterController = SPUStandardUpdaterController(
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        #endif
    }
    
    #if canImport(Sparkle)
    private func ensureUpdaterInitialized() {
        // O updater já é inicializado no init(), mas garantimos que existe
        if updaterController == nil {
            updaterController = SPUStandardUpdaterController(
                updaterDelegate: nil,
                userDriverDelegate: nil
            )
        }
    }
    #endif
    
    /// Verifica atualizações manualmente (botão em Settings)
    func checkForUpdates() {
        #if canImport(Sparkle)
        ensureUpdaterInitialized()
        isCheckingForUpdates = true
        updateStatus = "Verificando atualizações..."
        
        // Mostra o painel padrão do Sparkle
        updaterController?.checkForUpdates(nil)
        
        // Como não estamos escutando callbacks do Sparkle aqui, limpamos o estado
        // depois de alguns segundos só para o spinner não ficar preso.
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.isCheckingForUpdates = false
            if self.updateStatus == "Verificando atualizações..." {
                self.updateStatus = nil
            }
        }
        #else
        updateStatus = "Auto‑update não disponível neste build (Sparkle indisponível)."
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.updateStatus = nil
        }
        #endif
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
