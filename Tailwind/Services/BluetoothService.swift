import Foundation
import CoreBluetooth
import Combine

class BluetoothService: NSObject, ObservableObject {
    @Published var discoveredSensors: [SensorInfo] = []
    @Published var connectedSensors: [SensorType: SensorInfo] = [:]
    @Published var isScanning = false
    @Published var bluetoothState: CBManagerState = .unknown

    private var centralManager: CBCentralManager!
    private var connectedPeripherals: [CBPeripheral] = []
    private var connectingPeripherals: [CBPeripheral] = [] // Keep strong reference during connection
    private var peripheralMap: [UUID: CBPeripheral] = [:] // UUID -> Peripheral
    private var sensorInfoMap: [UUID: SensorInfo] = [:] // UUID -> SensorInfo
    private var peripheralToTypeMap: [UUID: SensorType] = [:] // UUID -> SensorType
    private var batteryLevels: [UUID: Int] = [:] // UUID -> Battery %

    // Remember previously connected devices
    private let connectedDevicesKey = "ConnectedDeviceUUIDs"
    private var autoReconnecting = false

    // Callbacks for sensor data
    var onSpeedUpdate: ((Double) -> Void)?
    var onCadenceUpdate: ((Int) -> Void)?
    var onHeartRateUpdate: ((Int) -> Void)?

    // Track last values for calculating deltas
    private var lastWheelRevolutions: UInt32 = 0
    private var lastWheelEventTime: UInt16 = 0
    private var lastCrankRevolutions: UInt16 = 0
    private var lastCrankEventTime: UInt16 = 0

    // Heart rate smoothing
    private var heartRateHistory: [Int] = []
    private let heartRateSmoothingWindow = 5 // Average last 5 readings

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func startScanning() {
        guard centralManager.state == .poweredOn else { return }

        isScanning = true
        discoveredSensors.removeAll()

        // Scan for cycling sensors
        let serviceUUIDs = [
            CBUUID(string: "1816"), // Cycling Speed and Cadence
            CBUUID(string: "180D"), // Heart Rate
            CBUUID(string: "1818")  // Cycling Power
        ]

        // Check for already-connected peripherals with these services
        // iOS won't advertise already-connected devices in scan results
        for serviceUUID in serviceUUIDs {
            let alreadyConnected = centralManager.retrieveConnectedPeripherals(withServices: [serviceUUID])
            for peripheral in alreadyConnected {
                // Determine type from service UUID
                let type: SensorType
                switch serviceUUID.uuidString {
                case "180D":
                    type = .heartRate
                case "1816":
                    type = .speed // Could also be cadence, we'll update when we read characteristics
                case "1818":
                    type = .power
                default:
                    continue
                }

                let sensorInfo = SensorInfo(
                    id: peripheral.identifier,
                    name: peripheral.name ?? "Unknown \(type.rawValue)",
                    type: type,
                    isConnected: true
                )

                // Add to discovered list if not already present
                if !discoveredSensors.contains(where: { $0.id == peripheral.identifier }) {
                    discoveredSensors.append(sensorInfo)
                    peripheralMap[peripheral.identifier] = peripheral
                    sensorInfoMap[peripheral.identifier] = sensorInfo
                    peripheralToTypeMap[peripheral.identifier] = type

                    // Also add to connected sensors if not already there
                    if connectedSensors[type] == nil {
                        connectedSensors[type] = sensorInfo
                        if !connectedPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
                            connectedPeripherals.append(peripheral)
                        }
                    }

                    print("📱 Found already-connected \(type.rawValue): \(peripheral.name ?? "Unknown")")
                }
            }
        }

        centralManager.scanForPeripherals(withServices: serviceUUIDs, options: nil)
    }

    func stopScanning() {
        isScanning = false
        centralManager.stopScan()
    }

    func connect(to sensor: SensorInfo) {
        guard let peripheral = peripheralMap[sensor.id] else {
            print("Peripheral not found for sensor: \(sensor.name)")
            return
        }

        peripheral.delegate = self

        // Keep strong reference during connection
        if !connectingPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
            connectingPeripherals.append(peripheral)
        }

        // Store type mapping for this peripheral
        peripheralToTypeMap[peripheral.identifier] = sensor.type

        centralManager.connect(peripheral, options: nil)
        sensorInfoMap[sensor.id] = sensor

        // Stop scanning once we start connecting
        if isScanning {
            stopScanning()
        }
    }

    func disconnect(from sensorType: SensorType) {
        guard let sensorInfo = connectedSensors[sensorType],
              let peripheral = peripheralMap[sensorInfo.id] else {
            return
        }

        centralManager.cancelPeripheralConnection(peripheral)
    }

    // MARK: - Sensor Assignment Helpers

    // Get peripheral ID for a connected sensor
    func getPeripheralId(for sensorType: SensorType) -> String? {
        guard let sensorInfo = connectedSensors[sensorType],
              let peripheral = peripheralMap[sensorInfo.id] else {
            return nil
        }
        return peripheral.identifier.uuidString
    }

    // Create SavedSensor from currently connected sensor
    func createSavedSensor(for sensorType: SensorType, customName: String? = nil) -> SavedSensor? {
        guard let sensorInfo = connectedSensors[sensorType],
              let peripheral = peripheralMap[sensorInfo.id] else {
            return nil
        }

        return SavedSensor(
            id: peripheral.identifier.uuidString,
            customName: customName,
            type: sensorType,
            deviceName: peripheral.name ?? "Unknown Sensor"
        )
    }

    // Get battery level for a sensor type
    func getBatteryLevel(for sensorType: SensorType) -> Int? {
        guard let sensorInfo = connectedSensors[sensorType] else {
            return nil
        }
        return batteryLevels[sensorInfo.id]
    }

    // Connect to a specific peripheral by ID (for auto-reconnect)
    func connectToPeripheral(withId peripheralId: String, type: SensorType) {
        guard let uuid = UUID(uuidString: peripheralId) else {
            print("Invalid peripheral UUID: \(peripheralId)")
            return
        }

        // Check if already connected
        if let existingPeripheral = peripheralMap[uuid], existingPeripheral.state == .connected {
            print("Already connected to \(type.rawValue)")
            return
        }

        // Retrieve known peripheral
        let peripherals = centralManager.retrievePeripherals(withIdentifiers: [uuid])
        guard let peripheral = peripherals.first else {
            print("Could not find peripheral with ID: \(peripheralId)")
            return
        }

        // Store type mapping
        peripheralToTypeMap[peripheral.identifier] = type

        // Connect
        print("Connecting to saved \(type.rawValue): \(peripheral.name ?? "Unknown")")
        peripheralMap[peripheral.identifier] = peripheral
        connectingPeripherals.append(peripheral)
        peripheral.delegate = self
        centralManager.connect(peripheral, options: nil)
    }

    // Disconnect all sensors
    func disconnectAll() {
        for peripheral in connectedPeripherals {
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }

    // Disconnect bike-specific sensors only (keep profile sensors like heart rate)
    func disconnectBikeSensors() {
        for (sensorType, _) in connectedSensors {
            if !sensorType.isProfileSensor {
                disconnect(from: sensorType)
            }
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothState = central.state

        switch central.state {
        case .poweredOn:
            print("Bluetooth is powered on")
            // Auto-reconnect to previously connected devices
            reconnectToKnownDevices()
        case .poweredOff:
            print("Bluetooth is powered off")
        case .unauthorized:
            print("Bluetooth is unauthorized")
        case .unsupported:
            print("Bluetooth is unsupported")
        default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? "Unknown Device"

        // Determine sensor type based on services
        let sensorType = determineSensorType(from: advertisementData)

        let sensorInfo = SensorInfo(
            id: peripheral.identifier,
            name: name,
            type: sensorType,
            rssi: RSSI.intValue
        )

        // Add to discovered sensors if not already present
        if !discoveredSensors.contains(where: { $0.id == peripheral.identifier }) {
            discoveredSensors.append(sensorInfo)
            peripheralMap[peripheral.identifier] = peripheral
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to \(peripheral.name ?? "unknown")")

        // Move from connecting to connected array
        connectingPeripherals.removeAll { $0.identifier == peripheral.identifier }
        if !connectedPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
            connectedPeripherals.append(peripheral)
        }

        // Update sensor status to connected
        // First check if we have a stored sensorInfo (from scanning)
        if let sensorInfo = sensorInfoMap.values.first(where: { peripheralMap[$0.id] == peripheral }) {
            var updatedInfo = sensorInfo
            updatedInfo.isConnected = true
            connectedSensors[sensorInfo.type] = updatedInfo

            // Update in discovered sensors list
            if let index = discoveredSensors.firstIndex(where: { $0.id == sensorInfo.id }) {
                discoveredSensors[index].isConnected = true
            }

            // Save to auto-reconnect list
            saveConnectedDevice(uuid: peripheral.identifier)
        } else if let type = peripheralToTypeMap[peripheral.identifier] {
            // This is an auto-reconnect - create SensorInfo from stored type
            let sensorInfo = SensorInfo(
                id: peripheral.identifier,
                name: peripheral.name ?? "Unknown",
                type: type,
                isConnected: true
            )
            sensorInfoMap[peripheral.identifier] = sensorInfo
            connectedSensors[type] = sensorInfo

            print("✅ Auto-reconnected \(type.rawValue): \(peripheral.name ?? "Unknown")")
        }

        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected from \(peripheral.name ?? "unknown")")

        // Remove from connected peripherals
        connectedPeripherals.removeAll { $0.identifier == peripheral.identifier }
        connectingPeripherals.removeAll { $0.identifier == peripheral.identifier }

        // Update sensor status
        if let sensorInfo = sensorInfoMap.values.first(where: { peripheralMap[$0.id] == peripheral }) {
            connectedSensors.removeValue(forKey: sensorInfo.type)

            if let index = discoveredSensors.firstIndex(where: { $0.id == sensorInfo.id }) {
                discoveredSensors[index].isConnected = false
            }
        }

        if let error = error {
            print("Disconnect error: \(error.localizedDescription)")
        }

        // Auto-reconnect if this was unexpected
        if error != nil && isConnectedDevice(uuid: peripheral.identifier) {
            print("Attempting to reconnect to \(peripheral.name ?? "unknown")...")
            if !connectingPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
                connectingPeripherals.append(peripheral)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.centralManager.connect(peripheral, options: nil)
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Failed to connect to \(peripheral.name ?? "unknown")")

        // Remove from connecting peripherals on failure
        connectingPeripherals.removeAll { $0.identifier == peripheral.identifier }

        if let error = error {
            print("Connection error: \(error.localizedDescription)")
        }
    }

    private func determineSensorType(from advertisementData: [String: Any]) -> SensorType {
        guard let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] else {
            return .speed // Default
        }

        if serviceUUIDs.contains(CBUUID(string: "1816")) {
            return .speed // Could be speed or cadence
        } else if serviceUUIDs.contains(CBUUID(string: "180D")) {
            return .heartRate
        } else if serviceUUIDs.contains(CBUUID(string: "1818")) {
            return .power
        }

        return .speed
    }
}

// MARK: - CBPeripheralDelegate
extension BluetoothService: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }

        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }

        for characteristic in characteristics {
            // Subscribe to notifications for sensor data
            if characteristic.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: characteristic)
            }

            // Read battery level once (Battery Level characteristic)
            if characteristic.uuid.uuidString == "2A19" && characteristic.properties.contains(.read) {
                peripheral.readValue(for: characteristic)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }

        // Parse based on characteristic UUID
        switch characteristic.uuid.uuidString {
        case "2A5B": // CSC Measurement (Cycling Speed and Cadence)
            parseCSCMeasurement(data: data)
        case "2A37": // Heart Rate Measurement
            parseHeartRateMeasurement(data: data)
        case "2A63": // Cycling Power Measurement
            parsePowerMeasurement(data: data)
        case "2A19": // Battery Level
            parseBatteryLevel(data: data, peripheral: peripheral)
        default:
            break // Silently ignore unknown characteristics
        }
    }

    // MARK: - Data Parsing

    private func parseCSCMeasurement(data: Data) {
        guard data.count >= 1 else { return }

        let flags = data[0]
        var offset = 1

        let hasWheelRevolution = (flags & 0x01) != 0
        let hasCrankRevolution = (flags & 0x02) != 0

        // Parse Wheel Revolution Data (Speed)
        if hasWheelRevolution && data.count >= offset + 6 {
            // Use loadUnaligned to safely handle misaligned data
            let wheelRevolutions = data.withUnsafeBytes {
                $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self)
            }
            offset += 4
            let wheelEventTime = data.withUnsafeBytes {
                $0.loadUnaligned(fromByteOffset: offset, as: UInt16.self)
            }
            offset += 2

            calculateSpeed(wheelRevolutions: wheelRevolutions, wheelEventTime: wheelEventTime)
        }

        // Parse Crank Revolution Data (Cadence)
        if hasCrankRevolution && data.count >= offset + 4 {
            let crankRevolutions = data.withUnsafeBytes {
                $0.loadUnaligned(fromByteOffset: offset, as: UInt16.self)
            }
            offset += 2
            let crankEventTime = data.withUnsafeBytes {
                $0.loadUnaligned(fromByteOffset: offset, as: UInt16.self)
            }

            calculateCadence(crankRevolutions: crankRevolutions, crankEventTime: crankEventTime)
        }
    }

    private func calculateSpeed(wheelRevolutions: UInt32, wheelEventTime: UInt16) {
        // Skip first reading (need delta)
        if lastWheelRevolutions == 0 {
            lastWheelRevolutions = wheelRevolutions
            lastWheelEventTime = wheelEventTime
            return
        }

        // Calculate deltas (handle rollover)
        let revDelta = wheelRevolutions >= lastWheelRevolutions
            ? wheelRevolutions - lastWheelRevolutions
            : (UInt32.max - lastWheelRevolutions) + wheelRevolutions + 1

        let timeDelta = wheelEventTime >= lastWheelEventTime
            ? wheelEventTime - lastWheelEventTime
            : (UInt16.max - lastWheelEventTime) + wheelEventTime + 1

        // Update last values
        lastWheelRevolutions = wheelRevolutions
        lastWheelEventTime = wheelEventTime

        // Calculate speed
        if timeDelta > 0 && revDelta > 0 {
            // Time is in 1/1024 seconds
            let timeInSeconds = Double(timeDelta) / 1024.0

            // Distance = revolutions * wheel circumference (meters)
            let distanceMeters = Double(revDelta) * Constants.Settings.wheelCircumference

            // Speed in meters per second
            let speedMPS = distanceMeters / timeInSeconds

            // Convert to mph
            let speedMPH = speedMPS * 2.23694

            DispatchQueue.main.async {
                self.onSpeedUpdate?(speedMPH)
            }
        }
    }

    private func calculateCadence(crankRevolutions: UInt16, crankEventTime: UInt16) {
        // Skip first reading
        if lastCrankRevolutions == 0 {
            lastCrankRevolutions = crankRevolutions
            lastCrankEventTime = crankEventTime
            return
        }

        // Calculate deltas (handle rollover)
        let revDelta = crankRevolutions >= lastCrankRevolutions
            ? crankRevolutions - lastCrankRevolutions
            : (UInt16.max - lastCrankRevolutions) + crankRevolutions + 1

        let timeDelta = crankEventTime >= lastCrankEventTime
            ? crankEventTime - lastCrankEventTime
            : (UInt16.max - lastCrankEventTime) + crankEventTime + 1

        // Update last values
        lastCrankRevolutions = crankRevolutions
        lastCrankEventTime = crankEventTime

        // Calculate cadence (RPM)
        if timeDelta > 0 && revDelta > 0 {
            let timeInMinutes = Double(timeDelta) / 1024.0 / 60.0
            let cadenceRPM = Double(revDelta) / timeInMinutes

            DispatchQueue.main.async {
                self.onCadenceUpdate?(Int(cadenceRPM))
            }
        }
    }

    private func parseHeartRateMeasurement(data: Data) {
        guard data.count >= 2 else { return }

        // Debug: Print raw data
        let hexString = data.map { String(format: "%02X", $0) }.joined(separator: " ")
        print("HR Raw Data: \(hexString) (bytes: \(data.count))")

        let flags = data[0]
        print("HR Flags byte: 0x\(String(format: "%02X", flags)) (binary: \(String(flags, radix: 2)))")

        let hrValueFormat = (flags & 0x01) != 0 // 0 = UInt8, 1 = UInt16
        print("HR Value Format: \(hrValueFormat ? "UInt16" : "UInt8")")

        let rawHeartRate: Int
        if hrValueFormat {
            // UInt16 format
            guard data.count >= 3 else {
                print("HR Error: Not enough data for UInt16")
                return
            }
            rawHeartRate = Int(data[1]) | (Int(data[2]) << 8)
            print("HR UInt16: byte[1]=\(data[1]), byte[2]=\(data[2]), result=\(rawHeartRate)")
        } else {
            // UInt8 format
            rawHeartRate = Int(data[1])
            print("HR UInt8: byte[1]=\(data[1]), result=\(rawHeartRate)")
        }

        // TICKR sends standard decimal values (not BCD)
        let actualHeartRate = rawHeartRate
        print("HR: \(actualHeartRate) bpm")

        // Validate reasonable heart rate range (30-220 bpm)
        guard actualHeartRate >= 30 && actualHeartRate <= 220 else {
            print("Invalid HR reading: \(actualHeartRate) - ignoring")
            return
        }

        // Add to history for smoothing
        heartRateHistory.append(actualHeartRate)

        // Keep only last N readings
        if heartRateHistory.count > heartRateSmoothingWindow {
            heartRateHistory.removeFirst()
        }

        // Calculate smoothed heart rate (moving average)
        let smoothedHeartRate = heartRateHistory.reduce(0, +) / heartRateHistory.count

        // Additional outlier filter: ignore if reading differs from average by more than 20 bpm
        if heartRateHistory.count >= 3 {
            let previousAverage = heartRateHistory.dropLast().reduce(0, +) / (heartRateHistory.count - 1)
            let difference = abs(actualHeartRate - previousAverage)

            if difference > 20 {
                print("HR outlier detected: \(actualHeartRate) (avg: \(previousAverage)) - using average")
                // Remove the outlier and use previous average
                heartRateHistory.removeLast()

                DispatchQueue.main.async {
                    self.onHeartRateUpdate?(previousAverage)
                }
                return
            }
        }

        DispatchQueue.main.async {
            self.onHeartRateUpdate?(smoothedHeartRate)
        }
    }

    private func parsePowerMeasurement(data: Data) {
        guard data.count >= 4 else { return }

        // Power is in bytes 2-3 as Int16 (watts)
        let power = Int(data[2]) | (Int(data[3]) << 8)

        print("Power: \(power)W")
        // Add power callback if needed
    }

    private func parseBatteryLevel(data: Data, peripheral: CBPeripheral) {
        guard data.count >= 1 else { return }

        let batteryLevel = Int(data[0]) // Battery level is 0-100%
        batteryLevels[peripheral.identifier] = batteryLevel

        print("🔋 \(peripheral.name ?? "Unknown"): \(batteryLevel)%")

        // Update sensor info with battery level
        if var sensorInfo = sensorInfoMap[peripheral.identifier] {
            sensorInfo.batteryLevel = batteryLevel
            sensorInfoMap[peripheral.identifier] = sensorInfo

            // Update in connected sensors
            if let type = peripheralToTypeMap[peripheral.identifier] {
                connectedSensors[type] = sensorInfo
            }

            // Update in discovered sensors
            if let index = discoveredSensors.firstIndex(where: { $0.id == peripheral.identifier }) {
                discoveredSensors[index].batteryLevel = batteryLevel
            }
        }
    }

    // MARK: - Auto-Reconnect Helpers

    private func saveConnectedDevice(uuid: UUID) {
        var uuids = UserDefaults.standard.array(forKey: connectedDevicesKey) as? [String] ?? []
        let uuidString = uuid.uuidString

        if !uuids.contains(uuidString) {
            uuids.append(uuidString)
            UserDefaults.standard.set(uuids, forKey: connectedDevicesKey)
            print("Saved device for auto-reconnect: \(uuidString)")
        }
    }

    private func isConnectedDevice(uuid: UUID) -> Bool {
        let uuids = UserDefaults.standard.array(forKey: connectedDevicesKey) as? [String] ?? []
        return uuids.contains(uuid.uuidString)
    }

    private func reconnectToKnownDevices() {
        guard !autoReconnecting else { return }
        autoReconnecting = true

        let uuidStrings = UserDefaults.standard.array(forKey: connectedDevicesKey) as? [String] ?? []

        guard !uuidStrings.isEmpty else {
            print("No known devices to reconnect")
            autoReconnecting = false
            return
        }

        print("Attempting to reconnect to \(uuidStrings.count) known device(s)...")

        let uuids = uuidStrings.compactMap { UUID(uuidString: $0) }
        let peripherals = centralManager.retrievePeripherals(withIdentifiers: uuids)

        for peripheral in peripherals {
            print("Reconnecting to: \(peripheral.name ?? "Unknown") (\(peripheral.identifier))")
            peripheral.delegate = self

            // Keep strong reference during connection
            if !connectingPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
                connectingPeripherals.append(peripheral)
            }

            centralManager.connect(peripheral, options: nil)
        }

        autoReconnecting = false
    }

    func clearSavedDevices() {
        UserDefaults.standard.removeObject(forKey: connectedDevicesKey)
        print("Cleared all saved devices")
    }
}

