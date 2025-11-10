import Foundation

enum SensorType: String, CaseIterable, Codable {
    case speed = "Speed Sensor"
    case cadence = "Cadence Sensor"
    case heartRate = "Heart Rate Monitor"
    case power = "Power Meter"

    var serviceUUID: String {
        switch self {
        case .speed:
            return "1816" // Cycling Speed and Cadence Service
        case .cadence:
            return "1816" // Cycling Speed and Cadence Service
        case .heartRate:
            return "180D" // Heart Rate Service
        case .power:
            return "1818" // Cycling Power Service
        }
    }

    // True if sensor is personal (goes with rider), false if bike-specific
    var isProfileSensor: Bool {
        switch self {
        case .heartRate:
            return true
        case .speed, .cadence, .power:
            return false
        }
    }
}

struct SensorInfo: Identifiable {
    let id: UUID
    let name: String
    let type: SensorType
    let rssi: Int
    var isConnected: Bool = false
    var batteryLevel: Int? = nil // Battery percentage (0-100)

    init(id: UUID = UUID(), name: String, type: SensorType, rssi: Int = 0, isConnected: Bool = false, batteryLevel: Int? = nil) {
        self.id = id
        self.name = name
        self.type = type
        self.rssi = rssi
        self.isConnected = isConnected
        self.batteryLevel = batteryLevel
    }
}

// Stored sensor assignment
struct SavedSensor: Identifiable, Codable {
    let id: String // Bluetooth peripheral identifier
    var customName: String? // User-given name
    let type: SensorType
    let deviceName: String // Original BLE device name

    var displayName: String {
        customName ?? deviceName
    }
}
