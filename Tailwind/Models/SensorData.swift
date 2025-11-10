import Foundation

struct SensorData {
    var speed: Double = 0.0 // mph
    var cadence: Int = 0 // rpm
    var heartRate: Int = 0 // bpm
    var power: Int = 0 // watts
    var distance: Double = 0.0 // miles
    var duration: TimeInterval = 0.0 // seconds
    var calories: Double = 0.0 // total calories burned

    // For calorie calculation
    var totalHeartRateSum: Double = 0.0 // Sum of all HR readings
    var heartRateSampleCount: Int = 0 // Number of HR samples

    var averageSpeed: Double {
        guard duration > 0 else { return 0 }
        return distance / (duration / 3600)
    }

    var averageHeartRate: Double {
        guard heartRateSampleCount > 0 else { return 0 }
        return totalHeartRateSum / Double(heartRateSampleCount)
    }

    var formattedSpeed: String {
        String(format: "%.1f", speed)
    }

    var formattedDistance: String {
        String(format: "%.2f", distance)
    }

    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}
