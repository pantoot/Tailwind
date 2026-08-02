import Foundation
import HealthKit
import Combine
import CoreLocation

class HealthKitService: ObservableObject {
    private let healthStore = HKHealthStore()
    @Published var isAuthorized = false

    // Health data types we want to write
    private let typesToWrite: Set<HKSampleType> = [
        HKObjectType.workoutType(),
        HKSeriesType.workoutRoute(),
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKObjectType.quantityType(forIdentifier: .distanceCycling)!,
        HKObjectType.quantityType(forIdentifier: .heartRate)!
    ]

    // Health data types we want to read (optional, for future features)
    private let typesToRead: Set<HKObjectType> = [
        HKObjectType.workoutType(),
        HKSeriesType.workoutRoute(),
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKObjectType.quantityType(forIdentifier: .distanceCycling)!,
        HKObjectType.quantityType(forIdentifier: .heartRate)!,
        HKObjectType.quantityType(forIdentifier: .cyclingPower)!,
        HKObjectType.quantityType(forIdentifier: .cyclingFunctionalThresholdPower)!,
        HKObjectType.quantityType(forIdentifier: .bodyMass)!,
        HKObjectType.quantityType(forIdentifier: .leanBodyMass)!,
        HKObjectType.quantityType(forIdentifier: .bodyFatPercentage)!
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
                limit: 10, // Should only be 1-2 matches, but limit to 10 for safety
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

    // MARK: - Delete Tailwind Workouts

    /// Delete all Tailwind-created workouts for a given day from HealthKit.
    /// These are the Move-ring duplicate workouts with metadata["Tailwind"] == true.
    func deleteTailwindWorkouts(for date: Date) async throws -> Int {
        guard isHealthKitAvailable && isAuthorized else {
            throw HealthKitError.notAuthorized
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let workoutPredicate = HKQuery.predicateForWorkouts(with: .cycling)
        let datePredicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: endOfDay,
            options: .strictStartDate
        )
        let compound = NSCompoundPredicate(andPredicateWithSubpredicates: [workoutPredicate, datePredicate])

        let workouts: [HKWorkout] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: compound,
                limit: 50,
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

        // Filter to Tailwind-created workouts only
        let tailwindWorkouts = workouts.filter { workout in
            workout.metadata?["Tailwind"] as? Bool == true
        }

        for workout in tailwindWorkouts {
            try await healthStore.delete(workout)
        }

        if !tailwindWorkouts.isEmpty {
            print("🗑️ Deleted \(tailwindWorkouts.count) Tailwind workouts from HealthKit for \(date)")
        }
        return tailwindWorkouts.count
    }

    // MARK: - Import Workouts

    // Fetch cycling workouts from HealthKit (limited to 100 most recent to prevent memory issues)
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
                limit: 100, // Limit to 100 workouts to prevent memory issues
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
    // Set writeActiveEnergy: true to also write a standalone Active Energy sample (helps with Move ring)
    func importWorkout(_ workout: HKWorkout, writeActiveEnergy: Bool = true) async throws -> Ride {
        // Get heart rate data for this workout
        let heartRateData = try await fetchHeartRateData(for: workout)

        // Try to fetch route data from HealthKit
        let routeCoordinates = await fetchRouteData(for: workout)

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

        // Fetch power and HR samples for creatine analysis (Peloton, Zwift, etc.)
        let powerSamples = await fetchPowerSamples(for: workout)
        let creatineMetrics: CreatineMetrics?
        if !powerSamples.isEmpty {
            let hrSamples = await fetchHeartRateSamplesForWorkout(workout)
            // No speed data from indoor workouts, pass empty array
            creatineMetrics = CreatineAnalysisService.analyze(
                power: powerSamples,
                heartRate: hrSamples,
                speed: [],
                rideStart: workout.startDate,
                settings: CreatineSettings.load()
            )
            if let cm = creatineMetrics {
                print("⚡ HealthKit power analysis: \(powerSamples.count) samples, 30s max=\(String(format: "%.0f", cm.max30sPower))W, \(cm.matchCount) matches")
            }
        } else {
            creatineMetrics = nil
        }

        let ride = Ride(
            id: UUID(),
            date: workout.startDate,
            duration: duration,
            distance: distance,
            averageSpeed: averageSpeed,
            maxSpeed: maxSpeed,
            averageHeartRate: heartRateData.average,
            maxHeartRate: Int(heartRateData.max),
            calories: calories,
            averagePower: creatineMetrics?.averagePower,
            averageCadence: nil,
            elevationGain: nil,
            routeCoordinates: routeCoordinates,
            notes: "Imported from \(workoutSource)",
            bikeName: nil,
            bikeType: nil,
            timeInZone: nil,
            hrTSS: hrTSS,
            creatineMetrics: creatineMetrics
        )

        // Create a Tailwind workout with Active Energy for Move ring credit
        // Third-party apps like Peloton often write calories only as workout metadata,
        // which Apple's Move ring ignores. Creating a proper workout fixes this.
        if writeActiveEnergy && calories > 0 {
            let configuration = HKWorkoutConfiguration()
            configuration.activityType = .cycling
            configuration.locationType = isIndoor ? .indoor : .outdoor

            let builder = HKWorkoutBuilder(
                healthStore: healthStore,
                configuration: configuration,
                device: .local()
            )

            try await builder.beginCollection(at: workout.startDate)

            let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
            let caloriesSample = HKQuantitySample(
                type: activeEnergyType,
                quantity: HKQuantity(unit: .kilocalorie(), doubleValue: calories),
                start: workout.startDate,
                end: workout.endDate
            )
            try await builder.addSamples([caloriesSample])

            if distance > 0 {
                let distanceSample = HKQuantitySample(
                    type: HKQuantityType.quantityType(forIdentifier: .distanceCycling)!,
                    quantity: HKQuantity(unit: .mile(), doubleValue: distance),
                    start: workout.startDate,
                    end: workout.endDate
                )
                try await builder.addSamples([distanceSample])
            }

            try await builder.addMetadata([
                HKMetadataKeyIndoorWorkout: isIndoor,
                "Tailwind": true,
                "ImportedFrom": workoutSource
            ])

            try await builder.endCollection(at: workout.endDate)
            _ = try await builder.finishWorkout()

            print("🔥 Created workout for Move ring: \(Int(calories)) kcal")
        }

        print("✅ Imported workout: \(distance) mi, \(duration)s, \(heartRateData.average) bpm avg, \(Int(calories)) kcal")
        return ride
    }

    /// Write a workout with Active Energy sample for a ride (fixes Move ring for third-party workouts)
    /// Creates a full HKWorkout which Move ring respects, not just a standalone sample
    func writeActiveEnergy(for ride: Ride) async throws {
        guard isHealthKitAvailable else {
            throw HealthKitError.notAvailable
        }

        guard ride.calories > 0 else {
            print("⚠️ No calories to write for ride")
            return
        }

        let endDate = ride.date.addingTimeInterval(ride.duration)

        // Create a workout (Move ring respects workouts, not standalone samples)
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .cycling
        configuration.locationType = (ride.routeCoordinates?.isEmpty ?? true) ? .indoor : .outdoor

        let builder = HKWorkoutBuilder(
            healthStore: healthStore,
            configuration: configuration,
            device: .local()
        )

        try await builder.beginCollection(at: ride.date)

        // Add Active Energy sample
        let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        let caloriesSample = HKQuantitySample(
            type: activeEnergyType,
            quantity: HKQuantity(unit: .kilocalorie(), doubleValue: ride.calories),
            start: ride.date,
            end: endDate
        )
        try await builder.addSamples([caloriesSample])

        // Add distance if available
        if ride.distance > 0 {
            let distanceSample = HKQuantitySample(
                type: HKQuantityType.quantityType(forIdentifier: .distanceCycling)!,
                quantity: HKQuantity(unit: .mile(), doubleValue: ride.distance),
                start: ride.date,
                end: endDate
            )
            try await builder.addSamples([distanceSample])
        }

        // Add metadata
        try await builder.addMetadata([
            HKMetadataKeyIndoorWorkout: (ride.routeCoordinates?.isEmpty ?? true),
            "Tailwind": true,
            "MoveRingFix": true
        ])

        try await builder.endCollection(at: endDate)
        let workout = try await builder.finishWorkout()

        print("🔥 Created workout with Active Energy: \(Int(ride.calories)) kcal for Move ring")
        print("   Workout ID: \(workout?.uuid.uuidString ?? "unknown")")
    }

    // MARK: - Manual Workout Entry

    /// Creates a cycling workout in HealthKit from manually entered data (e.g. Peloton ride that failed to sync)
    /// Returns a Ride object for Tailwind's ride history
    func createManualWorkout(
        startDate: Date,
        duration: TimeInterval,
        calories: Double,
        distance: Double, // miles
        averagePower: Double?, // watts
        averageHeartRate: Double?,
        maxHeartRate: Int?,
        averageCadence: Double?,
        averageSpeed: Double?, // mph
        maxSpeed: Double? = nil, // mph
        notes: String?
    ) async throws -> Ride {
        guard isHealthKitAvailable else {
            throw HealthKitError.notAvailable
        }

        try await requestAuthorization()

        let endDate = startDate.addingTimeInterval(duration)
        let speed = averageSpeed ?? (duration > 0 ? (distance / duration) * 3600 : 0)
        let peakSpeed = maxSpeed ?? speed

        // Calculate TSS from power if FTP is set, otherwise from HR
        let userProfile = UserProfile.load()
        let hrTSS: Double?
        if let avgPower = averagePower, let ftp = userProfile.ftp, ftp > 0 {
            // Power-based TSS: (seconds × (avgPower/FTP)²) / 36
            let intensityFactor = avgPower / Double(ftp)
            hrTSS = (duration * intensityFactor * intensityFactor) / 36.0
            print("📊 Power TSS: \(String(format: "%.1f", hrTSS!)) (IF=\(String(format: "%.2f", intensityFactor)))")
        } else if let avgHR = averageHeartRate, avgHR > 0,
                  let lthr = userProfile.lactateThresholdHR {
            let hrIntensity = avgHR / Double(lthr)
            hrTSS = (duration / 3600.0) * hrIntensity * hrIntensity * 100
        } else {
            hrTSS = nil
        }

        // Build HealthKit workout
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .cycling
        configuration.locationType = .indoor

        let builder = HKWorkoutBuilder(
            healthStore: healthStore,
            configuration: configuration,
            device: .local()
        )

        try await builder.beginCollection(at: startDate)

        // Active Energy (required for Move ring)
        let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        let caloriesSample = HKQuantitySample(
            type: activeEnergyType,
            quantity: HKQuantity(unit: .kilocalorie(), doubleValue: calories),
            start: startDate,
            end: endDate
        )
        try await builder.addSamples([caloriesSample])

        // Distance
        if distance > 0 {
            let distanceSample = HKQuantitySample(
                type: HKQuantityType.quantityType(forIdentifier: .distanceCycling)!,
                quantity: HKQuantity(unit: .mile(), doubleValue: distance),
                start: startDate,
                end: endDate
            )
            try await builder.addSamples([distanceSample])
        }

        // Metadata
        try await builder.addMetadata([
            HKMetadataKeyIndoorWorkout: true,
            "Tailwind": true,
            "ManualEntry": true
        ])

        try await builder.endCollection(at: endDate)
        let workout = try await builder.finishWorkout()
        print("🔥 Manual workout created: \(Int(calories)) kcal, \(String(format: "%.1f", distance)) mi")
        print("   Workout ID: \(workout?.uuid.uuidString ?? "unknown")")

        let ride = Ride(
            id: UUID(),
            date: startDate,
            duration: duration,
            distance: distance,
            averageSpeed: speed,
            maxSpeed: peakSpeed,
            averageHeartRate: averageHeartRate ?? 0,
            maxHeartRate: maxHeartRate ?? 0,
            calories: calories,
            averagePower: averagePower,
            averageCadence: averageCadence,
            elevationGain: nil,
            routeCoordinates: nil,
            notes: notes ?? "Manual entry (Peloton sync fix)",
            bikeName: nil,
            bikeType: nil,
            timeInZone: nil,
            hrTSS: hrTSS,
            creatineMetrics: nil
        )

        return ride
    }

    // MARK: - HealthKit Diagnostics

    struct WorkoutDiagnostic: Identifiable {
        let id = UUID()
        let source: String
        let bundleId: String
        let activityType: String
        let startTime: Date
        let endTime: Date
        let duration: TimeInterval
        let calories: Double
        let distance: Double // miles
        let hasTailwindMeta: Bool
    }

    /// Fetch ALL workouts for a given date from all sources — useful for diagnosing sync issues
    func diagnoseWorkouts(for date: Date) async throws -> [WorkoutDiagnostic] {
        guard isHealthKitAvailable else {
            throw HealthKitError.notAvailable
        }

        try await requestAuthorization()

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let datePredicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: endOfDay,
            options: .strictStartDate
        )

        let workouts: [HKWorkout] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: datePredicate,
                limit: 200,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples as? [HKWorkout] ?? [])
                }
            }
            healthStore.execute(query)
        }

        return workouts.map { workout in
            let activityName: String
            switch workout.workoutActivityType {
            case .cycling: activityName = "Cycling"
            case .running: activityName = "Running"
            case .walking: activityName = "Walking"
            case .yoga: activityName = "Yoga"
            case .functionalStrengthTraining: activityName = "Strength"
            case .cooldown: activityName = "Cooldown"
            case .highIntensityIntervalTraining: activityName = "HIIT"
            default: activityName = "Other (\(workout.workoutActivityType.rawValue))"
            }

            let calories: Double
            if #available(iOS 18.0, *) {
                if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
                   let stat = workout.statistics(for: energyType) {
                    calories = stat.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                } else {
                    calories = 0
                }
            } else {
                calories = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0
            }

            let distance = workout.totalDistance?.doubleValue(for: .mile()) ?? 0

            return WorkoutDiagnostic(
                source: workout.sourceRevision.source.name,
                bundleId: workout.sourceRevision.source.bundleIdentifier,
                activityType: activityName,
                startTime: workout.startDate,
                endTime: workout.endDate,
                duration: workout.duration,
                calories: calories,
                distance: distance,
                hasTailwindMeta: workout.metadata?["Tailwind"] as? Bool ?? false
            )
        }
    }

    // MARK: - Heart Rate Data Fetching

    /// Fetch detailed heart rate samples for a time range (for merging Watch HR into imported rides)
    /// Returns samples at ~5 second intervals to match FIT import resolution
    func fetchHeartRateSamples(from startDate: Date, to endDate: Date) async throws -> [(date: Date, bpm: Double)] {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        let samples: [HKQuantitySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, results, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: results as? [HKQuantitySample] ?? [])
                }
            }
            healthStore.execute(query)
        }

        let hrUnit = HKUnit.count().unitDivided(by: .minute())

        // Downsample to ~5 second intervals to match FIT import
        var result: [(date: Date, bpm: Double)] = []
        var lastSampleTime: Date?
        let downsampleInterval: TimeInterval = 5.0

        for sample in samples {
            let shouldInclude: Bool
            if let last = lastSampleTime {
                shouldInclude = sample.startDate.timeIntervalSince(last) >= downsampleInterval
            } else {
                shouldInclude = true
            }

            if shouldInclude {
                let bpm = sample.quantity.doubleValue(for: hrUnit)
                // Filter valid HR range
                if bpm > 30 && bpm < 250 {
                    result.append((date: sample.startDate, bpm: bpm))
                    lastSampleTime = sample.startDate
                }
            }
        }

        print("❤️ Fetched \(result.count) HR samples from HealthKit (from \(samples.count) total)")
        return result
    }

    // Fetch heart rate data for a specific workout using statistics (memory efficient)
    // Returns (0, 0) if no HR data available - does not throw
    private func fetchHeartRateData(for workout: HKWorkout) async throws -> (average: Double, max: Double) {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!

        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )

        // Use statistics query instead of fetching all samples - much more memory efficient
        // Catch "no data" errors and return zeros instead of throwing
        do {
            let statistics = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HKStatistics?, Error>) in
                let query = HKStatisticsQuery(
                    quantityType: heartRateType,
                    quantitySamplePredicate: predicate,
                    options: [.discreteAverage, .discreteMax]
                ) { _, statistics, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: statistics)
                    }
                }
                healthStore.execute(query)
            }

            guard let stats = statistics else {
                return (0, 0)
            }

            let hrUnit = HKUnit.count().unitDivided(by: .minute())
            let average = stats.averageQuantity()?.doubleValue(for: hrUnit) ?? 0
            let max = stats.maximumQuantity()?.doubleValue(for: hrUnit) ?? 0

            return (average, max)
        } catch {
            // "No data available for the specified predicate" is common for workouts without HR
            print("⚠️ No HR data for workout on \(workout.startDate): \(error.localizedDescription)")
            return (0, 0)
        }
    }

    /// Fetch timestamped power samples for a workout (Peloton, Zwift, etc. write these to HealthKit)
    private func fetchPowerSamples(for workout: HKWorkout) async -> [(date: Date, watts: Double)] {
        let powerType = HKQuantityType.quantityType(forIdentifier: .cyclingPower)!
        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )

        do {
            let samples: [HKQuantitySample] = try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: powerType,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
                ) { _, results, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: results as? [HKQuantitySample] ?? [])
                    }
                }
                healthStore.execute(query)
            }

            let wattUnit = HKUnit.watt()
            return samples.map { sample in
                (date: sample.startDate, watts: sample.quantity.doubleValue(for: wattUnit))
            }
        } catch {
            print("⚠️ No power data for workout: \(error.localizedDescription)")
            return []
        }
    }

    /// Fetch timestamped HR samples for a workout (needed for creatine HR recovery analysis)
    private func fetchHeartRateSamplesForWorkout(_ workout: HKWorkout) async -> [(date: Date, bpm: Double)] {
        let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )

        do {
            let samples: [HKQuantitySample] = try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: hrType,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
                ) { _, results, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: results as? [HKQuantitySample] ?? [])
                    }
                }
                healthStore.execute(query)
            }

            let bpmUnit = HKUnit.count().unitDivided(by: .minute())
            return samples.map { sample in
                (date: sample.startDate, bpm: sample.quantity.doubleValue(for: bpmUnit))
            }
        } catch {
            print("⚠️ No HR samples for workout: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - FTP

    /// Fetch the most recent FTP value from HealthKit (written by Peloton, Apple Watch, etc.)
    func fetchFTP() async -> Double? {
        let ftpType = HKQuantityType.quantityType(forIdentifier: .cyclingFunctionalThresholdPower)!

        do {
            let sample: HKQuantitySample? = try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: ftpType,
                    predicate: nil,
                    limit: 1,
                    sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
                ) { _, results, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: results?.first as? HKQuantitySample)
                    }
                }
                healthStore.execute(query)
            }

            if let sample = sample {
                let watts = sample.quantity.doubleValue(for: .watt())
                let date = sample.startDate
                print("⚡ Found FTP in HealthKit: \(Int(watts))W (from \(date))")
                return watts
            }

            print("⚡ No FTP found in HealthKit")
            return nil
        } catch {
            print("⚠️ Failed to fetch FTP: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Body Mass (Weight)

    /// Fetch body mass samples from HealthKit (Withings scale, manual entries, etc.)
    /// Returns entries sorted newest-first, capped at 365 days.
    func fetchWeightSamples(days: Int = 365) async -> [(date: Date, lbs: Double)] {
        let bodyMassType = HKQuantityType.quantityType(forIdentifier: .bodyMass)!
        let endDate = Date()
        guard let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate) else { return [] }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        do {
            let samples: [HKQuantitySample] = try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: bodyMassType,
                    predicate: predicate,
                    limit: 1000,
                    sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
                ) { _, results, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: results as? [HKQuantitySample] ?? [])
                    }
                }
                healthStore.execute(query)
            }

            let lbsUnit = HKUnit.pound()
            let result = samples.map { sample in
                (date: sample.startDate, lbs: sample.quantity.doubleValue(for: lbsUnit))
            }
            print("⚖️ Fetched \(result.count) weight samples from HealthKit")
            return result
        } catch {
            print("⚠️ Failed to fetch weight data: \(error.localizedDescription)")
            return []
        }
    }

    /// Fetch lean body mass samples from HealthKit (Withings scale).
    func fetchLeanBodyMassSamples(days: Int = 365) async -> [(date: Date, lbs: Double)] {
        let leanType = HKQuantityType.quantityType(forIdentifier: .leanBodyMass)!
        let endDate = Date()
        guard let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate) else { return [] }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        do {
            let samples: [HKQuantitySample] = try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: leanType,
                    predicate: predicate,
                    limit: 1000,
                    sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
                ) { _, results, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: results as? [HKQuantitySample] ?? [])
                    }
                }
                healthStore.execute(query)
            }

            let lbsUnit = HKUnit.pound()
            let result = samples.map { sample in
                (date: sample.startDate, lbs: sample.quantity.doubleValue(for: lbsUnit))
            }
            print("💪 Fetched \(result.count) lean body mass samples from HealthKit")
            return result
        } catch {
            print("⚠️ Failed to fetch lean body mass: \(error.localizedDescription)")
            return []
        }
    }

    /// Fetch body fat percentage samples from HealthKit (Withings scale).
    func fetchBodyFatSamples(days: Int = 365) async -> [(date: Date, pct: Double)] {
        let fatType = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)!
        let endDate = Date()
        guard let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate) else { return [] }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        do {
            let samples: [HKQuantitySample] = try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: fatType,
                    predicate: predicate,
                    limit: 1000,
                    sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
                ) { _, results, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: results as? [HKQuantitySample] ?? [])
                    }
                }
                healthStore.execute(query)
            }

            // HealthKit stores body fat as a fraction (0.0-1.0), convert to percentage
            let result = samples.map { sample in
                (date: sample.startDate, pct: sample.quantity.doubleValue(for: .percent()) * 100)
            }
            print("📊 Fetched \(result.count) body fat samples from HealthKit")
            return result
        } catch {
            print("⚠️ Failed to fetch body fat: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - LTHR Estimation

    struct LTHREstimate {
        let estimatedLTHR: Int
        let best20MinAvgHR: Double
        let workoutDate: Date
        let workoutDuration: TimeInterval
        let candidates: [LTHRCandidate]  // Top efforts for context
    }

    struct LTHRCandidate {
        let date: Date
        let best20MinHR: Double
        let avgHR: Double
        let maxHR: Double
        let duration: TimeInterval
    }

    /// Estimate LTHR by finding the highest 20-minute rolling average HR across recent cycling workouts.
    /// Returns nil if insufficient data.
    func estimateLTHR(days: Int = 90, progress: @escaping (String) -> Void) async -> LTHREstimate? {
        let endDate = Date()
        guard let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate) else { return nil }

        progress("Fetching cycling workouts...")

        // Fetch cycling workouts
        let workouts: [HKWorkout]
        do {
            workouts = try await fetchCyclingWorkouts(from: startDate, to: endDate)
        } catch {
            print("❌ LTHR estimation: failed to fetch workouts: \(error)")
            return nil
        }

        // Filter to workouts > 20 minutes (need at least 20 min for rolling window)
        // Deduplicate by start time — HealthKit returns the same ride from multiple sources
        let longEnough = workouts.filter { $0.duration >= 1200 } // 20 min
        var seen = Set<Int>() // hash of start time rounded to nearest minute
        let eligible = longEnough.filter { workout in
            let key = Int(workout.startDate.timeIntervalSinceReferenceDate / 60)
            return seen.insert(key).inserted
        }
        guard !eligible.isEmpty else {
            progress("No workouts > 20 min found")
            return nil
        }

        progress("Analyzing \(eligible.count) workouts...")

        var candidates: [LTHRCandidate] = []
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())

        for (i, workout) in eligible.enumerated() {
            progress("Scanning HR in workout \(i + 1) of \(eligible.count)...")

            // Fetch HR samples for this workout (capped)
            let predicate = HKQuery.predicateForSamples(
                withStart: workout.startDate,
                end: workout.endDate,
                options: .strictStartDate
            )
            let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)!

            let hrSamples: [HKQuantitySample]
            do {
                hrSamples = try await withCheckedThrowingContinuation { continuation in
                    let query = HKSampleQuery(
                        sampleType: hrType,
                        predicate: predicate,
                        limit: 10800,
                        sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
                    ) { _, results, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: results as? [HKQuantitySample] ?? [])
                        }
                    }
                    healthStore.execute(query)
                }
            } catch {
                continue
            }

            guard hrSamples.count >= 20 else { continue }

            // Build dense 1-second HR array for this workout
            let bpmValues = hrSamples.map { $0.quantity.doubleValue(for: bpmUnit) }
            let timestamps = hrSamples.map { $0.startDate }

            // Compute the best 20-minute rolling average
            // Use sample-based window (not time-based) since HR samples are ~1/sec from Peloton
            // but may be sparser from Apple Watch (~every 5s)
            let windowSeconds = 1200.0 // 20 minutes
            var best20Min = 0.0

            // Sliding window using timestamps for accuracy
            var windowStart = 0
            var windowSum = 0.0
            var windowCount = 0

            for end in 0..<hrSamples.count {
                windowSum += bpmValues[end]
                windowCount += 1

                // Shrink window from left until it fits within 20 minutes
                while windowStart < end &&
                      timestamps[end].timeIntervalSince(timestamps[windowStart]) > windowSeconds {
                    windowSum -= bpmValues[windowStart]
                    windowCount -= 1
                    windowStart += 1
                }

                // Only consider if window spans at least 18 minutes (allow small gaps)
                let windowDuration = timestamps[end].timeIntervalSince(timestamps[windowStart])
                if windowDuration >= 1080 && windowCount >= 10 {
                    let avg = windowSum / Double(windowCount)
                    if avg > best20Min {
                        best20Min = avg
                    }
                }
            }

            if best20Min > 0 {
                let avgHR = bpmValues.reduce(0, +) / Double(bpmValues.count)
                let maxHR = bpmValues.max() ?? 0

                candidates.append(LTHRCandidate(
                    date: workout.startDate,
                    best20MinHR: best20Min,
                    avgHR: avgHR,
                    maxHR: maxHR,
                    duration: workout.duration
                ))
            }

            // Brief pause between workouts for memory
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        guard !candidates.isEmpty else {
            progress("No usable HR data found")
            return nil
        }

        // Sort by best 20-min HR descending
        candidates.sort { $0.best20MinHR > $1.best20MinHR }

        let best = candidates[0]

        // LTHR estimate: best 20-min average is a good proxy
        // If they did a true 30-min TT, last 20 min avg ≈ LTHR
        // For general rides, best 20-min avg slightly overestimates (adrenaline, drafting)
        // Apply a small 2% discount for non-test conditions
        let estimated = Int(round(best.best20MinHR * 0.98))

        return LTHREstimate(
            estimatedLTHR: estimated,
            best20MinAvgHR: best.best20MinHR,
            workoutDate: best.date,
            workoutDuration: best.duration,
            candidates: Array(candidates.prefix(5))
        )
    }

    /// Quick check: does HealthKit have any power data for this ride's time window?
    func hasPowerData(for ride: Ride) async -> Bool {
        let powerType = HKQuantityType.quantityType(forIdentifier: .cyclingPower)!
        let predicate = HKQuery.predicateForSamples(
            withStart: ride.date,
            end: ride.date.addingTimeInterval(ride.duration),
            options: .strictStartDate
        )

        do {
            let count: Int = try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: powerType,
                    predicate: predicate,
                    limit: 1,
                    sortDescriptors: nil
                ) { _, results, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: results?.count ?? 0)
                    }
                }
                healthStore.execute(query)
            }
            return count > 0
        } catch {
            return false
        }
    }

    /// Reanalyze an existing ride by fetching power + HR samples from HealthKit.
    /// Returns updated CreatineMetrics if power data exists, nil otherwise.
    /// Cap samples at 10800 (3 hours at 1Hz) to prevent memory issues.
    func reanalyzePower(for ride: Ride) async -> CreatineMetrics? {
        let startDate = ride.date
        let endDate = startDate.addingTimeInterval(ride.duration)
        let sampleCap = 10800

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        // Fetch power samples (capped)
        let powerType = HKQuantityType.quantityType(forIdentifier: .cyclingPower)!
        let powerSamples: [(date: Date, watts: Double)]
        do {
            let samples: [HKQuantitySample] = try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: powerType,
                    predicate: predicate,
                    limit: sampleCap,
                    sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
                ) { _, results, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: results as? [HKQuantitySample] ?? [])
                    }
                }
                healthStore.execute(query)
            }
            let wattUnit = HKUnit.watt()
            powerSamples = samples.map { (date: $0.startDate, watts: $0.quantity.doubleValue(for: wattUnit)) }
        } catch {
            return nil
        }

        guard !powerSamples.isEmpty else { return nil }

        // Fetch HR samples (capped)
        let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        var hrSamples: [(date: Date, bpm: Double)] = []
        do {
            let samples: [HKQuantitySample] = try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: hrType,
                    predicate: predicate,
                    limit: sampleCap,
                    sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
                ) { _, results, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: results as? [HKQuantitySample] ?? [])
                    }
                }
                healthStore.execute(query)
            }
            let bpmUnit = HKUnit.count().unitDivided(by: .minute())
            hrSamples = samples.map { (date: $0.startDate, bpm: $0.quantity.doubleValue(for: bpmUnit)) }
        } catch {
            // HR is optional, continue without it
        }

        return CreatineAnalysisService.analyze(
            power: powerSamples,
            heartRate: hrSamples,
            speed: [],
            rideStart: startDate,
            settings: CreatineSettings.load()
        )
    }

    /// Re-fetch HR data from HealthKit for an existing ride and recalculate TSS.
    /// Returns updated (avgHR, maxHR, hrTSS) if HR data is now available, nil otherwise.
    func reanalyzeHR(for ride: Ride) async -> (averageHR: Double, maxHR: Double, hrTSS: Double?)? {
        let startDate = ride.date
        let endDate = startDate.addingTimeInterval(ride.duration)

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!

        do {
            let statistics = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HKStatistics?, Error>) in
                let query = HKStatisticsQuery(
                    quantityType: heartRateType,
                    quantitySamplePredicate: predicate,
                    options: [.discreteAverage, .discreteMax]
                ) { _, statistics, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: statistics)
                    }
                }
                healthStore.execute(query)
            }

            guard let stats = statistics else { return nil }

            let hrUnit = HKUnit.count().unitDivided(by: .minute())
            let avgHR = stats.averageQuantity()?.doubleValue(for: hrUnit) ?? 0
            let maxHR = stats.maximumQuantity()?.doubleValue(for: hrUnit) ?? 0

            guard avgHR > 0 else { return nil }

            let userProfile = UserProfile.load()
            let hrTSS: Double?
            if let thresholdHR = userProfile.lactateThresholdHR, ride.duration > 0 {
                let hrIntensity = avgHR / Double(thresholdHR)
                let hours = ride.duration / 3600.0
                hrTSS = hours * hrIntensity * hrIntensity * 100
                print("📊 Recalculated TSS: \(String(format: "%.1f", hrTSS!)) (HR: \(String(format: "%.0f", avgHR)) / LTHR: \(thresholdHR))")
            } else {
                hrTSS = nil
            }

            return (averageHR: avgHR, maxHR: maxHR, hrTSS: hrTSS)
        } catch {
            print("⚠️ No HR data for ride on \(startDate): \(error.localizedDescription)")
            return nil
        }
    }

    // Fetch route data (GPS coordinates) for a workout from HealthKit
    // Returns nil if no route data available
    private func fetchRouteData(for workout: HKWorkout) async -> [Ride.Coordinate]? {
        // Query for workout routes associated with this workout
        let routeType = HKSeriesType.workoutRoute()
        let predicate = HKQuery.predicateForObjects(from: workout)

        do {
            // First, get the HKWorkoutRoute objects
            let routes: [HKWorkoutRoute] = try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: routeType,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: nil
                ) { _, samples, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: samples as? [HKWorkoutRoute] ?? [])
                    }
                }
                healthStore.execute(query)
            }

            guard let route = routes.first else {
                print("📍 No route data found for workout on \(workout.startDate)")
                return nil
            }

            // Now extract the location data from the route
            let locations: [CLLocation] = try await withCheckedThrowingContinuation { continuation in
                var allLocations: [CLLocation] = []

                let routeQuery = HKWorkoutRouteQuery(route: route) { _, locationsOrNil, done, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }

                    if let newLocations = locationsOrNil {
                        allLocations.append(contentsOf: newLocations)
                    }

                    if done {
                        continuation.resume(returning: allLocations)
                    }
                }
                self.healthStore.execute(routeQuery)
            }

            // Convert to Ride.Coordinate, downsampling to every 5th point to save memory
            let coordinates = locations.enumerated().compactMap { index, location -> Ride.Coordinate? in
                guard index % 5 == 0 else { return nil }
                return Ride.Coordinate(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
            }

            print("📍 Recovered \(coordinates.count) GPS points from HealthKit (from \(locations.count) total)")
            return coordinates.isEmpty ? nil : coordinates

        } catch {
            print("⚠️ Failed to fetch route data: \(error.localizedDescription)")
            return nil
        }
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
