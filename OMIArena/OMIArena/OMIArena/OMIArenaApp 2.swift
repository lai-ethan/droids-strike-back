//
//  OMIArenaApp.swift
//  OMI Arena - Real-time multiplayer tag game using OMI wearables
//
//  Created for hackathon project
//

import SwiftUI

@main
struct OMIArenaApp: App {
    // Global app state that manages the entire application
    @StateObject private var appState = AppState()
    
    // Body of the app - sets up the root view and environment objects
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onAppear {
                    // Initialize app services when app launches
                    setupApp()
                }
        }
    }
    
    // Initialize core services and perform startup tasks
    private func setupApp() {
        print("🎮 OMI Arena starting up...")
        
        // Initialize Bluetooth manager
        appState.bluetoothManager.initialize()
        
        // Initialize Convex client
        appState.convexClient.initialize()
        
        print("✅ App initialization complete")
    }
}

// Root view that determines which screen to show
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Group {
            // Show loading screen while initializing
            if appState.isLoading {
                LoadingView()
            }
            // Show lobby if not in a game
            else if appState.currentRoom == nil {
                LobbyView()
            }
            // Show game view when in a room
            else {
                GameView()
            }
        }
        .alert("Error", isPresented: $appState.showError) {
            Button("OK") {
                appState.clearError()
            }
        } message: {
            Text(appState.errorMessage)
        }
    }
}

// Simple loading view for app startup
struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("OMI Arena")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Initializing...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview {
    OMIArenaApp()
}
