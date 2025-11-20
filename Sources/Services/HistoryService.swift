import Foundation
import SwiftUI

class HistoryService: ObservableObject {
    static let shared = HistoryService()
    
    @Published var sessions: [ChatSession] = []
    
    private let fileName = "chat_history.json"
    
    private init() {
        loadSessions()
        cleanupExpiredSessions()
    }
    
    // MARK: - File Management
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func getFileURL() -> URL {
        getDocumentsDirectory().appendingPathComponent(fileName)
    }
    
    func saveSessions() {
        do {
            let data = try JSONEncoder().encode(sessions)
            try data.write(to: getFileURL())
        } catch {
            print("Error saving sessions: \(error)")
        }
    }
    
    func loadSessions() {
        let url = getFileURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        
        do {
            let data = try Data(contentsOf: url)
            sessions = try JSONDecoder().decode([ChatSession].self, from: data)
        } catch {
            print("Error loading sessions: \(error)")
        }
    }
    
    // MARK: - Session Management
    
    func createNewSession() -> ChatSession {
        let session = ChatSession(name: "Chat \(Date().formatted(date: .numeric, time: .shortened))")
        sessions.insert(session, at: 0)
        saveSessions()
        return session
    }
    
    func updateSession(_ session: ChatSession) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
            saveSessions()
        }
    }
    
    func deleteSession(_ id: UUID) {
        sessions.removeAll { $0.id == id }
        saveSessions()
    }
    
    func cleanupExpiredSessions() {
        let initialCount = sessions.count
        sessions.removeAll { $0.isExpired }
        
        if sessions.count != initialCount {
            print("Pruned \(initialCount - sessions.count) expired sessions.")
            saveSessions()
        }
    }
    
    // MARK: - Message Management
    
    func addMessage(_ message: ChatMessage, to sessionId: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        
        var session = sessions[index]
        session.messages.append(message)
        
        // Update name if it's the first user message and name is generic
        if session.messages.filter({ $0.role == .user }).count == 1,
           message.role == .user {
            session.name = String(message.content.prefix(30))
        }
        
        sessions[index] = session
        saveSessions()
    }
    
    func updateRetention(for sessionId: UUID, days: Int) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        sessions[index].retentionDays = days
        saveSessions()
    }
    
    func updateMessage(_ message: ChatMessage, in sessionId: UUID) {
        guard let sessionIndex = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        var session = sessions[sessionIndex]
        
        if let messageIndex = session.messages.firstIndex(where: { $0.id == message.id }) {
            session.messages[messageIndex] = message
            sessions[sessionIndex] = session
            saveSessions()
        }
    }
}

