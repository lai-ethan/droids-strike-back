//
//  GameView.swift
//  OMI Arena - Main game interface for active gameplay
//
//  Shows real-time player positions, tag button, and game status
//

import SwiftUI

struct GameView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingTagConfirmation = false
    @State private var selectedTarget: PlayerModel?
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Game header
                gameHeaderView
                
                // Main game area
                if appState.currentRoom?.status == .inProgress {
                    gameAreaView
                } else {
                    waitingAreaView
                }
                
                // Bottom controls
                bottomControlsView
            }
        }
        .background(Color(.systemBackground))
        .alert("Tag Attempt", isPresented: $showingTagConfirmation) {
            Button("Tag!", role: .destructive) {
                if let target = selectedTarget {
                    attemptTag(target)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if let target = selectedTarget {
                Text("Tag \(target.name)?")
            }
        }
    }
    
    // MARK: - Game Header
    
    private var gameHeaderView: some View {
        VStack(spacing: 8) {
            HStack {
                // Room info
                VStack(alignment: .leading, spacing: 2) {
                    Text("Room \(appState.currentRoom?.code ?? "")")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text(appState.gameStatusDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Player status
                if appState.isItPlayer {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("🏃 YOU ARE IT!")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                        
                        Text("Tag someone!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Score: \(appState.currentPlayer?.score ?? 0)")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Text("Run from IT!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Connection status
            deviceConnectionBar
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    // MARK: - Device Connection Bar
    
    private var deviceConnectionBar: some View {
        HStack {
            HStack(spacing: 4) {
                Circle()
                    .fill(appState.isBluetoothConnected ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                
                Text(appState.isBluetoothConnected ? "Device Connected" : "Using Mock Data")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let rssi = appState.currentRssi {
                HStack(spacing: 4) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.caption)
                    Text("\(rssi) dBm")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Game Area
    
    private var gameAreaView: some View {
        GeometryReader { geometry in
            ZStack {
                // Background grid/map
                mapView(size: geometry.size)
                
                // Players
                playerNodesView(size: geometry.size)
                
                // Distance indicators
                if appState.isItPlayer {
                    distanceRingsView(size: geometry.size)
                }
            }
        }
        .clipped()
    }
    
    // MARK: - Waiting Area
    
    private var waitingAreaView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Text("Waiting for game to start...")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text("Players in room: \(appState.playersInRoom.count)")
                .font(.subheadline)
            
            if appState.playersInRoom.count < 2 {
                Text("Need at least 2 players to start")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            // Player list
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(appState.playersInRoom) { player in
                        PlayerRowView(player: player)
                    }
                }
                .padding()
            }
            .frame(maxHeight: 300)
            
            Spacer()
        }
    }
    
    // MARK: - Bottom Controls
    
    private var bottomControlsView: some View {
        VStack(spacing: 16) {
            // Tag button (only for "it" player)
            if appState.isItPlayer && appState.currentRoom?.status == .inProgress {
                tagButtonView
            }
            
            // Action buttons
            HStack(spacing: 12) {
                // Leave game button
                Button(action: leaveGame) {
                    HStack {
                        Text("🚪")
                        Text("Leave Game")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                
                // Debug button
                Button(action: { appState.showDebugView = true }) {
                    HStack {
                        Text("🔧")
                        Text("Debug")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    // MARK: - Tag Button
    
    private var tagButtonView: some View {
        Button(action: showTagOptions) {
            VStack(spacing: 4) {
                Text("TAG!")
                    .font(.title)
                    .fontWeight(.bold)
                
                if let taggableCount = appState.taggablePlayers.count {
                    Text("\(taggableCount) players in range")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                appState.canAttemptTag ? Color.red : Color.gray
            )
            .foregroundColor(.white)
            .cornerRadius(15)
            .scaleEffect(appState.canAttemptTag ? 1.0 : 0.95)
            .animation(.easeInOut(duration: 0.2), value: appState.canAttemptTag)
        }
        .disabled(!appState.canAttemptTag)
    }
    
    // MARK: - Map View
    
    private func mapView(size: CGSize) -> some View {
        ZStack {
            // Background
            Color(.systemGray5)
            
            // Grid lines
            Path { path in
                let gridSize: CGFloat = 50
                
                // Vertical lines
                for x in stride(from: 0, through: size.width, by: gridSize) {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                }
                
                // Horizontal lines
                for y in stride(from: 0, through: size.height, by: gridSize) {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }
            }
            .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
        }
    }
    
    // MARK: - Player Nodes
    
    private func playerNodesView(size: CGSize) -> some View {
        ZStack {
            ForEach(appState.playersInRoom) { player in
                PlayerNodeView(
                    player: player,
                    position: calculatePlayerPosition(player, in: size),
                    isCurrentPlayer: player.id == appState.currentPlayer?.id,
                    isTarget: player.id == appState.selectedTargetPlayer?.id,
                    canBeTagged: appState.isItPlayer && appState.taggablePlayers.contains(player)
                )
                .onTapGesture {
                    if appState.isItPlayer && appState.taggablePlayers.contains(player) {
                        selectedTarget = player
                        showingTagConfirmation = true
                    }
                }
            }
        }
    }
    
    // MARK: - Distance Rings
    
    private func distanceRingsView(size: CGSize) -> some View {
        ZStack {
            // Show distance rings around current player
            if let currentPlayer = appState.currentPlayer {
                let center = calculatePlayerPosition(currentPlayer, in: size)
                
                // RSSI threshold ring (-65 dBm = ~2-3 meters)
                Circle()
                    .stroke(Color.red.opacity(0.3), lineWidth: 2)
                    .frame(width: 150, height: 150)
                    .position(center)
                
                // Close range ring (-55 dBm = ~1 meter)
                Circle()
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    .frame(width: 100, height: 100)
                    .position(center)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func calculatePlayerPosition(_ player: PlayerModel, in size: CGSize) -> CGPoint {
        // Simple positioning based on RSSI distance estimation
        // In a real implementation, this would use actual positioning data
        
        guard let distance = player.distanceEstimate else {
            // Random position if no distance data
            return CGPoint(
                x: CGFloat.random(in: 50...size.width - 50),
                y: CGFloat.random(in: 50...size.height - 50)
            )
        }
        
        // Position players in a circle based on distance from current player
        guard let currentPlayer = appState.currentPlayer else {
            return CGPoint(x: size.width / 2, y: size.height / 2)
        }
        
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        
        // Current player at center
        if player.id == currentPlayer.id {
            return center
        }
        
        // Other players positioned based on estimated distance
        let maxDistance: Double = 10.0 // Maximum expected distance in meters
        let normalizedDistance = min(distance / maxDistance, 1.0)
        let radius = normalizedDistance * min(size.width, size.height) * 0.4
        
        // Use player ID to determine angle (consistent positioning)
        let hash = abs(player.id.hashValue)
        let angle = Double(hash) * .pi / 4.0
        
        let x = center.x + CGFloat(cos(angle) * radius)
        let y = center.y + CGFloat(sin(angle) * radius)
        
        return CGPoint(x: x, y: y)
    }
    
    private func showTagOptions() {
        let taggablePlayers = appState.taggablePlayers
        
        if taggablePlayers.isEmpty {
            appState.showError("No players in range to tag!")
            return
        }
        
        if taggablePlayers.count == 1 {
            // Auto-tag if only one player in range
            selectedTarget = taggablePlayers.first
            showingTagConfirmation = true
        } else {
            // Show multiple options (could be enhanced with a better UI)
            selectedTarget = taggablePlayers.first
            showingTagConfirmation = true
        }
    }
    
    private func attemptTag(_ target: PlayerModel) {
        Task {
            await appState.attemptTag(targetPlayer: target)
        }
    }
    
    private func leaveGame() {
        Task {
            await appState.leaveRoom()
        }
    }
}

// MARK: - Player Node View

struct PlayerNodeView: View {
    let player: PlayerModel
    let position: CGPoint
    let isCurrentPlayer: Bool
    let isTarget: Bool
    let canBeTagged: Bool
    
    var body: some View {
        ZStack {
            // Outer ring for "it" player
            if player.isIt {
                Circle()
                    .stroke(Color.red, lineWidth: 3)
                    .frame(width: 50, height: 50)
            }
            
            // Target indicator
            if isTarget {
                Circle()
                    .stroke(Color.yellow, lineWidth: 2)
                    .frame(width: 45, height: 45)
            }
            
            // Player circle
            Circle()
                .fill(
                    isCurrentPlayer ? Color.blue :
                    canBeTagged ? Color.green :
                    player.isConnected ? Color.primary : Color.gray
                )
                .frame(width: 35, height: 35)
            
            // Player icon/text
            VStack(spacing: 0) {
                if player.isIt {
                    Text("🏃")
                        .font(.title3)
                } else {
                    Text(String(player.name.prefix(1)))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                if !player.isConnected {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 6, height: 6)
                        .offset(y: -2)
                }
            }
        }
        .position(position)
        .scaleEffect(isTarget ? 1.2 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isTarget)
        .shadow(radius: 2)
    }
}

#Preview {
    GameView()
        .environmentObject(AppState())
}
