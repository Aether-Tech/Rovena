import Foundation

/// Helper para carregar variáveis de ambiente de arquivo .env
class EnvLoader {
    static func loadEnv(from path: String? = nil) -> [String: String] {
        // Se um caminho foi especificado, usa ele
        if let customPath = path {
            guard let contents = try? String(contentsOfFile: customPath, encoding: .utf8) else {
                return [:]
            }
            return parseEnvFile(contents)
        }
        
        // Tenta encontrar .env em vários locais
        let fileManager = FileManager.default
        var possiblePaths: [String] = []
        
        // 1. Na raiz do workspace (onde está o Package.swift)
        // Para apps macOS, o bundle resource path pode estar em Sources/App
        if let bundlePath = Bundle.main.resourcePath {
            // Tenta subir alguns níveis para encontrar a raiz do projeto
            var workspaceRoot = bundlePath
            for _ in 0..<5 {
                let envPath = workspaceRoot + "/.env"
                if fileManager.fileExists(atPath: envPath) {
                    possiblePaths.append(envPath)
                }
                workspaceRoot = (workspaceRoot as NSString).deletingLastPathComponent
            }
        }
        
        // 2. No diretório atual de trabalho
        possiblePaths.append(fileManager.currentDirectoryPath + "/.env")
        
        // 3. No diretório home do usuário
        if let homeDir = ProcessInfo.processInfo.environment["HOME"] {
            possiblePaths.append(homeDir + "/.rovena/.env")
        }
        
        // Procura o primeiro arquivo .env que existir e consegue ler
        for envPath in possiblePaths {
            if fileManager.fileExists(atPath: envPath),
               let contents = try? String(contentsOfFile: envPath, encoding: .utf8) {
                return parseEnvFile(contents)
            }
        }
        
        // Se não encontrou nenhum, retorna vazio
        return [:]
    }
    
    private static func parseEnvFile(_ contents: String) -> [String: String] {
        var env: [String: String] = [:]
        let lines = contents.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Ignora linhas vazias e comentários
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }
            
            // Parse KEY=VALUE
            if let range = trimmed.range(of: "=") {
                let key = String(trimmed[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                var value = String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                
                // Remove aspas se houver
                if (value.hasPrefix("\"") && value.hasSuffix("\"")) || 
                   (value.hasPrefix("'") && value.hasSuffix("'")) {
                    value = String(value.dropFirst().dropLast())
                }
                
                if !key.isEmpty && !value.isEmpty {
                    env[key] = value
                }
            }
        }
        
        return env
    }
    
    /// Carrega uma variável específica do .env
    static func getEnv(_ key: String) -> String? {
        let env = loadEnv()
        return env[key]
    }
}

