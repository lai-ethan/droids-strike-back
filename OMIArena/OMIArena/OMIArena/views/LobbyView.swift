//
//  LobbyView.swift
//  OMI Arena - Main lobby and room management interface
//
//  Handles room creation, joining, and displays current room status
//

import SwiftUI

struct LobbyView: View {
    @EnvironmentObject var appState: AppState
    @State private var roomCode: String = ""
    @State private var playerName: String = ""
    @State private var roomName: String = ""
    @State private var isCreatingRoom: Bool = false
    @State private var showDeviceScanner: Bool = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Debug: Test conditional logic
                if appState.currentPlayer == nil {
                    Text("SHOWING PLAYER SETUP")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                        .padding()
                } else {
                    Text("PLAYER EXISTS - SHOW ROOM VIEW")
                        .font(.largeTitle)
                        .foregroundColor(.blue)
                        .padding()
                }
                
                Text("Current Player: \(appState.currentPlayer?.name ?? "NONE")")
                    .foregroundColor(.green)
            }
            .padding()
            .navigationTitle("OMI Arena")
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(spacing: 10) {
            Text("🎮")
                .font(.system(size: 60))
            
            Text("OMI Arena")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Real-time multiplayer tag game")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Player Setup View
    
    private var playerSetupView: some View {
        VStack(spacing: 20) {
            Text("Join the Game")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Your Name")
                    .font(.headline)
                
                TextField("Enter your name", text: $playerName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.words)
            }
            
            Button(action: createPlayer) {
                HStack {
                    if appState.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Text("Start Playing")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(playerName.isEmpty || appState.isLoading)
            
            // Device connection status
            deviceStatusView
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(15)
    }
    
    // MARK: - Room Join/Create View
    
    private var roomJoinCreateView: some View {
        VStack(spacing: 20) {
            Text("Join or Create a Room")
                .font(.title2)
                .fontWeight(.semibold)
            
            // Join existing room
            VStack(alignment: .leading, spacing: 8) {
                Text("Room Code")
                    .font(.headline)
                
                TextField("Enter 6-character code", text: $roomCode)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textCase(.uppercase)
                    .keyboardType(.alphabet)
                    .onChange(of: roomCode) {
                        // Limit to 6 characters and uppercase
                        roomCode = String(roomCode.prefix(6)).uppercased()
                    }
            }
            
            Button(action: joinRoom) {
                HStack {
                    if appState.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Text("Join Room")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(roomCode.count != 6 || appState.isLoading)
            
            Divider()
            
            // Create new room
            VStack(alignment: .leading, spacing: 8) {
                Text("Room Name (Optional)")
                    .font(.headline)
                
                TextField("Enter room name", text: $roomName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            Button(action: { isCreatingRoom = true }) {
                HStack {
                    Text("🏠")
                    Text("Create New Room")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(appState.isLoading)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(15)
        .confirmationDialog("Create Room", isPresented: $isCreatingRoom) {
            Button("Create Room", action: createRoom)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Create a new room with code: \(generateRoomCode())")
        }
    }
    
    // MARK: - Current Room View
    
    private var currentRoomView: some View {
        VStack(spacing: 20) {
            // Room info
            VStack(spacing: 10) {
                Text("Current Room")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                VStack(spacing: 5) {
                    Text("Code: \(appState.currentRoom?.code ?? "")")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    if let roomName = appState.currentRoom?.name {
                        Text(roomName)
                            .font(.headline)
                    }
                    
                    Text("Status: \(appState.currentRoom?.status.displayName ?? "")")
                        .font(.subheadline)
                        .foregroundColor(statusColor)
                }
            }
            
            // Players in room
            if !appState.playersInRoom.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Players (\(appState.playersInRoom.count))")
                        .font(.headline)
                    
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(appState.playersInRoom) { player in
                                PlayerRowView(player: player)
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
            }
            
            // Room actions
            VStack(spacing: 10) {
                if appState.currentRoom?.status == .waiting {
                    Button(action: startGame) {
                        HStack {
                            Text("🎮")
                            Text("Start Game")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(appState.playersInRoom.count < 2 || appState.isLoading)
                }
                
                Button(action: leaveRoom) {
                    HStack {
                        Text("🚪")
                        Text("Leave Room")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(appState.isLoading)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(15)
    }
    
    // MARK: - Device Status View
    
    private var deviceStatusView: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Device Status:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if appState.isBluetoothConnected {
                    HStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("Connected")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                } else {
                    HStack {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 8, height: 8)
                        Text("Mock Data")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            if let deviceName = appState.connectedDeviceName {
                Text(deviceName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Button("Scan for Devices") {
                showDeviceScanner = true
            }
            .font(.caption)
            .foregroundColor(.blue)
        }
    }
    
    // MARK: - Debug Button
    
    private var debugButton: some View {
        Button(action: { appState.showDebugView = true }) {
            HStack {
                Text("🔧")
                Text("Debug View")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Computed Properties
    
    private var statusColor: Color {
        switch appState.currentRoom?.status {
        case .waiting:
            return .orange
        case .inProgress:
            return .green
        case .finished:
            return .gray
        case .none:
            return .secondary
        }
    }
    
    // MARK: - Actions
    
    private func createPlayer() {
        Task {
            do {
                try await appState.createOrGetPlayer(name: playerName)
            } catch {
                print("Failed to create player: \(error)")
            }
        }
    }
    
    private func joinRoom() {
        Task {
            await appState.joinRoom(roomCode: roomCode)
        }
    }
    
    private func createRoom() {
        Task {
            await appState.createRoom(roomName: roomName.isEmpty ? nil : roomName)
        }
    }
    
    private func startGame() {
        Task {
            await appState.startGame()
        }
    }
    
    private func leaveRoom() {
        Task {
            await appState.leaveRoom()
        }
    }
}

// MARK: - Player Row View

struct PlayerRowView: View {
    let player: PlayerModel
    
    var body: some View {
        HStack {
            // Player info
            VStack(alignment: .leading, spacing: 2) {
                Text(player.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    if player.isIt {
                        Text("🏃 IT")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                    
                    if player.isConnected {
                        HStack {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text("Online")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    } else {
                        HStack {
                            Circle()
                                .fill(Color.gray)
                                .frame(width: 6, height: 6)
                            Text("Offline")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Score
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(player.score)")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Text("points")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Device Scanner View

struct DeviceScannerView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                if appState.bluetoothManager.isScanning {
                    VStack(spacing: 10) {
                        ProgressView()
                        Text("Scanning for OMI devices...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                
                if appState.bluetoothManager.discoveredDevices.isEmpty {
                    Text("No devices found")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    List(appState.bluetoothManager.discoveredDevices) { device in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(device.name)
                                    .font(.headline)
                                Text("RSSI: \(device.rssi) dBm")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button("Connect") {
                                appState.bluetoothManager.connect(to: device)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            .navigationTitle("Scan Devices")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        appState.bluetoothManager.stopScanning()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(appState.bluetoothManager.isScanning ? "Stop" : "Scan") {
                        if appState.bluetoothManager.isScanning {
                            appState.bluetoothManager.stopScanning()
                        } else {
                            appState.bluetoothManager.startScanning()
                        }
                    }
                }
            }
            .onAppear {
                appState.bluetoothManager.startScanning()
            }
            .onDisappear {
                appState.bluetoothManager.stopScanning()
            }
        }
    }
}

#Preview {
    LobbyView()
        .environmentObject(AppState())
}
