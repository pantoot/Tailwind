#!/usr/bin/swift
import Foundation

// UserProfile struct (from your app)
struct UserProfile: Codable {
    var birthday: Date
    var weight: Double // in lbs
    var gender: Gender
    var heightInches: Int?
    var lactateThresholdHR: Int?
    var maxHeartRate: Int?

    enum Gender: String, Codable, CaseIterable {
        case male = "Male"
        case female = "Female"
    }

    var age: Int {
        let calendar = Calendar.current
        let now = Date()
        let ageComponents = calendar.dateComponents([.year], from: birthday, to: now)
        return ageComponents.year ?? 0
    }

    var weightKg: Double {
        weight * 0.453592
    }

    func calculateCalories(averageHeartRate: Double, durationMinutes: Double) -> Double {
        guard durationMinutes > 0, averageHeartRate > 0 else { return 0 }

        let durationHours = durationMinutes / 60.0

        switch gender {
        case .male:
            // Men: ((Age × 0.2017) - (Weight × 0.09036) + (HR × 0.6309) - 55.0969) × Duration / 4.184
            let calories = ((Double(age) * 0.2017) - (weightKg * 0.09036) + (averageHeartRate * 0.6309) - 55.0969) * durationHours / 4.184
            return max(0, calories)

        case .female:
            // Women: ((Age × 0.074) - (Weight × 0.05741) + (HR × 0.4472) - 20.4022) × Duration / 4.184
            let calories = ((Double(age) * 0.074) - (weightKg * 0.05741) + (averageHeartRate * 0.4472) - 20.4022) * durationHours / 4.184
            return max(0, calories)
        }
    }

    static var `default`: UserProfile {
        let calendar = Calendar.current
        let thirtyYearsAgo = calendar.date(byAdding: .year, value: -30, to: Date()) ?? Date()
        return UserProfile(birthday: thirtyYearsAgo, weight: 170, gender: .male, heightInches: 70, lactateThresholdHR: nil, maxHeartRate: nil)
    }
}

// Simplified Ride struct
struct Ride: Codable {
    let id: UUID
    let date: Date
    let duration: TimeInterval
    let distance: Double
    let averageSpeed: Double
    let maxSpeed: Double
    let averageHeartRate: Double
    let maxHeartRate: Int
    let calories: Double
    let elevationGain: Double?
    let routeCoordinates: [Coordinate]?
    let notes: String?
    let bikeName: String?
    let bikeType: String?
    let timeInZone: TimeInZone?
    let hrTSS: Double?

    struct Coordinate: Codable {
        let latitude: Double
        let longitude: Double
    }
}

// TimeInZone stub (just for decoding)
struct TimeInZone: Codable {
    var z1: TimeInterval = 0
    var z2: TimeInterval = 0
    var z3: TimeInterval = 0
    var z4: TimeInterval = 0
    var z5: TimeInterval = 0
}

// Main script
print("🔧 Tailwind Ride Calorie Fixer")
print("================================")

// Get app container
let defaults = UserDefaults.standard

// Load user profile
let profileKey = "UserProfile"
guard let profileData = defaults.data(forKey: profileKey),
      let profile = try? JSONDecoder().decode(UserProfile.self, from: profileData) else {
    print("❌ Could not load user profile")
    exit(1)
}

print("✅ Loaded user profile:")
print("   Age: \(profile.age)")
print("   Weight: \(profile.weight) lbs")
print("   Gender: \(profile.gender.rawValue)")

// Load rides
let ridesKey = "SavedRides"
guard let ridesData = defaults.data(forKey: ridesKey) else {
    print("❌ No rides data found")
    exit(1)
}

var rides = try! JSONDecoder().decode([Ride].self, from: ridesData)
print("✅ Loaded \(rides.count) rides")

// Find today's rides
let calendar = Calendar.current
let today = calendar.startOfDay(for: Date())

let todaysRides = rides.enumerated().filter { _, ride in
    calendar.isDate(ride.date, inSameDayAs: today)
}

guard !todaysRides.isEmpty else {
    print("ℹ️  No rides found for today")
    exit(0)
}

print("\n📊 Found \(todaysRides.count) ride(s) from today:")
for (_, ride) in todaysRides {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    print("\n   Ride at \(formatter.string(from: ride.date))")
    print("   Duration: \(Int(ride.duration / 60)) min")
    print("   Distance: \(String(format: "%.2f", ride.distance)) mi")
    print("   Avg HR: \(String(format: "%.0f", ride.averageHeartRate)) bpm")
    print("   Current Calories: \(String(format: "%.0f", ride.calories))")

    // Recalculate
    let durationMinutes = ride.duration / 60.0

    // Use baseline 135 if no HR data
    let hrForCalc = ride.averageHeartRate > 0 ? ride.averageHeartRate : 135.0
    let correctedCalories = profile.calculateCalories(averageHeartRate: hrForCalc, durationMinutes: durationMinutes)

    print("   Corrected Calories: \(String(format: "%.0f", correctedCalories))")
    print("   Difference: \(String(format: "%.0f", correctedCalories - ride.calories))")
}

print("\n⚠️  This script is read-only. To fix the rides, we need to add an update method to RideHistory.")
print("Run this from Xcode or the app itself to make changes.")
