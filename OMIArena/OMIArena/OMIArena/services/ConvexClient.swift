//
//  ConvexClient.swift
//  OMI Arena - Convex backend client wrapper
//
//  Handles communication with the Convex TypeScript backend
//  Provides real-time subscriptions and API calls
//

import Foundation
import Combine
import SwiftUI

/// Convex client wrapper for OMI Arena backend
/// Provides type-safe methods for all backend operations
@MainActor
class ConvexClient: ObservableObject {
    // MARK: - Published Properties
    @Published var isConnected: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Configuration
    private let baseURL: String
    private let session: URLSession
    private var subscriptions: [String: Task<Void, Never>] = [:]
    
    // MARK: - Initialization
    init(baseURL: String? = nil) {
        // Use provided URL or load from environment
        if let url = baseURL {
            self.baseURL = url
        } else {
            // Load from .env.local or use default
            self.baseURL = Self.loadConvexURL()
        }
        
        self.session = URLSession.shared
        
        print("🔗 Convex Client initialized with URL: \(self.baseURL)")
    }
    
    /// Initialize the client and test connection
    func initialize() {
        Task {
            await testConnection()
        }
    }
    
    // MARK: - Connection Management
    
    /// Test connection to Convex backend
    private func testConnection() async {
        do {
            let _ = try await performRequest("GET", "/api/version")
            await MainActor.run {
                self.isConnected = true
                print("✅ Connected to Convex backend")
            }
        } catch {
            await MainActor.run {
                self.isConnected = false
                self.showError("Failed to connect to Convex: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Player Management
    
    /// Create a new player or get existing one
    func createPlayer(name: String, deviceId: String? = nil) async throws -> PlayerModel {
        let payload: [String: Any] = [
            "name": name,
            "deviceId": deviceId as Any
        ]
        
        let response = try await performRequest("POST", "/api/players", body: payload)
        
        guard let playerData = response as? [String: Any],
              let player = PlayerModel(from: playerData) else {
            throw ConvexError.invalidResponse
        }
        
        return player
    }
    
    /// Update player's device information
    func updatePlayerDevice(playerId: String, deviceId: String, deviceName: String) async throws -> PlayerModel {
        let payload: [String: Any] = [
            "deviceId": deviceId,
            "deviceName": deviceName
        ]
        
        let response = try await performRequest("PATCH", "/api/players/\(playerId)", body: payload)
        
        guard let playerData = response as? [String: Any],
              let player = PlayerModel(from: playerData) else {
            throw ConvexError.invalidResponse
        }
        
        return player
    }
    
    /// Get player by ID
    func getPlayer(playerId: String) async throws -> PlayerModel? {
        let response = try await performRequest("GET", "/api/players/\(playerId)")
        
        guard let playerData = response as? [String: Any] else {
            return nil
        }
        
        return PlayerModel(from: playerData)
    }
    
    /// Remove player from current room
    func leaveRoom(playerId: String) async throws -> PlayerModel {
        let response = try await performRequest("POST", "/api/players/\(playerId)/leave")
        
        guard let playerData = response as? [String: Any],
              let player = PlayerModel(from: playerData) else {
            throw ConvexError.invalidResponse
        }
        
        return player
    }
    
    // MARK: - Room Management
    
    /// Create a new room
    func createRoom(creatorId: String, roomName: String? = nil) async throws -> RoomModel {
        let payload: [String: Any] = [
            "creatorId": creatorId,
            "roomName": roomName as Any
        ]
        
        let response = try await performRequest("POST", "/api/rooms", body: payload)
        
        guard let roomData = response as? [String: Any],
              let room = RoomModel(from: roomData) else {
            throw ConvexError.invalidResponse
        }
        
        return room
    }
    
    /// Get room by code
    func getRoomByCode(code: String) async throws -> RoomModel? {
        let response = try await performRequest("GET", "/api/rooms/code/\(code)")
        
        guard let roomData = response as? [String: Any] else {
            return nil
        }
        
        return RoomModel(from: roomData)
    }
    
    /// Join a room
    func joinRoom(playerId: String, roomCode: String) async throws -> (player: PlayerModel, room: RoomModel) {
        let payload: [String: Any] = [
            "playerId": playerId,
            "roomCode": roomCode
        ]
        
        let response = try await performRequest("POST", "/api/game/join", body: payload)
        
        guard let responseData = response as? [String: Any],
              let playerData = responseData["player"] as? [String: Any],
              let roomData = responseData["room"] as? [String: Any],
              let player = PlayerModel(from: playerData),
              let room = RoomModel(from: roomData) else {
            throw ConvexError.invalidResponse
        }
        
        return (player, room)
    }
    
    // MARK: - Game Actions
    
    /// Start a game in a room
    func startGame(roomId: String) async throws -> GameState {
        let payload: [String: Any] = ["roomId": roomId]
        
        let response = try await performRequest("POST", "/api/game/start", body: payload)
        
        guard let gameStateData = response as? [String: Any],
              let gameState = GameState(from: gameStateData) else {
            throw ConvexError.invalidResponse
        }
        
        return gameState
    }
    
    /// Attempt to tag another player
    func attemptTag(attackerId: String, defenderId: String) async throws -> TagResult {
        let payload: [String: Any] = [
            "attackerId": attackerId,
            "defenderId": defenderId
        ]
        
        let response = try await performRequest("POST", "/api/game/tag", body: payload)
        
        guard let resultData = response as? [String: Any] else {
            throw ConvexError.invalidResponse
        }
        
        return TagResult(
            success: resultData["success"] as? Bool ?? false,
            reason: resultData["reason"] as? String,
            newItPlayerId: resultData["newItPlayerId"] as? String,
            distance: resultData["distance"] as? Double
        )
    }
    
    /// Update player's motion data
    func updateMotion(playerId: String, motion: MotionData) async throws -> PlayerModel {
        let payload: [String: Any] = [
            "playerId": playerId,
            "motion": [
                "ax": motion.ax,
                "ay": motion.ay,
                "az": motion.az
            ]
        ]
        
        let response = try await performRequest("POST", "/api/game/motion", body: payload)
        
        guard let playerData = response as? [String: Any],
              let player = PlayerModel(from: playerData) else {
            throw ConvexError.invalidResponse
        }
        
        return player
    }
    
    /// Update player's RSSI data
    func updateRssi(playerId: String, rssi: Int) async throws -> PlayerModel {
        let payload: [String: Any] = [
            "playerId": playerId,
            "rssi": rssi
        ]
        
        let response = try await performRequest("POST", "/api/game/rssi", body: payload)
        
        guard let playerData = response as? [String: Any],
              let player = PlayerModel(from: playerData) else {
            throw ConvexError.invalidResponse
        }
        
        return player
    }
    
    /// Get current game state
    func getGameState(roomId: String) async throws -> GameState? {
        let response = try await performRequest("GET", "/api/game/state/\(roomId)")
        
        guard let gameStateData = response as? [String: Any] else {
            return nil
        }
        
        return GameState(from: gameStateData)
    }
    
    /// Get recent tag events
    func getRecentTagEvents(roomId: String, limit: Int = 10) async throws -> [TagEvent] {
        let response = try await performRequest("GET", "/api/game/events/\(roomId)?limit=\(limit)")
        
        guard let eventsArray = response as? [[String: Any]] else {
            return []
        }
        
        return eventsArray.compactMap { TagEvent(from: $0) }
    }
    
    // MARK: - Real-time Subscriptions
    
    /// Subscribe to game state updates for a room
    func subscribeToGameState(roomId: String) -> AsyncStream<GameState> {
        return AsyncStream { continuation in
            let subscriptionKey = "gameState_\(roomId)"
            
            let task = Task {
                // Simulate real-time updates with polling
                // In a real implementation, this would use WebSocket or SSE
                while !Task.isCancelled {
                    do {
                        if let gameState = try await self.getGameState(roomId: roomId) {
                            continuation.yield(gameState)
                        }
                    } catch {
                        print("Error in game state subscription: \(error)")
                    }
                    
                    // Poll every 1 second
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
                
                continuation.finish()
            }
            
            subscriptions[subscriptionKey] = task
            
            // Clean up subscription when stream is cancelled
            continuation.onTermination = { _ in
                DispatchQueue.main.async {
                    task.cancel()
                    self.subscriptions.removeValue(forKey: subscriptionKey)
                }
            }
        }
    }
    
    /// Subscribe to player updates
    func subscribeToPlayer(playerId: String) -> AsyncStream<PlayerModel> {
        return AsyncStream { continuation in
            let subscriptionKey = "player_\(playerId)"
            
            let task = Task {
                while !Task.isCancelled {
                    do {
                        if let player = try await self.getPlayer(playerId: playerId) {
                            continuation.yield(player)
                        }
                    } catch {
                        print("Error in player subscription: \(error)")
                    }
                    
                    // Poll every 2 seconds
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                }
                
                continuation.finish()
            }
            
            subscriptions[subscriptionKey] = task
            
            continuation.onTermination = { _ in
                DispatchQueue.main.async {
                    task.cancel()
                    self.subscriptions.removeValue(forKey: subscriptionKey)
                }
            }
        }
    }
    
    // MARK: - HTTP Request Handling
    
    /// Perform HTTP request to Convex backend
    private func performRequest(_ method: String, _ endpoint: String, body: [String: Any]? = nil) async throws -> Any {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw ConvexError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ConvexError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            throw ConvexError.serverError(httpResponse.statusCode)
        }
        
        let jsonResponse = try JSONSerialization.jsonObject(with: data)
        return jsonResponse
    }
    
    // MARK: - Configuration Loading
    
    /// Load Convex URL from environment configuration
    private static func loadConvexURL() -> String {
        // Try to load from .env.local file
        if let envPath = Bundle.main.path(forResource: ".env", ofType: "local"),
           let envData = try? String(contentsOfFile: envPath, encoding: .utf8) {
            let lines = envData.split(separator: "\n")
            for line in lines {
                let parts = line.split(separator: "=", maxSplits: 1)
                if parts.count == 2 && parts[0].trimmingCharacters(in: .whitespacesAndNewlines) == "CONVEX_URL" {
                    return String(parts[1].trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
        }
        
        // Fallback to default development URL
        // Use host machine IP for iOS simulator compatibility
        return "http://127.0.0.1:3210"
    }
    
    // MARK: - Error Handling
    
    /// Show error message
    private func showError(_ message: String) {
        errorMessage = message
        print("❌ Convex Error: \(message)")
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
    }
    
    /// Cancel all subscriptions
    func cancelAllSubscriptions() {
        for (_, task) in subscriptions {
            task.cancel()
        }
        subscriptions.removeAll()
    }
}

// MARK: - Error Types

enum ConvexError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(Int)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Convex URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let code):
            return "Server error: \(code)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Supporting Types

/// Result of a tag attempt
struct TagResult {
    let success: Bool
    let reason: String?
    let newItPlayerId: String?
    let distance: Double?
}
