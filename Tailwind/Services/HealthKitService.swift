import Foundation
import HealthKit
import Combine

class HealthKitService: ObservableObject {
    private let healthStore = HKHealthStore()
    @Published var isAuthorized = false

    // Health data types we want to write
    private let typesToWrite: Set<HKSampleType> = [
        HKObjectType.workoutType(),
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKObjectType.quantityType(forIdentifier: .distanceCycling)!,
        HKObjectType.quantityType(forIdentifier: .heartRate)!
    ]

    // Health data types we want to read (optional, for future features)
    private let typesToRead: Set<HKObjectType> = [
        HKObjectType.workoutType(),
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKObjectType.quantityType(forIdentifier: .distanceCycling)!,
        HKObjectType.quantityType(forIdentifier: .heartRate)!
    ]

    init() {
        checkAuthorization()
    }

    // Check if HealthKit is available
    var isHealthKitAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // Request authorization
    func requestAuthorization() async throws {
        guard isHealthKitAvailable else {
            throw HealthKitError.notAvailable
        }

        try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)

        await MainActor.run {
            checkAuthorization()
        }
    }

    // Check current authorization status
    private func checkAuthorization() {
        guard isHealthKitAvailable else {
            isAuthorized = false
            return
        }

        // Check if we have authorization for workout type
        let workoutType = HKObjectType.workoutType()
        let status = healthStore.authorizationStatus(for: workoutType)

        isAuthorized = (status == .sharingAuthorized)
    }

    // Save a completed ride to HealthKit
    func saveRide(_ ride: Ride) async throws {
        guard isHealthKitAvailable && isAuthorized else {
            throw HealthKitError.notAuthorized
        }

        let startDate = ride.date
        let endDate = ride.date.addingTimeInterval(ride.duration)

        if #available(iOS 17.0, *) {
            // Use modern HKWorkoutBuilder API
            let configuration = HKWorkoutConfiguration()
            configuration.activityType = .cycling
            configuration.locationType = .outdoor

            let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: .local())

            // Start building
            try await builder.beginCollection(at: startDate)

            // Add heart rate samples if we have HR data
            if ride.averageHeartRate > 0 {
                let heartRateSamples = createHeartRateSamples(for: ride)
                try await builder.addSamples(heartRateSamples)
            }

            // Add distance sample
            let distanceSample = HKQuantitySample(
                type: HKQuantityType.quantityType(forIdentifier: .distanceCycling)!,
                quantity: HKQuantity(unit: .mile(), doubleValue: ride.distance),
                start: startDate,
                end: endDate
            )
            try await builder.addSamples([distanceSample])

            // Add calories sample
            let caloriesSample = HKQuantitySample(
                type: HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
                quantity: HKQuantity(unit: .kilocalorie(), doubleValue: ride.calories),
                start: startDate,
                end: endDate
            )
            try await builder.addSamples([caloriesSample])

            // Add metadata
            try await builder.addMetadata([
                HKMetadataKeyIndoorWorkout: false,
                "Tailwind": true,
                "AverageSpeed": ride.averageSpeed,
                "MaxSpeed": ride.maxSpeed,
                "AverageHeartRate": ride.averageHeartRate,
                "MaxHeartRate": ride.maxHeartRate
            ])

            // Finish building
            try await builder.endCollection(at: endDate)
            _ = try await builder.finishWorkout()

            print("✅ Saved ride to HealthKit: \(ride.distance) mi, \(ride.calories) cal")
        } else {
            // Fallback for iOS 16 and earlier
            let workout = HKWorkout(
                activityType: .cycling,
                start: startDate,
                end: endDate,
                duration: ride.duration,
                totalEnergyBurned: HKQuantity(unit: .kilocalorie(), doubleValue: ride.calories),
                totalDistance: HKQuantity(unit: .mile(), doubleValue: ride.distance),
                metadata: [
                    HKMetadataKeyIndoorWorkout: false,
                    "Tailwind": true,
                    "AverageSpeed": ride.averageSpeed,
                    "MaxSpeed": ride.maxSpeed,
                    "AverageHeartRate": ride.averageHeartRate,
                    "MaxHeartRate": ride.maxHeartRate
                ]
            )

            try await healthStore.save(workout)

            var samples: [HKSample] = []

            if ride.averageHeartRate > 0 {
                let heartRateSamples = createHeartRateSamples(for: ride)
                samples.append(contentsOf: heartRateSamples)
            }

            let distanceSample = HKQuantitySample(
                type: HKQuantityType.quantityType(forIdentifier: .distanceCycling)!,
                quantity: HKQuantity(unit: .mile(), doubleValue: ride.distance),
                start: startDate,
                end: endDate
            )
            samples.append(distanceSample)

            let caloriesSample = HKQuantitySample(
                type: HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
                quantity: HKQuantity(unit: .kilocalorie(), doubleValue: ride.calories),
                start: startDate,
                end: endDate
            )
            samples.append(caloriesSample)

            for sample in samples {
                try await healthStore.save(sample)
            }

            print("✅ Saved ride to HealthKit: \(ride.distance) mi, \(ride.calories) cal")
        }
    }

    // Create heart rate samples distributed across the ride
    private func createHeartRateSamples(for ride: Ride) -> [HKQuantitySample] {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        var samples: [HKQuantitySample] = []

        // Create samples every 5 minutes
        let sampleInterval: TimeInterval = 300 // 5 minutes
        let numberOfSamples = max(1, Int(ride.duration / sampleInterval))

        for i in 0..<numberOfSamples {
            let timestamp = ride.date.addingTimeInterval(Double(i) * sampleInterval)

            // Vary heart rate slightly around average for more realistic data
            let variation = Double.random(in: -5...5)
            let heartRate = max(60, min(200, ride.averageHeartRate + variation))

            let sample = HKQuantitySample(
                type: heartRateType,
                quantity: HKQuantity(unit: HKUnit.count().unitDivided(by: .minute()), doubleValue: heartRate),
                start: timestamp,
                end: timestamp
            )
            samples.append(sample)
        }

        return samples
    }

    // Update a ride in HealthKit (delete old workout and save corrected version)
    func updateRide(_ ride: Ride) async throws {
        guard isHealthKitAvailable && isAuthorized else {
            throw HealthKitError.notAuthorized
        }

        // First, delete the old workout
        try await deleteRide(ride)

        // Then save the corrected version
        try await saveRide(ride)

        print("✅ Updated ride in HealthKit: \(ride.distance) mi, \(ride.calories) cal")
    }

    // Delete a ride from HealthKit (if user deletes from ride history)
    func deleteRide(_ ride: Ride) async throws {
        guard isHealthKitAvailable && isAuthorized else { return }

        // Query for workouts matching this ride
        let workoutPredicate = HKQuery.predicateForWorkouts(with: .cycling)
        let datePredicate = HKQuery.predicateForSamples(
            withStart: ride.date,
            end: ride.date.addingTimeInterval(ride.duration + 60), // Add 1 min buffer
            options: .strictStartDate
        )

        let compound = NSCompoundPredicate(andPredicateWithSubpredicates: [workoutPredicate, datePredicate])

        let workouts = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKWorkout], Error>) in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: compound,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples as? [HKWorkout] ?? [])
                }
            }
            healthStore.execute(query)
        }

        // Delete matching workouts
        for workout in workouts {
            try await healthStore.delete(workout)
        }

        print("🗑️ Deleted ride from HealthKit")
    }

    // MARK: - Import Workouts

    // Fetch cycling workouts from HealthKit
    func fetchCyclingWorkouts(from startDate: Date, to endDate: Date) async throws -> [HKWorkout] {
        guard isHealthKitAvailable else {
            throw HealthKitError.notAvailable
        }

        let workoutPredicate = HKQuery.predicateForWorkouts(with: .cycling)
        let datePredicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        let compound = NSCompoundPredicate(andPredicateWithSubpredicates: [workoutPredicate, datePredicate])

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKWorkout], Error>) in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: compound,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples as? [HKWorkout] ?? [])
                }
            }
            healthStore.execute(query)
        }
    }

    // Import a HealthKit workout as a Ride
    func importWorkout(_ workout: HKWorkout) async throws -> Ride {
        // Get heart rate data for this workout
        let heartRateData = try await fetchHeartRateData(for: workout)

        // Load user profile for threshold HR
        let userProfile = UserProfile.load()

        // Convert to Ride
        let distance = workout.totalDistance?.doubleValue(for: .mile()) ?? 0.0

        // Get calories - handle iOS 18 deprecation
        let calories: Double
        if #available(iOS 18.0, *) {
            if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
               let stat = workout.statistics(for: energyType) {
                calories = stat.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0.0
            } else {
                calories = 0.0
            }
        } else {
            calories = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0.0
        }

        let duration = workout.duration

        let averageSpeed = duration > 0 ? (distance / duration) * 3600 : 0.0 // mph
        let maxSpeed = (workout.metadata?["MaxSpeed"] as? Double) ?? averageSpeed

        // Calculate simplified TSS based on average HR and duration using user's threshold HR
        let hrTSS: Double?
        if heartRateData.average > 0 && duration > 0,
           let thresholdHR = userProfile.lactateThresholdHR {
            let hrIntensity = heartRateData.average / Double(thresholdHR)
            let hours = duration / 3600.0
            hrTSS = hours * hrIntensity * hrIntensity * 100 // TSS = hours × IF² × 100
            print("📊 Calculated TSS: \(String(format: "%.1f", hrTSS ?? 0)) (HR: \(String(format: "%.0f", heartRateData.average)) / LTHR: \(thresholdHR))")
        } else {
            hrTSS = nil
            if userProfile.lactateThresholdHR == nil {
                print("⚠️ No threshold HR in profile - TSS not calculated")
            }
        }

        // Check if indoor workout (Peloton, etc.)
        let isIndoor = workout.metadata?[HKMetadataKeyIndoorWorkout] as? Bool ?? false
        let workoutSource = isIndoor ? "Indoor Cycling" : "Apple Workouts"

        let ride = Ride(
            id: UUID(),
            date: workout.startDate,
            duration: duration,
            distance: distance,
            averageSpeed: averageSpeed,
            maxSpeed: maxSpeed,
            averageHeartRate: heartRateData.average,
            maxHeartRate: Int(heartRateData.max), // Convert Double to Int
            calories: calories,
            elevationGain: nil,
            routeCoordinates: nil,
            notes: "Imported from \(workoutSource)",
            bikeName: nil,
            bikeType: nil,
            timeInZone: nil,
            hrTSS: hrTSS
        )

        print("✅ Imported workout: \(distance) mi, \(duration)s, \(heartRateData.average) bpm avg")
        return ride
    }

    // Fetch heart rate data for a specific workout
    private func fetchHeartRateData(for workout: HKWorkout) async throws -> (average: Double, max: Double) {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!

        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )

        let samples: [HKQuantitySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples as? [HKQuantitySample] ?? [])
                }
            }
            healthStore.execute(query)
        }

        guard !samples.isEmpty else {
            return (0, 0)
        }

        let heartRates = samples.map { $0.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) }
        let average = heartRates.reduce(0, +) / Double(heartRates.count)
        let max = heartRates.max() ?? 0

        return (average, max)
    }
}

// MARK: - Errors
enum HealthKitError: LocalizedError {
    case notAvailable
    case notAuthorized

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device"
        case .notAuthorized:
            return "HealthKit access not authorized. Please enable in Settings."
        }
    }
}
