//
//  OMIBluetoothManager.swift
//  OMI Arena - Bluetooth LE manager for OMI Dev Kit 2
//
//  Handles scanning, connecting, and data streaming from OMI wearables
//  Provides mock data when hardware is not available
//

import Foundation
import CoreBluetooth
import Combine
import SwiftUI

/// Bluetooth manager for OMI Dev Kit 2 devices
/// Handles BLE operations and provides real-time motion and RSSI data
@MainActor
class OMIBluetoothManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var isConnected: Bool = false
    @Published var isScanning: Bool = false
    @Published var discoveredDevices: [OMIDevice] = []
    @Published var connectedDeviceName: String?
    @Published var currentMotion: MotionData?
    @Published var currentRssi: Int?
    @Published var batteryLevel: Int?
    @Published var errorMessage: String?
    
    // MARK: - Bluetooth Properties
    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var motionCharacteristic: CBCharacteristic?
    private var batteryCharacteristic: CBCharacteristic?
    
    // MARK: - UUIDs for OMI Dev Kit 2
    private struct OMIUUIDs {
        // Audio Service (main data service)
        static let audioService = CBUUID(string: "19B10000-E8F2-537E-4F6C-D104768A1214")
        static let audioData = CBUUID(string: "19B10001-E8F2-537E-4F6C-D104768A1214")
        static let codecType = CBUUID(string: "19B10002-E8F2-537E-4F6C-D104768A1214")
        
        // Standard BLE services
        static let batteryService = CBUUID(string: "180F")
        static let batteryLevel = CBUUID(string: "2A19")
        
        static let deviceInfoService = CBUUID(string: "180A")
        static let manufacturerName = CBUUID(string: "2A29")
        static let modelNumber = CBUUID(string: "2A24")
        static let hardwareRevision = CBUUID(string: "2A27")
        static let firmwareRevision = CBUUID(string: "2A26")
    }
    
    // MARK: - Mock Data
    private var mockDataTimer: Timer?
    private var isUsingMockData: Bool = false
    
    // MARK: - Initialization
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    /// Initialize the Bluetooth manager
    func initialize() {
        print("🔵 Initializing OMI Bluetooth Manager...")
        
        // Start mock data if Bluetooth is not available
        if centralManager.state != .poweredOn {
            startMockData()
        }
    }
    
    // MARK: - Device Management
    
    /// Start scanning for OMI devices
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            showError("Bluetooth is not powered on")
            return
        }
        
        print("🔍 Starting scan for OMI devices...")
        isScanning = true
        discoveredDevices.removeAll()
        
        // Scan for devices advertising the Audio Service
        centralManager.scanForPeripherals(
            withServices: [OMIUUIDs.audioService],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }
    
    /// Stop scanning for devices
    func stopScanning() {
        print("⏹️ Stopping device scan")
        isScanning = false
        centralManager.stopScan()
    }
    
    /// Connect to a specific OMI device
    func connect(to device: OMIDevice) {
        guard centralManager.state == .poweredOn else {
            showError("Bluetooth is not powered on")
            return
        }
        
        print("🔗 Connecting to \(device.name)...")
        centralManager.connect(device.peripheral, options: nil)
    }
    
    /// Disconnect from current device
    func disconnect() {
        guard let peripheral = connectedPeripheral else {
            return
        }
        
        print("🔌 Disconnecting from \(peripheral.name ?? "device")...")
        centralManager.cancelPeripheralConnection(peripheral)
    }
    
    // MARK: - Mock Data
    
    /// Start generating mock data for testing
    private func startMockData() {
        print("🎭 Starting mock data generation")
        isUsingMockData = true
        
        // Simulate device connection
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.connectedDeviceName = "Mock OMI Device"
            self.isConnected = true
            self.batteryLevel = 85
        }
        
        // Generate mock motion data
        mockDataTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.generateMockMotionData()
        }
        
        // Generate mock RSSI data
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.generateMockRssiData()
        }
    }
    
    /// Stop mock data generation
    private func stopMockData() {
        print("🛑 Stopping mock data generation")
        isUsingMockData = false
        mockDataTimer?.invalidate()
        mockDataTimer = nil
    }
    
    /// Generate mock motion data
    private func generateMockMotionData() {
        // Simulate realistic motion with some randomness
        let time = Date().timeIntervalSince1970
        let ax = sin(time * 2) * 2 + Double.random(in: -0.5...0.5)
        let ay = cos(time * 3) * 1.5 + Double.random(in: -0.3...0.3)
        let az = 9.8 + sin(time * 4) * 0.5 + Double.random(in: -0.2...0.2)
        
        currentMotion = MotionData(ax: ax, ay: ay, az: az)
    }
    
    /// Generate mock RSSI data
    private func generateMockRssiData() {
        // Simulate varying signal strength
        let baseRssi = -65
        let variation = Int.random(in: -10...10)
        currentRssi = baseRssi + variation
    }
    
    // MARK: - Data Processing
    
    /// Process incoming motion data from device
    private func processMotionData(_ data: Data) {
        // TODO: Implement actual motion data parsing based on OMI protocol
        // For now, generate mock-like data from the input
        guard data.count >= 12 else { return } // 3 floats * 4 bytes each
        
        let ax = data.withUnsafeBytes { $0.load(fromByteOffset: 0, as: Float.self) }
        let ay = data.withUnsafeBytes { $0.load(fromByteOffset: 4, as: Float.self) }
        let az = data.withUnsafeBytes { $0.load(fromByteOffset: 8, as: Float.self) }
        
        currentMotion = MotionData(ax: Double(ax), ay: Double(ay), az: Double(az))
    }
    
    /// Process battery level data
    private func processBatteryData(_ data: Data) {
        guard !data.isEmpty else { return }
        batteryLevel = Int(data[0])
    }
    
    // MARK: - Placeholder Methods
    
    /// Send storage command to device (placeholder)
    func sendStorageCommand(_ command: String) {
        // TODO: Implement storage command sending
        // The exact characteristic and command format needs to be determined
        print("📝 Storage command (placeholder): \(command)")
    }
    
    /// Start listening for button notifications (placeholder)
    func startListeningForButtonNotifications() {
        // TODO: Implement button notification listening
        // The exact characteristic needs to be determined from documentation
        print("🔘 Button notifications (placeholder): Not implemented")
    }
    
    // MARK: - Error Handling
    
    /// Show error message
    private func showError(_ message: String) {
        errorMessage = message
        print("❌ Bluetooth Error: \(message)")
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
    }
}

// MARK: - CBCentralManagerDelegate

extension OMIBluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("✅ Bluetooth is powered on")
            if isUsingMockData {
                stopMockData()
            }
        case .poweredOff:
            print("❌ Bluetooth is powered off")
            if !isUsingMockData {
                startMockData()
            }
        case .unauthorized:
            showError("Bluetooth access is not authorized")
        case .unsupported:
            showError("Bluetooth is not supported on this device")
        case .resetting:
            print("🔄 Bluetooth is resetting")
        case .unknown:
            print("❓ Bluetooth state is unknown")
        @unknown default:
            print("❓ Unknown Bluetooth state")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let deviceName = peripheral.name ?? "Unknown OMI Device"
        let device = OMIDevice(
            peripheral: peripheral,
            name: deviceName,
            rssi: RSSI.intValue
        )
        
        // Add device if not already discovered
        if !discoveredDevices.contains(where: { $0.peripheral.identifier == peripheral.identifier }) {
            discoveredDevices.append(device)
            print("📱 Discovered: \(deviceName) (RSSI: \(RSSI.intValue))")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("✅ Connected to \(peripheral.name ?? "device")")
        
        connectedPeripheral = peripheral
        connectedDeviceName = peripheral.name
        isConnected = true
        
        // Stop scanning
        stopScanning()
        
        // Discover services
        peripheral.delegate = self
        peripheral.discoverServices([
            OMIUUIDs.audioService,
            OMIUUIDs.batteryService,
            OMIUUIDs.deviceInfoService
        ])
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("🔌 Disconnected from \(peripheral.name ?? "device")")
        
        connectedPeripheral = nil
        connectedDeviceName = nil
        isConnected = false
        motionCharacteristic = nil
        batteryCharacteristic = nil
        currentMotion = nil
        currentRssi = nil
        batteryLevel = nil
        
        if let error = error {
            showError("Disconnection error: \(error.localizedDescription)")
        }
        
        // Start mock data if no real connection
        if !isUsingMockData {
            startMockData()
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("❌ Failed to connect to \(peripheral.name ?? "device")")
        
        if let error = error {
            showError("Connection failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - CBPeripheralDelegate

extension OMIBluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            showError("Service discovery failed: \(error.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else { return }
        
        for service in services {
            print("🔍 Found service: \(service.uuid)")
            
            // Discover characteristics for each service
            if service.uuid == OMIUUIDs.audioService {
                peripheral.discoverCharacteristics([
                    OMIUUIDs.audioData,
                    OMIUUIDs.codecType
                ], for: service)
            } else if service.uuid == OMIUUIDs.batteryService {
                peripheral.discoverCharacteristics([
                    OMIUUIDs.batteryLevel
                ], for: service)
            } else if service.uuid == OMIUUIDs.deviceInfoService {
                peripheral.discoverCharacteristics([
                    OMIUUIDs.manufacturerName,
                    OMIUUIDs.modelNumber,
                    OMIUUIDs.hardwareRevision,
                    OMIUUIDs.firmwareRevision
                ], for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            showError("Characteristic discovery failed: \(error.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            print("📊 Found characteristic: \(characteristic.uuid)")
            
            // Handle audio data characteristic
            if characteristic.uuid == OMIUUIDs.audioData {
                motionCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
                print("📡 Subscribed to motion data")
            }
            
            // Handle battery level characteristic
            if characteristic.uuid == OMIUUIDs.batteryLevel {
                batteryCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
                peripheral.readValue(for: characteristic)
                print("🔋 Subscribed to battery level")
            }
            
            // Read device information once
            if service.uuid == OMIUUIDs.deviceInfoService {
                peripheral.readValue(for: characteristic)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            showError("Characteristic update failed: \(error.localizedDescription)")
            return
        }
        
        guard let data = characteristic.value else { return }
        
        // Process different characteristic types
        if characteristic.uuid == OMIUUIDs.audioData {
            processMotionData(data)
        } else if characteristic.uuid == OMIUUIDs.batteryLevel {
            processBatteryData(data)
        } else if characteristic.uuid == OMIUUIDs.manufacturerName {
            let manufacturer = String(data: data, encoding: .utf8) ?? "Unknown"
            print("🏭 Manufacturer: \(manufacturer)")
        } else if characteristic.uuid == OMIUUIDs.modelNumber {
            let model = String(data: data, encoding: .utf8) ?? "Unknown"
            print("📱 Model: \(model)")
        } else if characteristic.uuid == OMIUUIDs.firmwareRevision {
            let firmware = String(data: data, encoding: .utf8) ?? "Unknown"
            print("💾 Firmware: \(firmware)")
        }
    }
}

// MARK: - OMI Device Model

/// Represents a discovered OMI device
struct OMIDevice: Identifiable, Equatable {
    let id = UUID()
    let peripheral: CBPeripheral
    let name: String
    let rssi: Int
    
    static func == (lhs: OMIDevice, rhs: OMIDevice) -> Bool {
        return lhs.peripheral.identifier == rhs.peripheral.identifier
    }
}
