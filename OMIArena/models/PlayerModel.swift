//
//  PlayerModel.swift
//  OMI Arena - Player data model mirroring Convex backend
//
//  This model represents a player in the game and matches the Convex schema
//

import Foundation

/// Represents a player in OMI Arena
/// This struct mirrors the Convex player schema for type consistency
struct PlayerModel: Codable, Identifiable, Equatable {
    // Unique identifier (matches Convex _id)
    let id: String
    
    // Player identity
    let name: String
    let deviceId: String?
    let deviceName: String?
    
    // Room association
    let roomId: String?
    
    // Game state
    let isIt: Bool
    let score: Int
    let tagsMade: Int
    let tagsReceived: Int
    
    // Device state (from BLE)
    let motion: MotionData?
    let rssi: Int?
    let lastMotionUpdate: Date?
    let lastRssiUpdate: Date?
    
    // Timing for game logic
    let lastTagAttemptAt: Date?
    let lastTaggedAt: Date?
    
    // Connection state
    let isOnline: Bool
    let lastSeen: Date
    let createdAt: Date
    
    // Computed properties
    var isConnected: Bool {
        return isOnline && isRecentlyActive
    }
    
    var isRecentlyActive: Bool {
        let now = Date()
        let fiveMinutesAgo = now.addingTimeInterval(-5 * 60)
        return lastSeen > fiveMinutesAgo
    }
    
    var distanceEstimate: Double? {
        guard let rssi = rssi else { return nil }
        // Simplified distance estimation using path loss model
        // Distance = 10^((TX_POWER - RSSI) / (10 * N))
        let txPower = -59.0 // RSSI at 1 meter
        let pathLoss = 2.0 // Free space propagation
        let distance = pow(10, (txPower - Double(rssi)) / (10 * pathLoss))
        return max(0, distance)
    }
    
    var canBeTagged: Bool {
        // Check immunity period (2 seconds after being tagged)
        guard let lastTaggedAt = lastTaggedAt else { return true }
        let immunityPeriod: TimeInterval = 2.0
        return Date().timeIntervalSince(lastTaggedAt) > immunityPeriod
    }
    
    var canAttemptTag: Bool {
        // Check cooldown period (3 seconds between attempts)
        guard let lastTagAttemptAt = lastTagAttemptAt else { return true }
        let cooldownPeriod: TimeInterval = 3.0
        return Date().timeIntervalSince(lastTagAttemptAt) > cooldownPeriod
    }
}

/// Motion data from OMI device
struct MotionData: Codable, Equatable {
    let ax: Double // Acceleration X
    let ay: Double // Acceleration Y
    let az: Double // Acceleration Z
    
    // Computed properties for motion analysis
    var magnitude: Double {
        return sqrt(ax * ax + ay * ay + az * az)
    }
    
    var isMoving: Bool {
        // Simple motion detection - if magnitude exceeds gravity significantly
        return magnitude > 12.0 // Gravity is ~9.8 m/s²
    }
}

/// Player creation/update DTO for API calls
struct PlayerInput: Codable {
    let name: String
    let deviceId: String?
    let deviceName: String?
}

/// Player update DTO for partial updates
struct PlayerUpdate: Codable {
    let name: String?
    let deviceId: String?
    let deviceName: String?
    let isOnline: Bool?
}

// MARK: - Convex Integration

/// Extension to convert between Convex data and Swift models
extension PlayerModel {
    /// Initialize from Convex query response
    init?(from convexData: [String: Any]) {
        guard let id = convexData["_id"] as? String,
              let name = convexData["name"] as? String,
              let isIt = convexData["isIt"] as? Bool,
              let score = convexData["score"] as? Int,
              let tagsMade = convexData["tagsMade"] as? Int,
              let tagsReceived = convexData["tagsReceived"] as? Int,
              let isOnline = convexData["isOnline"] as? Bool,
              let lastSeenTimestamp = convexData["lastSeen"] as? Double,
              let createdAtTimestamp = convexData["createdAt"] as? Double else {
            return nil
        }
        
        self.id = id
        self.name = name
        self.deviceId = convexData["deviceId"] as? String
        self.deviceName = convexData["deviceName"] as? String
        self.roomId = convexData["roomId"] as? String
        self.isIt = isIt
        self.score = score
        self.tagsMade = tagsMade
        self.tagsReceived = tagsReceived
        self.isOnline = isOnline
        self.lastSeen = Date(timeIntervalSince1970: lastSeenTimestamp / 1000)
        self.createdAt = Date(timeIntervalSince1970: createdAtTimestamp / 1000)
        
        // Parse optional motion data
        if let motionDict = convexData["motion"] as? [String: Double],
           let ax = motionDict["ax"],
           let ay = motionDict["ay"],
           let az = motionDict["az"] {
            self.motion = MotionData(ax: ax, ay: ay, az: az)
        } else {
            self.motion = nil
        }
        
        // Parse RSSI
        self.rssi = convexData["rssi"] as? Int
        
        // Parse timestamps
        if let motionTimestamp = convexData["lastMotionUpdate"] as? Double {
            self.lastMotionUpdate = Date(timeIntervalSince1970: motionTimestamp / 1000)
        } else {
            self.lastMotionUpdate = nil
        }
        
        if let rssiTimestamp = convexData["lastRssiUpdate"] as? Double {
            self.lastRssiUpdate = Date(timeIntervalSince1970: rssiTimestamp / 1000)
        } else {
            self.lastRssiUpdate = nil
        }
        
        if let tagAttemptTimestamp = convexData["lastTagAttemptAt"] as? Double {
            self.lastTagAttemptAt = Date(timeIntervalSince1970: tagAttemptTimestamp / 1000)
        } else {
            self.lastTagAttemptAt = nil
        }
        
        if let taggedTimestamp = convexData["lastTaggedAt"] as? Double {
            self.lastTaggedAt = Date(timeIntervalSince1970: taggedTimestamp / 1000)
        } else {
            self.lastTaggedAt = nil
        }
    }
    
    /// Convert to dictionary for Convex mutations
    func toConvexDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "_id": id,
            "name": name,
            "isIt": isIt,
            "score": score,
            "tagsMade": tagsMade,
            "tagsReceived": tagsReceived,
            "isOnline": isOnline,
            "lastSeen": lastSeen.timeIntervalSince1970 * 1000,
            "createdAt": createdAt.timeIntervalSince1970 * 1000,
        ]
        
        if let deviceId = deviceId {
            dict["deviceId"] = deviceId
        }
        
        if let deviceName = deviceName {
            dict["deviceName"] = deviceName
        }
        
        if let roomId = roomId {
            dict["roomId"] = roomId
        }
        
        if let motion = motion {
            dict["motion"] = [
                "ax": motion.ax,
                "ay": motion.ay,
                "az": motion.az
            ]
        }
        
        if let rssi = rssi {
            dict["rssi"] = rssi
        }
        
        return dict
    }
}

// MARK: - Mock Data

/// Extension for generating mock players (useful for testing)
extension PlayerModel {
    static func mockPlayer(id: String = UUID().uuidString, name: String = "Mock Player") -> PlayerModel {
        return PlayerModel(
            id: id,
            name: name,
            deviceId: "mock_device_\(id)",
            deviceName: "OMI Dev Kit 2",
            roomId: nil,
            isIt: false,
            score: 0,
            tagsMade: 0,
            tagsReceived: 0,
            motion: MotionData(ax: 0.1, ay: 0.2, az: 9.8),
            rssi: -65,
            lastMotionUpdate: Date(),
            lastRssiUpdate: Date(),
            lastTagAttemptAt: nil,
            lastTaggedAt: nil,
            isOnline: true,
            lastSeen: Date(),
            createdAt: Date()
        )
    }
    
    static func mockPlayers(count: Int) -> [PlayerModel] {
        return (0..<count).map { index in
            PlayerModel.mockPlayer(
                id: UUID().uuidString,
                name: "Player \(index + 1)"
            )
        }
    }
}
