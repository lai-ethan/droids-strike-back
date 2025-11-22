import { defineSchema, defineTable } from "convex/schema";
import { v } from "convex/values";

/**
 * Server-authoritative schema for OMI Arena.
 * Tag roles, proximity estimates, and scores live in Convex to prevent
 * client-side tampering while still flowing to the iOS app in real time.
 */
export default defineSchema({
  players: defineTable({
    roomId: v.id("rooms"),
    clientId: v.string(), // stable guest UUID per device
    name: v.string(),
    deviceId: v.optional(v.string()),
    isIt: v.boolean(),
    score: v.int64(),
    rssi: v.optional(v.number()),
    motion: v.optional(
      v.object({
        accel: v.object({ x: v.number(), y: v.number(), z: v.number() }),
        gyro: v.object({ x: v.number(), y: v.number(), z: v.number() }),
        velocity: v.optional(
          v.object({ x: v.number(), y: v.number(), z: v.number() })
        ),
      })
    ),
    estimatedPosition: v.optional(v.object({ x: v.number(), y: v.number() })),
    lastUpdate: v.number(), // ms epoch from server clock
    lastTaggedAt: v.optional(v.number()),
    immuneUntil: v.optional(v.number()),
    lastTagAttempt: v.optional(v.number()),
  })
    .index("byRoom", ["roomId"])
    .index("byRoomIsIt", ["roomId", "isIt"]),
  rooms: defineTable({
    code: v.string(),
    status: v.string(), // "lobby" | "running" | "finished"
    activeIt: v.optional(v.id("players")),
    createdAt: v.number(),
    immunityMs: v.optional(v.number()),
    minRssi: v.optional(v.number()),
  })
    .index("byCode", ["code"])
    .index("byStatus", ["status"]),
});
