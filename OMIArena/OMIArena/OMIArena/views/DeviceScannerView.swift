//
//  DeviceScannerView.swift
//  OMI Arena - Device scanning interface
//
//  Shows available OMI devices and allows connection
//

import SwiftUI

struct DeviceScannerView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                Text("OMI Device Scanner")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()
                
                // Status
                if appState.isBluetoothConnected {
                    Text("✅ Connected to \(appState.connectedDeviceName ?? "OMI Device")")
                        .font(.headline)
                        .foregroundColor(.green)
                } else {
                    Text("🔍 Scanning for OMI devices...")
                        .font(.headline)
                        .foregroundColor(.blue)
                }
                
                // Device list
                deviceListView
                
                Spacer()
                
                // Action buttons
                actionButtons
            }
            .padding()
            .navigationTitle("Device Scanner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            startScanning()
        }
        .onDisappear {
            stopScanning()
        }
    }
    
    // MARK: - Device List View
    
    private var deviceListView: some View {
        VStack(spacing: 10) {
            if appState.bluetoothManager.discoveredDevices.isEmpty {
                Text("No OMI devices found")
                    .foregroundColor(.secondary)
                    .padding()
                
                Text("Make sure your OMI device is powered on and nearby")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(appState.bluetoothManager.discoveredDevices) { device in
                            DeviceRowView(device: device) {
                                connectToDevice(device)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxHeight: 300)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            if !appState.isBluetoothConnected {
                Button(action: startScanning) {
                    HStack {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                        Text("Scan Again")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(appState.bluetoothManager.isScanning)
            }
            
            Button(action: useMockData) {
                HStack {
                    Image(systemName: "gamecontroller")
                    Text("Use Mock Data")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
    }
    
    // MARK: - Actions
    
    private func startScanning() {
        appState.bluetoothManager.startScanning()
    }
    
    private func stopScanning() {
        appState.bluetoothManager.stopScanning()
    }
    
    private func connectToDevice(_ device: OMIDevice) {
        appState.bluetoothManager.connect(to: device)
    }
    
    private func useMockData() {
        // Mock data is already started by BluetoothManager
        dismiss()
    }
}

// MARK: - Device Row View

struct DeviceRowView: View {
    let device: OMIDevice
    let onConnect: () -> Void
    
    var body: some View {
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
                onConnect()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

#Preview {
    DeviceScannerView()
        .environmentObject(AppState())
}
