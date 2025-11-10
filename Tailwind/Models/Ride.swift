import Foundation
import CoreLocation
import Combine


struct Ride: Identifiable, Codable {
    let id: UUID
    let date: Date
    let duration: TimeInterval // seconds
    let distance: Double // miles
    let averageSpeed: Double // mph
    let maxSpeed: Double // mph
    let averageHeartRate: Double // bpm
    let maxHeartRate: Int // bpm
    let calories: Double

    // GPS data
    let elevationGain: Double? // feet
    let routeCoordinates: [Coordinate]? // GPS track
    let notes: String?

    // Bike info
    let bikeName: String?
    let bikeType: String?

    // Training metrics
    let timeInZone: TimeInZone?
    let hrTSS: Double? // Heart Rate Training Stress Score

    // Codable wrapper for CLLocationCoordinate2D
    struct Coordinate: Codable {
        let latitude: Double
        let longitude: Double

        init(latitude: Double, longitude: Double) {
            self.latitude = latitude
            self.longitude = longitude
        }

        init(from coordinate: CLLocationCoordinate2D) {
            self.latitude = coordinate.latitude
            self.longitude = coordinate.longitude
        }

        var clCoordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
    }

    init(id: UUID = UUID(),
         date: Date = Date(),
         duration: TimeInterval,
         distance: Double,
         averageSpeed: Double,
         maxSpeed: Double,
         averageHeartRate: Double,
         maxHeartRate: Int,
         calories: Double,
         elevationGain: Double? = nil,
         routeCoordinates: [Coordinate]? = nil,
         notes: String? = nil,
         bikeName: String? = nil,
         bikeType: String? = nil,
         timeInZone: TimeInZone? = nil,
         hrTSS: Double? = nil) {
        self.id = id
        self.date = date
        self.duration = duration
        self.distance = distance
        self.averageSpeed = averageSpeed
        self.maxSpeed = maxSpeed
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
        self.calories = calories
        self.elevationGain = elevationGain
        self.routeCoordinates = routeCoordinates
        self.notes = notes
        self.bikeName = bikeName
        self.bikeType = bikeType
        self.timeInZone = timeInZone
        self.hrTSS = hrTSS
    }

    // Formatted values
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
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

    var formattedDistance: String {
        String(format: "%.2f mi", distance)
    }

    var formattedAvgSpeed: String {
        String(format: "%.1f mph", averageSpeed)
    }

    var formattedMaxSpeed: String {
        String(format: "%.1f mph", maxSpeed)
    }

    var formattedCalories: String {
        String(format: "%.0f cal", calories)
    }
}

// Storage for rides
class RideHistory: ObservableObject {
    @Published var rides: [Ride] = []

    private let ridesKey = "SavedRides"
    private let maxRides = 100 // Keep last 100 rides

    init() {
        loadRides()
    }

    func saveRide(_ ride: Ride) {
        rides.insert(ride, at: 0) // Add to beginning (most recent first)

        // Limit to max rides
        if rides.count > maxRides {
            rides = Array(rides.prefix(maxRides))
        }

        persistRides()
    }

    func deleteRide(_ ride: Ride) {
        rides.removeAll { $0.id == ride.id }
        persistRides()
    }

    func deleteRides(at offsets: IndexSet) {
        rides = rides.enumerated().filter { !offsets.contains($0.offset) }.map { $0.element }
        persistRides()
    }

    // Update a specific ride (e.g., to fix calories)
    func updateRide(_ rideId: UUID, with updatedRide: Ride) {
        if let index = rides.firstIndex(where: { $0.id == rideId }) {
            rides[index] = updatedRide
            persistRides()
            print("✅ Updated ride: \(updatedRide.formattedDate)")
        }
    }

    // Fix calories for a specific date's rides using correct formula (async version that updates HealthKit)
    func fixCalories(for date: Date? = nil, userProfile: UserProfile, healthKitService: HealthKitService? = nil) async -> String {
        let calendar = Calendar.current
        let targetDate = date != nil ? calendar.startOfDay(for: date!) : calendar.startOfDay(for: Date())

        var fixedCount = 0
        var diagnosticInfo = ""

        for i in 0..<rides.count {
            let ride = rides[i]

            // Check if ride is from target date
            guard calendar.isDate(ride.date, inSameDayAs: targetDate) else { continue }

            // Recalculate calories
            let durationMinutes = ride.duration / 60.0
            let hrForCalc = ride.averageHeartRate > 0 ? ride.averageHeartRate : 135.0
            let correctedCalories = userProfile.calculateCalories(
                averageHeartRate: hrForCalc,
                durationMinutes: durationMinutes
            )

            // Build diagnostic info with detailed calculation breakdown
            let weightKg = userProfile.weight * 0.453592
            let durationHours = durationMinutes / 60.0

            let term1 = Double(userProfile.age) * 0.2017
            let term2 = weightKg * 0.1988  // Fixed coefficient
            let term3 = hrForCalc * 0.6309
            let term4 = 55.0969
            let sum = term1 + term2 + term3 - term4
            let calPerMinute = sum / 4.184
            let manualCalc = calPerMinute * durationMinutes

            diagnosticInfo += "Ride: \(ride.formattedDate)\n"
            diagnosticInfo += "Duration: \(String(format: "%.1f", durationMinutes)) min (\(String(format: "%.2f", durationHours))h)\n"
            diagnosticInfo += "Avg HR: \(String(format: "%.1f", ride.averageHeartRate)) bpm\n"
            diagnosticInfo += "Profile: Age=\(userProfile.age), Weight=\(userProfile.weight)lbs (\(String(format: "%.1f", weightKg))kg), Gender=\(userProfile.gender.rawValue)\n"
            diagnosticInfo += "\nFormula breakdown:\n"
            diagnosticInfo += "  Age term: \(String(format: "%.2f", term1))\n"
            diagnosticInfo += "  Weight term: \(String(format: "%.2f", term2))\n"
            diagnosticInfo += "  HR term: \(String(format: "%.2f", term3))\n"
            diagnosticInfo += "  Constant: -\(String(format: "%.2f", term4))\n"
            diagnosticInfo += "  Sum: \(String(format: "%.2f", sum))\n"
            diagnosticInfo += "  Per minute: \(String(format: "%.2f", calPerMinute)) cal/min\n"
            diagnosticInfo += "  Total: \(String(format: "%.2f", manualCalc)) cal\n\n"
            diagnosticInfo += "Old: \(String(format: "%.0f", ride.calories)) cal\n"
            diagnosticInfo += "New: \(String(format: "%.0f", correctedCalories)) cal\n"
            diagnosticInfo += "Diff: \(String(format: "%.0f", correctedCalories - ride.calories)) cal\n\n"

            // Only update if significantly different (more than 5 calories)
            if abs(correctedCalories - ride.calories) > 5 {
                print("🔧 Fixing ride from \(ride.formattedDate)")
                print("   Duration: \(String(format: "%.1f", durationMinutes)) minutes")
                print("   Average HR: \(String(format: "%.1f", ride.averageHeartRate)) bpm")
                print("   Using HR: \(String(format: "%.1f", hrForCalc)) bpm")
                print("   Profile: Age=\(userProfile.age), Weight=\(userProfile.weight)lbs, Gender=\(userProfile.gender.rawValue)")
                print("   Old calories: \(String(format: "%.0f", ride.calories))")
                print("   New calories: \(String(format: "%.0f", correctedCalories))")

                // Create updated ride with corrected calories
                let updatedRide = Ride(
                    id: ride.id,
                    date: ride.date,
                    duration: ride.duration,
                    distance: ride.distance,
                    averageSpeed: ride.averageSpeed,
                    maxSpeed: ride.maxSpeed,
                    averageHeartRate: ride.averageHeartRate,
                    maxHeartRate: ride.maxHeartRate,
                    calories: correctedCalories,
                    elevationGain: ride.elevationGain,
                    routeCoordinates: ride.routeCoordinates,
                    notes: ride.notes,
                    bikeName: ride.bikeName,
                    bikeType: ride.bikeType,
                    timeInZone: ride.timeInZone,
                    hrTSS: ride.hrTSS
                )

                rides[i] = updatedRide

                // Update HealthKit if service is available
                if let healthKit = healthKitService, healthKit.isAuthorized {
                    do {
                        try await healthKit.updateRide(updatedRide)
                        print("✅ Updated ride in HealthKit")
                    } catch {
                        print("⚠️ Failed to update HealthKit: \(error.localizedDescription)")
                    }
                }

                fixedCount += 1
            }
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let dateString = formatter.string(from: targetDate)

        if fixedCount > 0 {
            persistRides()
            print("✅ Fixed \(fixedCount) ride(s) from \(dateString)")
            return diagnosticInfo + "✅ Fixed \(fixedCount) ride(s)"
        } else if !diagnosticInfo.isEmpty {
            return diagnosticInfo + "ℹ️ Rides already have correct calories (diff < 5 cal)"
        } else {
            print("ℹ️  No rides found for \(dateString)")
            return "No rides found for \(dateString)"
        }
    }

    // Convenience method for fixing today's calories
    func fixTodaysCalories(userProfile: UserProfile, healthKitService: HealthKitService? = nil) async -> String {
        return await fixCalories(for: nil, userProfile: userProfile, healthKitService: healthKitService)
    }

    private func loadRides() {
        guard let data = UserDefaults.standard.data(forKey: ridesKey) else {
            print("ℹ️ No saved rides data found")
            return
        }

        do {
            let decoder = JSONDecoder()
            rides = try decoder.decode([Ride].self, from: data)
            print("✅ Successfully loaded \(rides.count) rides")
        } catch {
            print("❌ ERROR: Failed to decode rides: \(error)")
            print("   Clearing corrupt data and starting fresh")
            UserDefaults.standard.removeObject(forKey: ridesKey)
            rides = []
        }
    }

    private func persistRides() {
        do {
            let encoder = JSONEncoder()
            let encoded = try encoder.encode(rides)
            UserDefaults.standard.set(encoded, forKey: ridesKey)
            print("✅ Successfully saved \(rides.count) rides")
        } catch {
            print("❌ ERROR: Failed to encode rides: \(error)")
        }
    }

    // Statistics
    var totalDistance: Double {
        rides.reduce(0) { $0 + $1.distance }
    }

    var totalRides: Int {
        rides.count
    }

    var totalCalories: Double {
        rides.reduce(0) { $0 + $1.calories }
    }

    var totalDuration: TimeInterval {
        rides.reduce(0) { $0 + $1.duration }
    }
}
