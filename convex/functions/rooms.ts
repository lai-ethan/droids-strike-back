/**
 * Room Management Functions for OMI Arena
 * 
 * Handles creation and lookup of game rooms with unique codes.
 */

import { v } from "convex/values";
import { mutation, query } from "./_generated/server";
import { generateRoomCode } from "../lib/tagLogic";

/**
 * Create a new game room with a unique code
 * 
 * @param creatorId ID of the player creating the room
 * @param roomName Optional human-readable name for the room
 * @param gameSettings Optional custom game settings
 * @returns The newly created room object
 */
export const createRoom = mutation({
  args: {
    creatorId: v.id("players"),
    roomName: v.optional(v.string()),
    gameSettings: v.optional(v.object({
      rssiThreshold: v.number(),
      tagCooldownMs: v.number(),
      immunityMs: v.number(),
    })),
  },
  handler: async (ctx, args) => {
    const { creatorId, roomName, gameSettings } = args;
    
    // Verify the creator exists
    const creator = await ctx.db.get(creatorId);
    if (!creator) {
      throw new Error("Creator player not found");
    }

    // Generate unique room code (retry if collision)
    let roomCode: string;
    let attempts = 0;
    const maxAttempts = 10;
    
    do {
      roomCode = generateRoomCode();
      const existing = await ctx.db
        .query("rooms")
        .withIndex("by_code", (q) => q.eq("code", roomCode))
        .first();
      
      if (!existing) break;
      attempts++;
    } while (attempts < maxAttempts);

    if (attempts >= maxAttempts) {
      throw new Error("Failed to generate unique room code");
    }

    // Use default settings if none provided
    const defaultSettings = {
      rssiThreshold: -65,  // dBm
      tagCooldownMs: 3000, // 3 seconds
      immunityMs: 2000,    // 2 seconds
    };

    const now = Date.now();
    const roomId = await ctx.db.insert("rooms", {
      code: roomCode,
      name: roomName,
      createdBy: creatorId,
      status: "waiting", // Room starts in waiting state
      gameSettings: gameSettings || defaultSettings,
      createdAt: now,
    });

    const room = await ctx.db.get(roomId);
    if (!room) {
      throw new Error("Failed to create room");
    }

    return room;
  },
});

/**
 * Look up a room by its unique code
 * 
 * @param code The 6-character room code
 * @returns The room object if found, null otherwise
 */
export const getRoomByCode = query({
  args: {
    code: v.string(),
  },
  handler: async (ctx, args) => {
    const { code } = args;
    
    const room = await ctx.db
      .query("rooms")
      .withIndex("by_code", (q) => q.eq("code", code))
      .first();

    return room || null;
  },
});

/**
 * Get a room by its ID
 * 
 * @param roomId The internal room ID
 * @returns The room object if found, null otherwise
 */
export const getRoomById = query({
  args: {
    roomId: v.id("rooms"),
  },
  handler: async (ctx, args) => {
    const { roomId } = args;
    
    const room = await ctx.db.get(roomId);
    return room || null;
  },
});

/**
 * Get all players in a room
 * 
 * @param roomId The room ID
 * @returns Array of player objects in the room
 */
export const getPlayersInRoom = query({
  args: {
    roomId: v.id("rooms"),
  },
  handler: async (ctx, args) => {
    const { roomId } = args;
    
    const players = await ctx.db
      .query("players")
      .withIndex("by_room", (q) => q.eq("roomId", roomId))
      .collect();

    return players;
  },
});

/**
 * Update room status (e.g., from waiting to in_progress)
 * 
 * @param roomId The room ID
 * @param status New status value
 * @returns The updated room object
 */
export const updateRoomStatus = mutation({
  args: {
    roomId: v.id("rooms"),
    status: v.string(), // "waiting", "in_progress", "finished"
  },
  handler: async (ctx, args) => {
    const { roomId, status } = args;
    
    const room = await ctx.db.get(roomId);
    if (!room) {
      throw new Error("Room not found");
    }

    const updateData = { status };
    
    // Set timestamps based on status
    const now = Date.now();
    if (status === "in_progress" && !room.startedAt) {
      updateData.startedAt = now;
    } else if (status === "finished" && !room.finishedAt) {
      updateData.finishedAt = now;
    }

    await ctx.db.patch(roomId, updateData);
    
    return await ctx.db.get(roomId);
  },
});

/**
 * Delete a room (cleanup after game ends)
 * 
 * @param roomId The room ID to delete
 * @returns True if successful
 */
export const deleteRoom = mutation({
  args: {
    roomId: v.id("rooms"),
  },
  handler: async (ctx, args) => {
    const { roomId } = args;
    
    // First, remove all players from the room
    const players = await ctx.db
      .query("players")
      .withIndex("by_room", (q) => q.eq("roomId", roomId))
      .collect();

    for (const player of players) {
      await ctx.db.patch(player._id, { roomId: undefined });
    }

    // Then delete the room
    await ctx.db.delete(roomId);
    
    return true;
  },
});
