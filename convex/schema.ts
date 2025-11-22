import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

/**
 * Schema for OMI Arena - Real-time multiplayer tag game
 * 
 * Tables:
 * - rooms: Game rooms with unique codes
 * - players: Player state and metadata
 * - tagEvents: History of tag attempts for scoring
 */

export default defineSchema({
  rooms: defineTable({
    // Room identifier (auto-generated)
    code: v.string(), // Human-readable room code (e.g., "ABC123")
    name: v.optional(v.string()), // Optional room name
    createdBy: v.id("players"), // Player who created the room
    status: v.string(), // "waiting", "in_progress", "finished"
    gameSettings: v.optional(v.object({
      rssiThreshold: v.number(), // RSSI threshold for valid tags (dBm)
      tagCooldownMs: v.number(), // Cooldown between tag attempts
      immunityMs: v.number(), // Immunity after being tagged
    })),
    createdAt: v.number(), // Unix timestamp
    startedAt: v.optional(v.number()), // When game started
    finishedAt: v.optional(v.number()), // When game ended
  }).index("by_code", ["code"]),

  players: defineTable({
    // Player identity
    name: v.string(), // Display name
    deviceId: v.optional(v.string()), // OMI device identifier
    deviceName: v.optional(v.string()), // BLE device name
    
    // Room association
    roomId: v.optional(v.id("rooms")), // Current room (null if not in room)
    
    // Game state
    isIt: v.boolean(), // Whether this player is currently "it"
    score: v.number(), // Number of successful tags
    tagsMade: v.number(), // Total tags attempted
    tagsReceived: v.number(), // Times been tagged
    
    // Device state (from BLE)
    motion: v.optional(v.object({
      ax: v.number(), // Acceleration X
      ay: v.number(), // Acceleration Y  
      az: v.number(), // Acceleration Z
    })),
    rssi: v.optional(v.number()), // Signal strength (dBm)
    lastMotionUpdate: v.optional(v.number()), // Timestamp of last motion data
    lastRssiUpdate: v.optional(v.number()), // Timestamp of last RSSI data
    
    // Timing for game logic
    lastTagAttemptAt: v.optional(v.number()), // When player last attempted to tag
    lastTaggedAt: v.optional(v.number()), // When player was last tagged
    
    // Connection state
    isOnline: v.boolean(), // Whether player is connected
    lastSeen: v.number(), // Last activity timestamp
    
    createdAt: v.number(), // When player record was created
  }).index("by_room", ["roomId"]).index("by_device", ["deviceId"]),

  tagEvents: defineTable({
    // Event metadata
    timestamp: v.number(), // When the tag occurred
    roomId: v.id("rooms"), // Which room this happened in
    
    // Players involved
    attackerId: v.id("players"), // Who attempted the tag
    defenderId: v.id("players"), // Who was tagged
    
    // Tag details
    success: v.boolean(), // Whether the tag was valid
    rssi: v.number(), // Signal strength at time of tag
    distance: v.optional(v.number()), // Estimated distance (if calculated)
    
    // Reason for failure (if applicable)
    failureReason: v.optional(v.string()), // "too_far", "cooldown", "immunity", etc.
  }).index("by_room", ["roomId"]).index("by_attacker", ["attackerId"]),
});
