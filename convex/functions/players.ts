/**
 * Player Management Functions for OMI Arena
 * 
 * Handles player creation, updates, and room association.
 */

import { v } from "convex/values";
import { mutation, query } from "./_generated/server";

/**
 * Create a new player record
 * 
 * @param name Display name for the player
 * @param deviceId Optional OMI device identifier
 * @param deviceName Optional BLE device name
 * @returns The newly created player object
 */
export const createPlayer = mutation({
  args: {
    name: v.string(),
    deviceId: v.optional(v.string()),
    deviceName: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const { name, deviceId, deviceName } = args;
    
    // Check if player with this device ID already exists
    if (deviceId) {
      const existingPlayer = await ctx.db
        .query("players")
        .withIndex("by_device", (q) => q.eq("deviceId", deviceId))
        .first();
      
      if (existingPlayer) {
        // Return existing player instead of creating duplicate
        return existingPlayer;
      }
    }

    const now = Date.now();
    const playerId = await ctx.db.insert("players", {
      name,
      deviceId,
      deviceName,
      roomId: undefined, // Not in a room initially
      isIt: false,
      score: 0,
      tagsMade: 0,
      tagsReceived: 0,
      isOnline: true,
      lastSeen: now,
      createdAt: now,
    });

    const player = await ctx.db.get(playerId);
    if (!player) {
      throw new Error("Failed to create player");
    }

    return player;
  },
});

/**
 * Update player's online status and last seen timestamp
 * 
 * @param playerId The player ID
 * @param isOnline Whether the player is currently online
 * @returns The updated player object
 */
export const updatePlayerStatus = mutation({
  args: {
    playerId: v.id("players"),
    isOnline: v.boolean(),
  },
  handler: async (ctx, args) => {
    const { playerId, isOnline } = args;
    
    const player = await ctx.db.get(playerId);
    if (!player) {
      throw new Error("Player not found");
    }

    await ctx.db.patch(playerId, {
      isOnline,
      lastSeen: Date.now(),
    });

    return await ctx.db.get(playerId);
  },
});

/**
 * Update player's device information
 * 
 * @param playerId The player ID
 * @param deviceId OMI device identifier
 * @param deviceName BLE device name
 * @returns The updated player object
 */
export const updatePlayerDevice = mutation({
  args: {
    playerId: v.id("players"),
    deviceId: v.optional(v.string()),
    deviceName: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const { playerId, deviceId, deviceName } = args;
    
    const player = await ctx.db.get(playerId);
    if (!player) {
      throw new Error("Player not found");
    }

    // Check if another player is already using this device ID
    if (deviceId) {
      const existingPlayer = await ctx.db
        .query("players")
        .withIndex("by_device", (q) => q.eq("deviceId", deviceId))
        .first();
      
      if (existingPlayer && existingPlayer._id !== playerId) {
        throw new Error("Device ID already in use by another player");
      }
    }

    await ctx.db.patch(playerId, {
      deviceId,
      deviceName,
      lastSeen: Date.now(),
    });

    return await ctx.db.get(playerId);
  },
});

/**
 * Get a player by their ID
 * 
 * @param playerId The player ID
 * @returns The player object if found, null otherwise
 */
export const getPlayerById = query({
  args: {
    playerId: v.id("players"),
  },
  handler: async (ctx, args) => {
    const { playerId } = args;
    
    const player = await ctx.db.get(playerId);
    return player || null;
  },
});

/**
 * Get a player by their device ID
 * 
 * @param deviceId The OMI device identifier
 * @returns The player object if found, null otherwise
 */
export const getPlayerByDeviceId = query({
  args: {
    deviceId: v.string(),
  },
  handler: async (ctx, args) => {
    const { deviceId } = args;
    
    const player = await ctx.db
      .query("players")
      .withIndex("by_device", (q) => q.eq("deviceId", deviceId))
      .first();

    return player || null;
  },
});

/**
 * Remove a player from their current room
 * 
 * @param playerId The player ID
 * @returns The updated player object
 */
export const leaveRoom = mutation({
  args: {
    playerId: v.id("players"),
  },
  handler: async (ctx, args) => {
    const { playerId } = args;
    
    const player = await ctx.db.get(playerId);
    if (!player) {
      throw new Error("Player not found");
    }

    // Clear room association and reset game state
    await ctx.db.patch(playerId, {
      roomId: undefined,
      isIt: false,
      score: 0,
      tagsMade: 0,
      tagsReceived: 0,
      motion: undefined,
      rssi: undefined,
      lastMotionUpdate: undefined,
      lastRssiUpdate: undefined,
      lastTagAttemptAt: undefined,
      lastTaggedAt: undefined,
      lastSeen: Date.now(),
    });

    return await ctx.db.get(playerId);
  },
});

/**
 * Update player's motion data from OMI device
 * 
 * @param playerId The player ID
 * @param motion Motion vector { ax, ay, az }
 * @returns The updated player object
 */
export const updatePlayerMotion = mutation({
  args: {
    playerId: v.id("players"),
    motion: v.object({
      ax: v.number(),
      ay: v.number(),
      az: v.number(),
    }),
  },
  handler: async (ctx, args) => {
    const { playerId, motion } = args;
    
    const player = await ctx.db.get(playerId);
    if (!player) {
      throw new Error("Player not found");
    }

    const now = Date.now();
    await ctx.db.patch(playerId, {
      motion,
      lastMotionUpdate: now,
      lastSeen: now,
    });

    return await ctx.db.get(playerId);
  },
});

/**
 * Update player's RSSI data for distance estimation
 * 
 * @param playerId The player ID
 * @param rssi Signal strength in dBm
 * @returns The updated player object
 */
export const updatePlayerRssi = mutation({
  args: {
    playerId: v.id("players"),
    rssi: v.number(),
  },
  handler: async (ctx, args) => {
    const { playerId, rssi } = args;
    
    const player = await ctx.db.get(playerId);
    if (!player) {
      throw new Error("Player not found");
    }

    const now = Date.now();
    await ctx.db.patch(playerId, {
      rssi,
      lastRssiUpdate: now,
      lastSeen: now,
    });

    return await ctx.db.get(playerId);
  },
});

/**
 * Clean up offline players (remove from rooms if inactive for too long)
 * This should be called periodically to maintain room state
 * 
 * @param inactiveThresholdMs Time threshold for considering a player inactive
 * @returns Number of players cleaned up
 */
export const cleanupInactivePlayers = mutation({
  args: {
    inactiveThresholdMs: v.number(), // Default: 5 minutes = 300000ms
  },
  handler: async (ctx, args) => {
    const { inactiveThresholdMs } = args;
    
    const now = Date.now();
    const cutoffTime = now - inactiveThresholdMs;
    
    // Find players who haven't been seen recently
    const inactivePlayers = await ctx.db
      .query("players")
      .filter((q) => q.lt(q.field("lastSeen"), cutoffTime))
      .collect();

    let cleanedCount = 0;
    
    for (const player of inactivePlayers) {
      if (player.roomId) {
        // Remove inactive players from their rooms
        await ctx.db.patch(player._id, {
          roomId: undefined,
          isIt: false,
          isOnline: false,
        });
        cleanedCount++;
      }
    }

    return cleanedCount;
  },
});
