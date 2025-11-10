import Foundation

struct UserProfile: Codable {
    var birthday: Date
    var weight: Double // in lbs
    var gender: Gender
    var heightInches: Int? // Optional for BMI calculations later
    var lactateThresholdHR: Int? // LTHR for zone calculations
    var maxHeartRate: Int? // Max HR (optional - can be estimated)

    enum Gender: String, Codable, CaseIterable {
        case male = "Male"
        case female = "Female"
    }

    // Calculate current age from birthday
    var age: Int {
        let calendar = Calendar.current
        let now = Date()
        let ageComponents = calendar.dateComponents([.year], from: birthday, to: now)
        return ageComponents.year ?? 0
    }

    // Convert weight to kg for calculations
    var weightKg: Double {
        weight * 0.453592
    }

    // Estimated max heart rate (220 - age formula)
    var estimatedMaxHR: Int {
        maxHeartRate ?? (220 - age)
    }

    // Heart rate zones based on LTHR (Lactate Threshold HR)
    var hrZones: HeartRateZones? {
        guard let lthr = lactateThresholdHR else { return nil }
        return HeartRateZones(lthr: lthr)
    }

    // Default profile (30 years old from today)
    static var `default`: UserProfile {
        let calendar = Calendar.current
        let thirtyYearsAgo = calendar.date(byAdding: .year, value: -30, to: Date()) ?? Date()
        return UserProfile(birthday: thirtyYearsAgo, weight: 170, gender: .male, heightInches: 70)
    }

    // Calculate calories burned using heart rate formula (Keytel et al.)
    func calculateCalories(averageHeartRate: Double, durationMinutes: Double) -> Double {
        guard durationMinutes > 0, averageHeartRate > 0 else { return 0 }

        switch gender {
        case .male:
            // Men: Calories/min = (-55.0969 + (0.6309 × HR) + (0.1988 × Weight_kg) + (0.2017 × Age)) / 4.184
            let caloriesPerMinute = ((-55.0969) + (0.6309 * averageHeartRate) + (0.1988 * weightKg) + (0.2017 * Double(age))) / 4.184
            let calories = caloriesPerMinute * durationMinutes
            return max(0, calories)

        case .female:
            // Women: Calories/min = (-20.4022 + (0.4472 × HR) + (0.1263 × Weight_kg) + (0.074 × Age)) / 4.184
            let caloriesPerMinute = ((-20.4022) + (0.4472 * averageHeartRate) + (0.1263 * weightKg) + (0.074 * Double(age))) / 4.184
            let calories = caloriesPerMinute * durationMinutes
            return max(0, calories)
        }
    }
}

// UserDefaults storage
extension UserProfile {
    private static let profileKey = "UserProfile"

    static func load() -> UserProfile {
        guard let data = UserDefaults.standard.data(forKey: profileKey),
              let profile = try? JSONDecoder().decode(UserProfile.self, from: data) else {
            return .default
        }
        return profile
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: UserProfile.profileKey)
        }
    }
}
