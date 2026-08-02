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

    // Workout import
    struct Import {
        /// Workouts shorter than this are skipped. Peloton writes each warm-up and
        /// cool-down as its own cycling activity, so importing everything inflates
        /// the ride count and adds a few TSS per phantom "ride". Skipped workouts
        /// are always reported back to the user rather than dropped silently.
        static let minimumWorkoutDuration: TimeInterval = 10 * 60
    }
}
