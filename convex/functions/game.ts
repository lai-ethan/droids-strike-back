/**
 * Game Logic Functions for OMI Arena
 * 
 * Core game mechanics including joining rooms, updating device data,
 * and handling tag attempts with server-authoritative validation.
 */

import { v } from "convex/values";
import { mutation, query } from "./_generated/server";
import { 
  validateTagAttempt, 
  updateItStatus, 
  GAME_CONSTANTS 
} from "../lib/tagLogic";

/**
 * Join a room with a player (high-level join flow)
 * 
 * @param playerId The player joining
 * @param roomCode The 6-character room code
 * @returns Updated player and room objects
 */
export const joinRoom = mutation({
  args: {
    playerId: v.id("players"),
    roomCode: v.string(),
  },
  handler: async (ctx, args) => {
    const { playerId, roomCode } = args;
    
    // Get the player
    const player = await ctx.db.get(playerId);
    if (!player) {
      throw new Error("Player not found");
    }

    // Find the room by code
    const room = await ctx.db.query("rooms").withIndex("by_code", (q) => q.eq("code", roomCode)).first();
    if (!room) {
      throw new Error("Room not found");
    }

    // Check if room is accepting players
    if (room.status !== "waiting") {
      throw new Error("Room is not accepting new players");
    }

    // Update player to join the room
    await ctx.db.patch(playerId, {
      roomId: room._id,
      isOnline: true,
      lastSeen: Date.now(),
      // Reset game state for new room
      isIt: false,
      score: 0,
      tagsMade: 0,
      tagsReceived: 0,
      lastTagAttemptAt: undefined,
      lastTaggedAt: undefined,
    });

    // Get updated player
    const updatedPlayer = await ctx.db.get(playerId);
    if (!updatedPlayer) {
      throw new Error("Failed to update player");
    }

    return {
      player: updatedPlayer,
      room,
    };
  },
});

/**
 * Update a player's motion data from their OMI device
 * 
 * @param playerId The player ID
 * @param motion Motion vector { ax, ay, az }
 * @returns The updated player object
 */
export const updateMotion = mutation({
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

    // Only update if player is in a room (game state tracking)
    if (!player.roomId) {
      // Still update motion but don't track it for game logic
      const now = Date.now();
      await ctx.db.patch(playerId, {
        motion,
        lastMotionUpdate: now,
        lastSeen: now,
      });
      return await ctx.db.get(playerId);
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
 * Update a player's RSSI data for distance estimation
 * 
 * @param playerId The player ID
 * @param rssi Signal strength in dBm
 * @returns The updated player object
 */
export const updateRssi = mutation({
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

    // Only update if player is in a room
    if (!player.roomId) {
      const now = Date.now();
      await ctx.db.patch(playerId, {
        rssi,
        lastRssiUpdate: now,
        lastSeen: now,
      });
      return await ctx.db.get(playerId);
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
 * Attempt to tag another player (core game action)
 * 
 * @param attackerId Player attempting the tag
 * @param defenderId Player being tagged
 * @returns Tag attempt result with updated game state
 */
export const attemptTag = mutation({
  args: {
    attackerId: v.id("players"),
    defenderId: v.id("players"),
  },
  handler: async (ctx, args) => {
    const { attackerId, defenderId } = args;
    
    // Get both players
    const attacker = await ctx.db.get(attackerId);
    const defender = await ctx.db.get(defenderId);
    
    if (!attacker || !defender) {
      throw new Error("Player not found");
    }

    // Validate both players are in the same room
    if (!attacker.roomId || !defender.roomId || attacker.roomId !== defender.roomId) {
      throw new Error("Players must be in the same room to tag");
    }

    // Validate game is in progress
    const room = await ctx.db.get(attacker.roomId);
    if (!room || room.status !== "in_progress") {
      throw new Error("Game is not in progress");
    }

    // Get room settings (or use defaults)
    const settings = room.gameSettings || {
      rssiThreshold: GAME_CONSTANTS.RSSI_THRESHOLD,
      tagCooldownMs: GAME_CONSTANTS.TAG_COOLDOWN_MS,
      immunityMs: GAME_CONSTANTS.TAG_IMMUNITY_MS,
    };

    const currentTime = Date.now();

    // Validate the tag attempt
    const validation = validateTagAttempt({
      attackerRssi: attacker.rssi,
      defenderRssi: defender.rssi,
      attackerLastTagAttempt: attacker.lastTagAttemptAt,
      defenderLastTagged: defender.lastTaggedAt,
      currentTime,
    });

    // Record the tag attempt regardless of outcome
    const tagEventId = await ctx.db.insert("tagEvents", {
      timestamp: currentTime,
      roomId: attacker.roomId,
      attackerId,
      defenderId,
      success: validation.success,
      rssi: (attacker.rssi && defender.rssi) ? (attacker.rssi + defender.rssi) / 2 : 0,
      distance: validation.distance,
      failureReason: validation.success ? undefined : validation.reason,
    });

    if (!validation.success) {
      // Tag failed - update attacker's cooldown and return failure
      await ctx.db.patch(attackerId, {
        lastTagAttemptAt: currentTime,
        tagsMade: attacker.tagsMade + 1,
        lastSeen: currentTime,
      });

      return {
        success: false,
        reason: validation.reason,
        distance: validation.distance,
        tagEventId,
      };
    }

    // Tag succeeded! Update game state
    const newItPlayerId = updateItStatus(
      attackerId,
      defenderId,
      // Find current "it" player in the room
      (() => {
        // This is a simplified approach - in production you'd query for current "it"
        return attacker.isIt ? attackerId : (defender.isIt ? defenderId : attackerId);
      })()
    );

    // Update attacker stats
    await ctx.db.patch(attackerId, {
      lastTagAttemptAt: currentTime,
      score: attacker.score + 1,
      tagsMade: attacker.tagsMade + 1,
      isIt: newItPlayerId === attackerId,
      lastSeen: currentTime,
    });

    // Update defender stats
    await ctx.db.patch(defenderId, {
      lastTaggedAt: currentTime,
      tagsReceived: defender.tagsReceived + 1,
      isIt: newItPlayerId === defenderId,
      lastSeen: currentTime,
    });

    // If the "it" status changed, update the previous "it" player
    if (newItPlayerId !== attackerId && newItPlayerId !== defenderId) {
      // This means someone else was "it" and needs to be updated
      // In a real implementation, you'd query for the current "it" player
      // For now, we'll assume the game logic handles this correctly
    }

    return {
      success: true,
      newItPlayerId,
      distance: validation.distance,
      tagEventId,
    };
  },
});

/**
 * Start a game in a room (select who is "it" and change status)
 * 
 * @param roomId The room to start
 * @returns Updated room and initial game state
 */
export const startGame = mutation({
  args: {
    roomId: v.id("rooms"),
  },
  handler: async (ctx, args) => {
    const { roomId } = args;
    
    const room = await ctx.db.get(roomId);
    if (!room) {
      throw new Error("Room not found");
    }

    if (room.status !== "waiting") {
      throw new Error("Game is already in progress or finished");
    }

    // Get all players in the room
    const players = await ctx.db.query("players").withIndex("by_room", (q) => q.eq("roomId", roomId)).collect();

    if (players.length < 2) {
      throw new Error("Need at least 2 players to start a game");
    }

    // Randomly select who is "it"
    const randomIndex = Math.floor(Math.random() * players.length);
    const itPlayerId = players[randomIndex]._id;

    // Update all players' game state
    for (const player of players) {
      await ctx.db.patch(player._id, {
        isIt: player._id === itPlayerId,
        score: 0,
        tagsMade: 0,
        tagsReceived: 0,
        lastTagAttemptAt: undefined,
        lastTaggedAt: undefined,
        lastSeen: Date.now(),
      });
    }

    // Update room status
    await ctx.db.patch(roomId, { status: "in_progress", startedAt: Date.now() });
    const updatedRoom = await ctx.db.get(roomId);

    return {
      room: updatedRoom,
      itPlayerId,
      playerCount: players.length,
    };
  },
});

/**
 * Get current game state for a room
 * 
 * @param roomId The room ID
 * @returns Current game state with all players
 */
export const getGameState = query({
  args: {
    roomId: v.id("rooms"),
  },
  handler: async (ctx, args) => {
    const { roomId } = args;
    
    const room = await ctx.db.get(roomId);
    if (!room) {
      return null;
    }

    const players = await ctx.db.query("players").withIndex("by_room", (q) => q.eq("roomId", roomId)).collect();

    // Sort players by score and highlight who is "it"
    const sortedPlayers = players.sort((a: any, b: any) => b.score - a.score);

    return {
      room,
      players: sortedPlayers,
      itPlayerId: players.find((p: any) => p.isIt)?._id,
      playerCount: players.length,
    };
  },
});

/**
 * Get recent tag events for a room (for scoring/history)
 * 
 * @param roomId The room ID
 * @param limit Maximum number of events to return
 * @returns Array of recent tag events
 */
export const getRecentTagEvents = query({
  args: {
    roomId: v.id("rooms"),
    limit: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const { roomId, limit = 10 } = args;
    
    const events = await ctx.db
      .query("tagEvents")
      .withIndex("by_room", (q) => q.eq("roomId", roomId))
      .order("desc")
      .take(limit);

    return events;
  },
});
