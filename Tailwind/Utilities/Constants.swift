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
        /// The shortest thing that counts as a ride.
        ///
        /// Peloton writes each warm-up and cool-down as its own cycling activity, so
        /// importing everything inflates the ride count and adds a few TSS per
        /// phantom "ride". Fifteen minutes clears both the 5-minute cool-downs and
        /// the 10-minute warm-up classes while keeping any real short session.
        ///
        /// Route analysis uses the same bar — a ride too short to be a session is
        /// also too short to be a route — so the two never drift apart.
        /// Skipped workouts are always reported rather than dropped silently.
        static let minimumWorkoutDuration: TimeInterval = 15 * 60
    }
}
