//
//  DeviceDebugView.swift
//  OMI Arena - Debug interface for BLE and device data
//
//  Shows real-time device metrics, connection status, and raw data
//

import SwiftUI

struct DeviceDebugView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Connection Status
                    connectionStatusCard
                    
                    // Device Info
                    deviceInfoCard
                    
                    // Real-time Data
                    realtimeDataCard
                    
                    // Motion Data
                    motionDataCard
                    
                    // RSSI Data
                    rssiDataCard
                    
                    // Battery Info
                    batteryInfoCard
                    
                    // Error Log
                    errorLogCard
                    
                    // Actions
                    actionsCard
                }
                .padding()
            }
            .navigationTitle("Device Debug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Connection Status Card
    
    private var connectionStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connection Status")
                .font(.headline)
                .fontWeight(.bold)
            
            VStack(spacing: 8) {
                HStack {
                    Circle()
                        .fill(appState.isBluetoothConnected ? Color.green : Color.orange)
                        .frame(width: 12, height: 12)
                    
                    Text(appState.isBluetoothConnected ? "Connected" : "Mock Data")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    if appState.bluetoothManager.isScanning {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Scanning...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if let deviceName = appState.connectedDeviceName {
                    HStack {
                        Text("Device:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(deviceName)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Device Info Card
    
    private var deviceInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Device Information")
                .font(.headline)
                .fontWeight(.bold)
            
            VStack(spacing: 8) {
                DebugRow(label: "Device ID", value: appState.currentPlayer?.deviceId ?? "Unknown")
                DebugRow(label: "Device Name", value: appState.connectedDeviceName ?? "Unknown")
                DebugRow(label: "Player ID", value: appState.currentPlayer?.id ?? "Unknown")
                DebugRow(label: "Room ID", value: appState.currentRoom?.id ?? "None")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Real-time Data Card
    
    private var realtimeDataCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Real-time Data")
                .font(.headline)
                .fontWeight(.bold)
            
            VStack(spacing: 8) {
                HStack {
                    Text("Last Update:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(lastUpdateTime)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Data Rate:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("10 Hz")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Using Mock:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(appState.isBluetoothConnected ? "No" : "Yes")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(appState.isBluetoothConnected ? .green : .orange)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Motion Data Card
    
    private var motionDataCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Motion Data")
                .font(.headline)
                .fontWeight(.bold)
            
            if let motion = appState.currentMotion {
                VStack(spacing: 8) {
                    // Acceleration values
                    DebugRow(label: "AX (X-axis)", value: String(format: "%.3f m/s²", motion.ax))
                    DebugRow(label: "AY (Y-axis)", value: String(format: "%.3f m/s²", motion.ay))
                    DebugRow(label: "AZ (Z-axis)", value: String(format: "%.3f m/s²", motion.az))
                    
                    Divider()
                    
                    // Computed values
                    DebugRow(label: "Magnitude", value: String(format: "%.3f m/s²", motion.magnitude))
                    DebugRow(label: "Is Moving", value: motion.isMoving ? "Yes" : "No")
                    
                    // Motion indicator
                    MotionIndicatorView(motion: motion)
                }
            } else {
                Text("No motion data available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - RSSI Data Card
    
    private var rssiDataCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RSSI Data")
                .font(.headline)
                .fontWeight(.bold)
            
            if let rssi = appState.currentRssi {
                VStack(spacing: 8) {
                    DebugRow(label: "RSSI", value: "\(rssi) dBm")
                    DebugRow(label: "Distance Est.", value: String(format: "%.2f meters", estimateDistance(from: rssi)))
                    DebugRow(label: "Signal Quality", value: signalQuality(rssi))
                    
                    // RSSI indicator
                    RSSIIndicatorView(rssi: rssi)
                }
            } else {
                Text("No RSSI data available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Battery Info Card
    
    private var batteryInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Battery Information")
                .font(.headline)
                .fontWeight(.bold)
            
            if let batteryLevel = appState.bluetoothManager.batteryLevel {
                VStack(spacing: 8) {
                    DebugRow(label: "Battery Level", value: "\(batteryLevel)%")
                    
                    // Battery indicator
                    BatteryIndicatorView(level: batteryLevel)
                }
            } else {
                Text("Battery data not available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Error Log Card
    
    private var errorLogCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Error Log")
                .font(.headline)
                .fontWeight(.bold)
            
            if !appState.errorMessage.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(appState.errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    
                    Button("Clear Error") {
                        appState.clearError()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            } else {
                Text("No errors")
                    .font(.subheadline)
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Actions Card
    
    private var actionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Debug Actions")
                .font(.headline)
                .fontWeight(.bold)
            
            VStack(spacing: 8) {
                Button(action: { appState.bluetoothManager.startScanning() }) {
                    HStack {
                        Text("🔍")
                        Text("Start Scanning")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                Button(action: { appState.bluetoothManager.stopScanning() }) {
                    HStack {
                        Text("⏹️")
                        Text("Stop Scanning")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                if appState.isBluetoothConnected {
                    Button(action: { appState.bluetoothManager.disconnect() }) {
                        HStack {
                            Text("🔌")
                            Text("Disconnect")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
                
                Button(action: { appState.bluetoothManager.sendStorageCommand("test") }) {
                    HStack {
                        Text("📝")
                        Text("Test Storage Command")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                Button(action: { appState.bluetoothManager.startListeningForButtonNotifications() }) {
                    HStack {
                        Text("🔘")
                        Text("Start Button Notifications")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.indigo)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Helper Properties
    
    private var lastUpdateTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: Date())
    }
    
    // MARK: - Helper Methods
    
    private func estimateDistance(from rssi: Int) -> Double {
        let txPower = -59.0 // RSSI at 1 meter
        let pathLoss = 2.0 // Free space propagation
        let distance = pow(10, (txPower - Double(rssi)) / (10 * pathLoss))
        return max(0, distance)
    }
    
    private func signalQuality(_ rssi: Int) -> String {
        switch rssi {
        case -50...0:
            return "Excellent"
        case -60 ..< -50:
            return "Good"
        case -70 ..< -60:
            return "Fair"
        case -80 ..< -70:
            return "Poor"
        default:
            return "Very Poor"
        }
    }
}

// MARK: - Debug Row Component

struct DebugRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Motion Indicator View

struct MotionIndicatorView: View {
    let motion: MotionData
    
    var body: some View {
        VStack(spacing: 4) {
            Text("Motion Indicator")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    .frame(width: 60, height: 60)
                
                // Motion vector
                Path { path in
                    let center = CGPoint(x: 30, y: 30)
                    let scale: CGFloat = 3.0
                    
                    path.move(to: center)
                    let end = CGPoint(
                        x: center.x + CGFloat(motion.ax) * scale,
                        y: center.y + CGFloat(motion.ay) * scale
                    )
                    path.addLine(to: end)
                }
                .stroke(motion.isMoving ? Color.red : Color.blue, lineWidth: 2)
                
                // Center dot
                Circle()
                    .fill(Color.primary)
                    .frame(width: 4, height: 4)
            }
            .frame(height: 70)
        }
    }
}

// MARK: - RSSI Indicator View

struct RSSIIndicatorView: View {
    let rssi: Int
    
    var body: some View {
        VStack(spacing: 4) {
            Text("Signal Strength")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            HStack(spacing: 2) {
                ForEach(0..<5) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(barColor(for: index))
                        .frame(width: 8, height: 20)
                }
            }
        }
    }
    
    private func barColor(for index: Int) -> Color {
        let threshold = -80 + (index * 10)
        if rssi >= threshold {
            return rssi >= -60 ? .green : (rssi >= -70 ? .yellow : .orange)
        } else {
            return .gray.opacity(0.3)
        }
    }
}

// MARK: - Battery Indicator View

struct BatteryIndicatorView: View {
    let level: Int
    
    var body: some View {
        VStack(spacing: 4) {
            Text("Battery Level")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            HStack(spacing: 2) {
                ZStack(alignment: .leading) {
                    Rectangle()
                        .stroke(Color.gray, lineWidth: 1)
                        .frame(width: 60, height: 20)
                    
                    Rectangle()
                        .fill(batteryColor)
                        .frame(width: CGFloat(level) / 100.0 * 58, height: 18)
                }
                
                Rectangle()
                    .fill(Color.gray)
                    .frame(width: 3, height: 10)
            }
        }
    }
    
    private var batteryColor: Color {
        switch level {
        case 50...100:
            return .green
        case 20..<50:
            return .yellow
        default:
            return .red
        }
    }
}

#Preview {
    DeviceDebugView()
        .environmentObject(AppState())
}
