//
//  AppState.swift
//  OMI Arena - Global state management for the app
//
//  This class manages the entire application state including:
//  - Current player and room
//  - Bluetooth connection status
//  - Real-time game updates
//  - Error handling
//

import Foundation
import SwiftUI
import Combine

/// Global state container for OMI Arena
/// Uses ObservableObject to provide reactive updates to SwiftUI views
@MainActor
class AppState: ObservableObject {
    // MARK: - Core Services
    let bluetoothManager = OMIBluetoothManager()
    let convexClient = ConvexClient()
    
    // MARK: - App State
    @Published var isLoading: Bool = true
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""
    
    // MARK: - Player State
    @Published var currentPlayer: PlayerModel?
    @Published var currentRoom: RoomModel?
    @Published var playersInRoom: [PlayerModel] = []
    
    // MARK: - Game State
    @Published var gameState: GameState?
    @Published var isItPlayer: Bool = false
    @Published var recentTagEvents: [TagEvent] = []
    
    // MARK: - Device State
    @Published var isBluetoothConnected: Bool = false
    @Published var connectedDeviceName: String?
    @Published var currentMotion: MotionData?
    @Published var currentRssi: Int?
    
    // MARK: - UI State
    @Published var showDebugView: Bool = false
    @Published var selectedTargetPlayer: PlayerModel?
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var gameStateTimer: Timer?
    
    init() {
        setupBindings()
    }
    
    // MARK: - Setup
    
    /// Set up reactive bindings between services and app state
    private func setupBindings() {
        // Monitor Bluetooth connection state
        bluetoothManager.$isConnected
            .receive(on: DispatchQueue.main)
            .assign(to: \.isBluetoothConnected, on: self)
            .store(in: &cancellables)
        
        bluetoothManager.$connectedDeviceName
            .receive(on: DispatchQueue.main)
            .assign(to: \.connectedDeviceName, on: self)
            .store(in: &cancellables)
        
        // Monitor device data
        bluetoothManager.$currentMotion
            .receive(on: DispatchQueue.main)
            .assign(to: \.currentMotion, on: self)
            .store(in: &cancellables)
        
        bluetoothManager.$currentRssi
            .receive(on: DispatchQueue.main)
            .assign(to: \.currentRssi, on: self)
            .store(in: &cancellables)
        
        // Monitor Convex connection state
        convexClient.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                if isConnected {
                    self?.finishLoading()
                }
            }
            .store(in: &cancellables)
        
        // Monitor errors from both services
        bluetoothManager.$errorMessage
            .compactMap { $0 }
            .sink { [weak self] error in
                self?.showError(error)
            }
            .store(in: &cancellables)
        
        convexClient.$errorMessage
            .compactMap { $0 }
            .sink { [weak self] error in
                self?.showError(error)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Player Management
    
    /// Create or get current player
    func createOrGetPlayer(name: String, deviceId: String? = nil) async throws {
        do {
            let player = try await convexClient.createPlayer(
                name: name,
                deviceId: deviceId
            )
            
            await MainActor.run {
                self.currentPlayer = player
            }
        } catch {
            showError("Failed to create player: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Update current player's device information
    func updatePlayerDevice(deviceId: String, deviceName: String) async {
        guard let player = currentPlayer else { return }
        
        do {
            let updatedPlayer = try await convexClient.updatePlayerDevice(
                playerId: player.id,
                deviceId: deviceId,
                deviceName: deviceName
            )
            
            await MainActor.run {
                self.currentPlayer = updatedPlayer
            }
        } catch {
            showError("Failed to update device: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Room Management
    
    /// Join a room by code
    func joinRoom(roomCode: String) async {
        guard let player = currentPlayer else {
            showError("No player found")
            return
        }
        
        do {
            let result = try await convexClient.joinRoom(
                playerId: player.id,
                roomCode: roomCode
            )
            
            await MainActor.run {
                self.currentRoom = result.room
                self.currentPlayer = result.player
                self.startGameStateUpdates()
            }
        } catch {
            showError("Failed to join room: \(error.localizedDescription)")
        }
    }
    
    /// Create a new room
    func createRoom(roomName: String? = nil) async {
        guard let player = currentPlayer else {
            showError("No player found")
            return
        }
        
        do {
            let room = try await convexClient.createRoom(
                creatorId: player.id,
                roomName: roomName
            )
            
            await MainActor.run {
                self.currentRoom = room
                self.startGameStateUpdates()
            }
        } catch {
            showError("Failed to create room: \(error.localizedDescription)")
        }
    }
    
    /// Leave current room
    func leaveRoom() async {
        guard let player = currentPlayer else { return }
        
        do {
            let updatedPlayer = try await convexClient.leaveRoom(playerId: player.id)
            
            await MainActor.run {
                self.currentPlayer = updatedPlayer
                self.currentRoom = nil
                self.gameState = nil
                self.playersInRoom = []
                self.stopGameStateUpdates()
            }
        } catch {
            showError("Failed to leave room: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Game Actions
    
    /// Start the game in current room
    func startGame() async {
        guard let room = currentRoom else {
            showError("No room found")
            return
        }
        
        do {
            _ = try await convexClient.startGame(roomId: room.id)
        } catch {
            showError("Failed to start game: \(error.localizedDescription)")
        }
    }
    
    /// Attempt to tag another player
    func attemptTag(targetPlayer: PlayerModel) async {
        guard let attacker = currentPlayer else {
            showError("No player found")
            return
        }
        
        do {
            let result = try await convexClient.attemptTag(
                attackerId: attacker.id,
                defenderId: targetPlayer.id
            )
            
            await MainActor.run {
                if result.success {
                    // Tag was successful - game state will update via subscription
                    print("✅ Tag successful!")
                } else {
                    // Tag failed - show reason
                    let reason = result.reason ?? "Unknown reason"
                    print("❌ Tag failed: \(reason)")
                }
            }
        } catch {
            showError("Tag attempt failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Device Data Updates
    
    /// Send motion data to server
    func sendMotionData(_ motion: MotionData) async {
        guard let player = currentPlayer, player.roomId != nil else { return }
        
        do {
            _ = try await convexClient.updateMotion(
                playerId: player.id,
                motion: motion
            )
        } catch {
            print("Failed to update motion: \(error)")
        }
    }
    
    /// Send RSSI data to server
    func sendRssiData(_ rssi: Int) async {
        guard let player = currentPlayer, player.roomId != nil else { return }
        
        do {
            _ = try await convexClient.updateRssi(
                playerId: player.id,
                rssi: rssi
            )
        } catch {
            print("Failed to update RSSI: \(error)")
        }
    }
    
    // MARK: - Game State Updates
    
    /// Start real-time game state updates
    private func startGameStateUpdates() {
        guard let room = currentRoom else { return }
        
        // Set up subscription for game state
        Task {
            // Subscribe to game state changes
            for await gameState in convexClient.subscribeToGameState(roomId: room.id) {
                await MainActor.run {
                    self.updateGameState(gameState)
                }
            }
        }
        
        // Start periodic updates for device data
        startDeviceDataUpdates()
    }
    
    /// Stop game state updates
    private func stopGameStateUpdates() {
        gameStateTimer?.invalidate()
        gameStateTimer = nil
    }
    
    /// Update local game state from server
    private func updateGameState(_ newState: GameState) {
        self.gameState = newState
        self.playersInRoom = newState.players
        self.isItPlayer = newState.itPlayerId == currentPlayer?.id
        
        // Load recent tag events
        Task {
            do {
                let events = try await convexClient.getRecentTagEvents(
                    roomId: newState.id,
                    limit: 10
                )
                await MainActor.run {
                    self.recentTagEvents = events
                }
            } catch {
                print("Failed to load tag events: \(error)")
            }
        }
    }
    
    /// Start periodic device data updates
    private func startDeviceDataUpdates() {
        gameStateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                
                // Send motion data if available
                if let motion = self.currentMotion {
                    await self.sendMotionData(motion)
                }
                
                // Send RSSI data if available
                if let rssi = self.currentRssi {
                    await self.sendRssiData(rssi)
                }
            }
        }
    }
    
    // MARK: - Error Handling
    
    /// Show an error message
    func showError(_ message: String) {
        errorMessage = message
        showError = true
    }
    
    /// Clear current error
    func clearError() {
        errorMessage = ""
        showError = false
    }
    
    // MARK: - Loading State
    
    /// Finish app initialization
    private func finishLoading() {
        isLoading = false
    }
    
    /// Reset app state (for testing/debug)
    func resetState() {
        currentPlayer = nil
        currentRoom = nil
        gameState = nil
        playersInRoom = []
        recentTagEvents = []
        selectedTargetPlayer = nil
        stopGameStateUpdates()
    }
}

// MARK: - Computed Properties

extension AppState {
    /// Check if current player can attempt to tag
    var canAttemptTag: Bool {
        guard let player = currentPlayer else { return false }
        return player.canAttemptTag && currentRoom?.status == .inProgress
    }
    
    /// Get nearby players (in same room)
    var nearbyPlayers: [PlayerModel] {
        return playersInRoom.filter { $0.id != currentPlayer?.id }
    }
    
    /// Get players that can be tagged (close enough and not immune)
    var taggablePlayers: [PlayerModel] {
        return nearbyPlayers.filter { player in
            // Check distance (using RSSI threshold)
            guard let rssi = player.rssi else { return false }
            
            // Check if player is close enough (-65 dBm threshold)
            let isCloseEnough = rssi >= -65
            
            // Check if player is not immune
            let notImmune = player.canBeTagged
            
            return isCloseEnough && notImmune
        }
    }
    
    /// Current game status description
    var gameStatusDescription: String {
        guard let room = currentRoom else {
            return "Not in a room"
        }
        
        switch room.status {
        case .waiting:
            return "Waiting for game to start"
        case .inProgress:
            if isItPlayer {
                return "You are IT! Tag someone!"
            } else {
                guard let itPlayer = playersInRoom.first(where: { $0.isIt }) else {
                    return "Game in progress"
                }
                return "Run from \(itPlayer.name)!"
            }
        case .finished:
            return "Game finished"
        }
    }
}
