//
//  RoomModel.swift
//  OMI Arena - Room data model mirroring Convex backend
//
//  This model represents a game room and matches the Convex schema
//

import Foundation

/// Represents a game room in OMI Arena
/// This struct mirrors the Convex room schema for type consistency
struct RoomModel: Codable, Identifiable, Equatable {
    // Unique identifier (matches Convex _id)
    let id: String
    
    // Room identification
    let code: String // 6-character room code
    let name: String? // Optional human-readable name
    
    // Room management
    let createdBy: String // Player ID who created the room
    let status: RoomStatus
    
    // Game configuration
    let gameSettings: GameSettings
    
    // Timestamps
    let createdAt: Date
    let startedAt: Date?
    let finishedAt: Date?
    
    // Computed properties
    var isActive: Bool {
        return status == .inProgress
    }
    
    var isWaiting: Bool {
        return status == .waiting
    }
    
    var isFinished: Bool {
        return status == .finished
    }
    
    var duration: TimeInterval? {
        guard let startedAt = startedAt else { return nil }
        let endTime = finishedAt ?? Date()
        return endTime.timeIntervalSince(startedAt)
    }
}

/// Room status enumeration
enum RoomStatus: String, Codable, CaseIterable {
    case waiting = "waiting"      // Room created, waiting for players
    case inProgress = "in_progress" // Game is active
    case finished = "finished"     // Game has ended
    
    var displayName: String {
        switch self {
        case .waiting:
            return "Waiting for Players"
        case .inProgress:
            return "Game in Progress"
        case .finished:
            return "Game Finished"
        }
    }
    
    var color: String {
        switch self {
        case .waiting:
            return "orange"
        case .inProgress:
            return "green"
        case .finished:
            return "gray"
        }
    }
}

/// Game settings for a room
struct GameSettings: Codable, Equatable {
    let rssiThreshold: Int      // RSSI threshold for valid tags (dBm)
    let tagCooldownMs: Int      // Cooldown between tag attempts
    let immunityMs: Int         // Immunity after being tagged
    
    // Default settings
    static let `default` = GameSettings(
        rssiThreshold: -65,
        tagCooldownMs: 3000,
        immunityMs: 2000
    )
    
    // Computed properties for easy access
    var tagCooldownSeconds: Double {
        return Double(tagCooldownMs) / 1000.0
    }
    
    var immunitySeconds: Double {
        return Double(immunityMs) / 1000.0
    }
}

/// Room creation DTO for API calls
struct RoomInput: Codable {
    let roomName: String?
    let gameSettings: GameSettings?
}

/// Game state summary for a room
struct GameState: Codable, Identifiable {
    let id: String // Room ID
    let room: RoomModel
    let players: [PlayerModel]
    let itPlayerId: String?
    let playerCount: Int
    
    // Computed properties
    var itPlayer: PlayerModel? {
        return players.first { $0.id == itPlayerId }
    }
    
    var sortedPlayers: [PlayerModel] {
        return players.sorted { $0.score > $1.score }
    }
    
    var leaderboard: [PlayerModel] {
        return sortedPlayers.prefix(10).map { $0 }
    }
}

/// Tag event for game history
struct TagEvent: Codable, Identifiable {
    let id: String
    let timestamp: Date
    let roomId: String
    let attackerId: String
    let defenderId: String
    let success: Bool
    let rssi: Int
    let distance: Double?
    let failureReason: String?
    
    var displayName: String {
        if success {
            return "Successful Tag"
        } else {
            return "Failed Tag: \(failureReason ?? "Unknown")"
        }
    }
}

// MARK: - Convex Integration

/// Extension to convert between Convex data and Swift models
extension RoomModel {
    /// Initialize from Convex query response
    init?(from convexData: [String: Any]) {
        guard let id = convexData["_id"] as? String,
              let code = convexData["code"] as? String,
              let createdBy = convexData["createdBy"] as? String,
              let statusString = convexData["status"] as? String,
              let status = RoomStatus(rawValue: statusString),
              let createdAtTimestamp = convexData["createdAt"] as? Double else {
            return nil
        }
        
        self.id = id
        self.code = code
        self.name = convexData["name"] as? String
        self.createdBy = createdBy
        self.status = status
        
        // Parse game settings
        if let settingsDict = convexData["gameSettings"] as? [String: Any],
           let rssiThreshold = settingsDict["rssiThreshold"] as? Int,
           let tagCooldownMs = settingsDict["tagCooldownMs"] as? Int,
           let immunityMs = settingsDict["immunityMs"] as? Int {
            self.gameSettings = GameSettings(
                rssiThreshold: rssiThreshold,
                tagCooldownMs: tagCooldownMs,
                immunityMs: immunityMs
            )
        } else {
            self.gameSettings = .default
        }
        
        self.createdAt = Date(timeIntervalSince1970: createdAtTimestamp / 1000)
        
        // Parse optional timestamps
        if let startedAtTimestamp = convexData["startedAt"] as? Double {
            self.startedAt = Date(timeIntervalSince1970: startedAtTimestamp / 1000)
        } else {
            self.startedAt = nil
        }
        
        if let finishedAtTimestamp = convexData["finishedAt"] as? Double {
            self.finishedAt = Date(timeIntervalSince1970: finishedAtTimestamp / 1000)
        } else {
            self.finishedAt = nil
        }
    }
    
    /// Convert to dictionary for Convex mutations
    func toConvexDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "_id": id,
            "code": code,
            "createdBy": createdBy,
            "status": status.rawValue,
            "gameSettings": [
                "rssiThreshold": gameSettings.rssiThreshold,
                "tagCooldownMs": gameSettings.tagCooldownMs,
                "immunityMs": gameSettings.immunityMs
            ],
            "createdAt": createdAt.timeIntervalSince1970 * 1000,
        ]
        
        if let name = name {
            dict["name"] = name
        }
        
        if let startedAt = startedAt {
            dict["startedAt"] = startedAt.timeIntervalSince1970 * 1000
        }
        
        if let finishedAt = finishedAt {
            dict["finishedAt"] = finishedAt.timeIntervalSince1970 * 1000
        }
        
        return dict
    }
}

extension GameState {
    /// Initialize from Convex game state query
    init?(from convexData: [String: Any]) {
        guard let roomDict = convexData["room"] as? [String: Any],
              let room = RoomModel(from: roomDict),
              let playersArray = convexData["players"] as? [[String: Any]],
              let playerCount = convexData["playerCount"] as? Int else {
            return nil
        }
        
        self.id = room.id
        self.room = room
        self.players = playersArray.compactMap { PlayerModel(from: $0) }
        self.itPlayerId = convexData["itPlayerId"] as? String
        self.playerCount = playerCount
    }
}

extension TagEvent {
    /// Initialize from Convex tag event data
    init?(from convexData: [String: Any]) {
        guard let id = convexData["_id"] as? String,
              let timestamp = convexData["timestamp"] as? Double,
              let roomId = convexData["roomId"] as? String,
              let attackerId = convexData["attackerId"] as? String,
              let defenderId = convexData["defenderId"] as? String,
              let success = convexData["success"] as? Bool,
              let rssi = convexData["rssi"] as? Int else {
            return nil
        }
        
        self.id = id
        self.timestamp = Date(timeIntervalSince1970: timestamp / 1000)
        self.roomId = roomId
        self.attackerId = attackerId
        self.defenderId = defenderId
        self.success = success
        self.rssi = rssi
        self.distance = convexData["distance"] as? Double
        self.failureReason = convexData["failureReason"] as? String
    }
}

// MARK: - Mock Data

/// Extension for generating mock rooms (useful for testing)
extension RoomModel {
    static func mockRoom(
        id: String = UUID().uuidString,
        code: String = "ABC123",
        name: String? = nil,
        status: RoomStatus = .waiting
    ) -> RoomModel {
        let now = Date()
        return RoomModel(
            id: id,
            code: code,
            name: name,
            createdBy: "mock_creator_id",
            status: status,
            gameSettings: .default,
            createdAt: now,
            startedAt: status == .inProgress ? now.addingTimeInterval(-60) : nil,
            finishedAt: status == .finished ? now.addingTimeInterval(-30) : nil
        )
    }
    
    static func mockRooms(count: Int) -> [RoomModel] {
        let statuses: [RoomStatus] = [.waiting, .inProgress, .finished]
        return (0..<count).map { index in
            RoomModel.mockRoom(
                id: UUID().uuidString,
                code: generateRoomCode(),
                name: "Test Room \(index + 1)",
                status: statuses[index % statuses.count]
            )
        }
    }
}

/// Helper function to generate room codes (matches backend logic)
func generateRoomCode() -> String {
    let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    var code = ""
    for _ in 0..<6 {
        if let randomChar = chars.randomElement() {
            code.append(randomChar)
        }
    }
    return code
}
