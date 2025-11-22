/**
 * Tag Logic Utilities for OMI Arena
 * 
 * Contains core game logic for validating tag attempts,
 * calculating distances from RSSI, and managing game state.
 */

import { v } from "convex/values";

// Game constants - these can be tuned based on testing
export const GAME_CONSTANTS = {
  // RSSI threshold for valid tags (lower = closer, -65 is ~2-3 meters)
  RSSI_THRESHOLD: -65,
  
  // Cooldown between tag attempts to prevent spam (milliseconds)
  TAG_COOLDOWN_MS: 3000,
  
  // Immunity period after being tagged (milliseconds)
  TAG_IMMUNITY_MS: 2000,
  
  // RSSI to distance estimation (simplified path loss model)
  // Distance = 10^((TX_POWER - RSSI) / (10 * N))
  // where TX_POWER is RSSI at 1 meter, N is path loss exponent
  TX_POWER_AT_1M: -59, // Typical for BLE devices
  PATH_LOSS_EXPONENT: 2.0, // Free space propagation
};

/**
 * Estimate distance from RSSI using simplified path loss model
 * 
 * @param rssi Signal strength in dBm
 * @returns Estimated distance in meters
 */
export function estimateDistanceFromRssi(rssi: number): number {
  const { TX_POWER_AT_1M, PATH_LOSS_EXPONENT } = GAME_CONSTANTS;
  
  // Path loss formula: distance = 10^((txPower - rssi) / (10 * pathLoss))
  const distance = Math.pow(
    10, 
    (TX_POWER_AT_1M - rssi) / (10 * PATH_LOSS_EXPONENT)
  );
  
  return Math.max(0, distance); // Ensure non-negative
}

/**
 * Check if a player can attempt to tag based on cooldown
 * 
 * @param lastTagAttemptAt Timestamp of last tag attempt
 * @param currentTime Current timestamp
 * @returns True if cooldown has expired
 */
export function canAttemptTag(
  lastTagAttemptAt: number | undefined, 
  currentTime: number
): boolean {
  if (!lastTagAttemptAt) return true;
  
  const timeSinceLastAttempt = currentTime - lastTagAttemptAt;
  return timeSinceLastAttempt >= GAME_CONSTANTS.TAG_COOLDOWN_MS;
}

/**
 * Check if a player has immunity from being tagged
 * 
 * @param lastTaggedAt Timestamp when player was last tagged
 * @param currentTime Current timestamp
 * @returns True if player has immunity
 */
export function hasImmunity(
  lastTaggedAt: number | undefined, 
  currentTime: number
): boolean {
  if (!lastTaggedAt) return false;
  
  const timeSinceTagged = currentTime - lastTaggedAt;
  return timeSinceTagged < GAME_CONSTANTS.TAG_IMMUNITY_MS;
}

/**
 * Validate if a tag attempt is successful
 * 
 * @param attackerRssi RSSI of attacker device
 * @param defenderRssi RSSI of defender device  
 * @param attackerLastTagAttempt When attacker last attempted a tag
 * @param defenderLastTagged When defender was last tagged
 * @param currentTime Current timestamp
 * @returns Object with validation result and reason
 */
export function validateTagAttempt({
  attackerRssi,
  defenderRssi,
  attackerLastTagAttempt,
  defenderLastTagged,
  currentTime,
}: {
  attackerRssi: number | undefined;
  defenderRssi: number | undefined;
  attackerLastTagAttempt: number | undefined;
  defenderLastTagged: number | undefined;
  currentTime: number;
}): {
  success: boolean;
  reason?: string;
  distance?: number;
} {
  // Check if we have RSSI data for both players
  if (!attackerRssi || !defenderRssi) {
    return {
      success: false,
      reason: "missing_rssi_data",
    };
  }

  // Check attacker cooldown
  if (!canAttemptTag(attackerLastTagAttempt, currentTime)) {
    return {
      success: false,
      reason: "attacker_cooldown",
    };
  }

  // Check defender immunity
  if (hasImmunity(defenderLastTagged, currentTime)) {
    return {
      success: false,
      reason: "defender_immunity",
    };
  }

  // Calculate distance using average RSSI (more accurate than single direction)
  const averageRssi = (attackerRssi + defenderRssi) / 2;
  const distance = estimateDistanceFromRssi(averageRssi);

  // Check if players are close enough
  if (averageRssi < GAME_CONSTANTS.RSSI_THRESHOLD) {
    return {
      success: false,
      reason: "too_far",
      distance,
    };
  }

  // All checks passed - tag is valid!
  return {
    success: true,
    distance,
  };
}

/**
 * Determine who should be "it" after a successful tag
 * 
 * @param currentAttackerId Player who made the tag
 * @param currentDefenderId Player who was tagged
 * @param currentItPlayerId Player who is currently "it"
 * @returns New "it" player ID
 */
export function updateItStatus(
  currentAttackerId: string,
  currentDefenderId: string,
  currentItPlayerId: string
): string {
  // If attacker is currently "it", they pass it to defender
  if (currentItPlayerId === currentAttackerId) {
    return currentDefenderId;
  }
  
  // If defender is currently "it", attacker takes it
  if (currentItPlayerId === currentDefenderId) {
    return currentAttackerId;
  }
  
  // If neither is "it" (edge case), attacker becomes "it"
  return currentAttackerId;
}

/**
 * Generate a random room code
 * 
 * @returns 6-character alphanumeric room code
 */
export function generateRoomCode(): string {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let code = '';
  for (let i = 0; i < 6; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return code;
}
