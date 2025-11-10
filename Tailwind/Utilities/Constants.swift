import Foundation

struct Constants {
    // Bluetooth Service UUIDs
    struct BLE {
        static let cyclingSpeedCadenceService = "1816"
        static let heartRateService = "180D"
        static let cyclingPowerService = "1818"

        // Characteristic UUIDs
        static let cscMeasurement = "2A5B"
        static let heartRateMeasurement = "2A37"
        static let cyclingPowerMeasurement = "2A63"
    }

    // App settings
    struct Settings {
        static let wheelCircumference = 2.105 // meters (700x25c tire)
        static let metersToMiles = 0.000621371 // Conversion factor
        static let updateInterval = 1.0 // seconds
    }
}
