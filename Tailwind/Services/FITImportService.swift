import Foundation
import CoreLocation
import HealthKit
import Combine
import FitFileParser

/// Parsed workout data from a FIT file
struct FITWorkoutData {
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    let distance: Double // meters
    let calories: Double
    let elevationGain: Double? // meters
    let averageTemperature: Double? // Celsius, nil when the head unit had no sensor

    // Detailed samples for HealthKit
    let heartRateSamples: [(date: Date, bpm: Double)]
    let speedSamples: [(date: Date, metersPerSecond: Double)]
    let cadenceSamples: [(date: Date, rpm: Double)]
    let powerSamples: [(date: Date, watts: Double)]
    let coordinates: [(date: Date, coordinate: CLLocationCoordinate2D, altitude: Double?)]

    // Creatine analysis results (computed from raw 1Hz data during import)
    let creatineMetrics: CreatineMetrics?

    // Computed properties
    var distanceMiles: Double { distance * 0.000621371 }
    var elevationGainFeet: Double? { elevationGain.map { $0 * 3.28084 } }

    var averageHeartRate: Double {
        guard !heartRateSamples.isEmpty else { return 0 }
        return heartRateSamples.reduce(0) { $0 + $1.bpm } / Double(heartRateSamples.count)
    }

    var maxHeartRate: Int {
        Int(heartRateSamples.map { $0.bpm }.max() ?? 0)
    }

    var averageSpeedMph: Double {
        guard !speedSamples.isEmpty else {
            // Fallback: calculate from distance and duration
            guard duration > 0 else { return 0 }
            return (distanceMiles / duration) * 3600
        }
        let avgMps = speedSamples.reduce(0) { $0 + $1.metersPerSecond } / Double(speedSamples.count)
        return avgMps * 2.23694 // m/s to mph
    }

    var maxSpeedMph: Double {
        let maxMps = speedSamples.map { $0.metersPerSecond }.max() ?? 0
        return maxMps * 2.23694
    }

    var averageCadence: Double {
        guard !cadenceSamples.isEmpty else { return 0 }
        return cadenceSamples.reduce(0) { $0 + $1.rpm } / Double(cadenceSamples.count)
    }

    var averagePower: Double {
        guard !powerSamples.isEmpty else { return 0 }
        return powerSamples.reduce(0) { $0 + $1.watts } / Double(powerSamples.count)
    }
}

/// Service for importing FIT files and converting to workouts
class FITImportService: ObservableObject {

    enum ImportError: LocalizedError {
        case fileNotFound
        case invalidFormat
        case parsingFailed(String)
        case noWorkoutData

        var errorDescription: String? {
            switch self {
            case .fileNotFound:
                return "FIT file not found"
            case .invalidFormat:
                return "Invalid FIT file format"
            case .parsingFailed(let reason):
                return "Failed to parse FIT file: \(reason)"
            case .noWorkoutData:
                return "No workout data found in FIT file"
            }
        }
    }

    @Published var isImporting = false
    @Published var lastImportedRide: Ride?
    @Published var importError: ImportError?

    private let healthKitService: HealthKitService
    private let rideHistory: RideHistory

    init(healthKitService: HealthKitService, rideHistory: RideHistory) {
        self.healthKitService = healthKitService
        self.rideHistory = rideHistory
    }

    /// Import a FIT file from a URL (e.g., from Share Extension or file picker)
    func importFITFile(from url: URL) async throws -> Ride {
        await MainActor.run { isImporting = true }
        defer { Task { @MainActor in isImporting = false } }

        // Try to access security-scoped resource (for file picker/document provider)
        // This returns false for App Group files, which is fine - they don't need scoping
        let needsSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if needsSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        // Verify file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("❌ FIT file not found at: \(url.path)")
            throw ImportError.fileNotFound
        }
        print("📄 Importing FIT file: \(url.lastPathComponent)")

        // Parse the FIT file
        let workoutData = try parseFITFile(at: url)

        // Convert to Ride model
        let ride = createRide(from: workoutData)

        // Save to HealthKit with detailed samples
        try await saveToHealthKit(workoutData: workoutData, ride: ride)

        // Save to ride history
        await MainActor.run {
            rideHistory.saveRide(ride)
            lastImportedRide = ride
        }

        return ride
    }

    /// Parse a FIT file and extract workout data
    private func parseFITFile(at url: URL) throws -> FITWorkoutData {
        print("📄 FIT: Opening file...")
        guard let fitFile = FitFile(file: url) else {
            throw ImportError.parsingFailed("Could not open FIT file")
        }
        print("📄 FIT: File opened successfully")

        var heartRateSamples: [(date: Date, bpm: Double)] = []
        var speedSamples: [(date: Date, metersPerSecond: Double)] = []
        var coordinates: [(date: Date, coordinate: CLLocationCoordinate2D, altitude: Double?)] = []
        var cadenceSamples: [(date: Date, rpm: Double)] = []
        var powerSamples: [(date: Date, watts: Double)] = []

        var startTime: Date?
        var endTime: Date?
        var totalDistance: Double = 0
        var totalCalories: Double = 0
        var totalAscent: Double = 0

        // Ambient temperature, so outdoor efforts can be compared like with like.
        // A Phoenix ride in June runs 5-11 bpm hotter than the same route in April
        // at identical speed, which otherwise reads as a fitness decline.
        var sessionTemperature: Double?
        var recordTemperatures: [Double] = []

        // Downsample interval: keep every Nth second to reduce memory
        // 5-second intervals still provide good HR graph resolution
        let downsampleInterval: TimeInterval = 5.0
        var lastSampleTime: Date?
        var recordCount = 0

        // Raw 1Hz arrays for creatine analysis (captured before downsample gate)
        var raw1HzPower: [(date: Date, watts: Double)] = []
        var raw1HzHR: [(date: Date, bpm: Double)] = []
        var raw1HzSpeed: [(date: Date, metersPerSecond: Double)] = []

        // Parse record messages (second-by-second data)
        print("📄 FIT: Parsing records...")
        for message in fitFile.messages(forMessageType: .record) {
            recordCount += 1
            let fields = message.interpretedFields()

            // Get timestamp
            guard let timestamp = fields["timestamp"]?.time else { continue }

            if startTime == nil { startTime = timestamp }
            endTime = timestamp

            // Always capture distance (cumulative, need final value)
            if let distanceField = fields["distance"],
               let distance = distanceField.valueUnit?.value {
                totalDistance = distance
            }

            // Capture raw 1Hz data BEFORE downsample gate (for creatine analysis)
            if let powerField = fields["power"],
               let power = powerField.valueUnit?.value {
                raw1HzPower.append((date: timestamp, watts: power))
            }
            if let hrField = fields["heart_rate"],
               let hr = hrField.valueUnit?.value,
               hr > 30 && hr < 250 {
                raw1HzHR.append((date: timestamp, bpm: hr))
            }
            if let speedField = fields["speed"],
               let speed = speedField.valueUnit?.value {
                raw1HzSpeed.append((date: timestamp, metersPerSecond: speed))
            }

            // Downsample: only keep samples every N seconds
            let shouldSample: Bool
            if let last = lastSampleTime {
                shouldSample = timestamp.timeIntervalSince(last) >= downsampleInterval
            } else {
                shouldSample = true
            }

            guard shouldSample else { continue }
            lastSampleTime = timestamp

            // Heart rate - filter out invalid values (0 or 255/0xFF = no sensor)
            if let hrField = fields["heart_rate"],
               let hr = hrField.valueUnit?.value,
               hr > 30 && hr < 250 {  // Valid HR range
                heartRateSamples.append((date: timestamp, bpm: hr))
            }

            // Speed
            if let speedField = fields["speed"],
               let speed = speedField.valueUnit?.value {
                speedSamples.append((date: timestamp, metersPerSecond: speed))
            }

            // Cadence
            if let cadenceField = fields["cadence"],
               let cadence = cadenceField.valueUnit?.value {
                cadenceSamples.append((date: timestamp, rpm: cadence))
            }

            // Power
            if let powerField = fields["power"],
               let power = powerField.valueUnit?.value {
                powerSamples.append((date: timestamp, watts: power))
            }

            // Ambient temperature. Sanity-bounded because a disconnected sensor
            // reports sentinel values rather than nothing.
            if let temperatureField = fields["temperature"],
               let temperature = temperatureField.valueUnit?.value,
               temperature > -30 && temperature < 70 {
                recordTemperatures.append(temperature)
            }

            // GPS position
            if let position = fields["position"]?.coordinate {
                let altitude = fields["altitude"]?.valueUnit?.value
                coordinates.append((date: timestamp, coordinate: position, altitude: altitude))
            }
        }

        // Parse session message for totals
        for message in fitFile.messages(forMessageType: .session) {
            let fields = message.interpretedFields()

            if let caloriesField = fields["total_calories"],
               let calories = caloriesField.valueUnit?.value {
                totalCalories = calories
                print("📊 Parsed calories from FIT session: \(calories) kcal")
            }

            if let ascentField = fields["total_ascent"],
               let ascent = ascentField.valueUnit?.value {
                totalAscent = ascent
            }

            if let temperatureField = fields["avg_temperature"],
               let temperature = temperatureField.valueUnit?.value,
               temperature > -30 && temperature < 70 {
                sessionTemperature = temperature
            }

            // Use session start/end if not found in records
            if startTime == nil, let start = fields["start_time"]?.time {
                startTime = start
            }
            if let end = fields["timestamp"]?.time {
                endTime = end
            }
        }

        print("📄 FIT: Parsed \(recordCount) records (\(raw1HzPower.count) power, \(raw1HzHR.count) HR, \(raw1HzSpeed.count) speed @ 1Hz)")

        guard let start = startTime, let end = endTime else {
            throw ImportError.noWorkoutData
        }

        let duration = end.timeIntervalSince(start)

        // Run creatine analysis on raw 1Hz data
        let creatineMetrics = CreatineAnalysisService.analyze(
            power: raw1HzPower,
            heartRate: raw1HzHR,
            speed: raw1HzSpeed,
            rideStart: start,
            settings: CreatineSettings.load()
        )
        if let cm = creatineMetrics {
            print("⚡ Creatine analysis: 30s max=\(String(format: "%.0f", cm.max30sPower))W, \(cm.matchCount) matches, \(cm.hrRecoveryEvents.count) HR recovery events")
        }

        print("📊 FIT Parse Summary: \(String(format: "%.1f", totalDistance * 0.000621371)) mi, \(Int(totalCalories)) kcal, \(heartRateSamples.count) HR samples (valid), \(String(format: "%.0f", duration/60)) min")
        if heartRateSamples.isEmpty {
            print("⚠️ FIT: No valid heart rate data in file (sensor may have been disconnected)")
        }

        return FITWorkoutData(
            startDate: start,
            endDate: end,
            duration: duration,
            distance: totalDistance,
            calories: totalCalories,
            elevationGain: totalAscent > 0 ? totalAscent : nil,
            averageTemperature: sessionTemperature ?? averageOf(recordTemperatures),
            heartRateSamples: heartRateSamples,
            speedSamples: speedSamples,
            cadenceSamples: cadenceSamples,
            powerSamples: powerSamples,
            coordinates: coordinates,
            creatineMetrics: creatineMetrics
        )
    }

    private func averageOf(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    /// Create a Ride model from parsed FIT data
    private func createRide(from data: FITWorkoutData) -> Ride {
        // Convert coordinates to our Coordinate type
        let routeCoordinates: [Ride.Coordinate]? = data.coordinates.isEmpty ? nil :
            data.coordinates.map { Ride.Coordinate(from: $0.coordinate) }

        // Calculate time in zones and hrTSS from HR samples
        let (timeInZone, hrTSS) = calculateTimeInZones(from: data.heartRateSamples)

        return Ride(
            id: UUID(),
            date: data.startDate,
            duration: data.duration,
            distance: data.distanceMiles,
            averageSpeed: data.averageSpeedMph,
            maxSpeed: data.maxSpeedMph,
            averageHeartRate: data.averageHeartRate,
            maxHeartRate: data.maxHeartRate,
            calories: data.calories,
            elevationGain: data.elevationGainFeet,
            averageTemperatureCelsius: data.averageTemperature,
            routeCoordinates: routeCoordinates,
            notes: "Imported from Magene",
            bikeName: nil,
            bikeType: nil,
            timeInZone: timeInZone,
            hrTSS: hrTSS,
            creatineMetrics: data.creatineMetrics
        )
    }

    /// Merge heart rate data from Apple Watch into an existing ride
    /// Call this when a FIT import has no HR data but the user was wearing their Watch
    func mergeWatchHeartRate(into ride: Ride) async throws -> Ride {
        print("❤️ Fetching Watch HR data for ride on \(ride.formattedDate)...")

        let endDate = ride.date.addingTimeInterval(ride.duration)
        let hrSamples = try await healthKitService.fetchHeartRateSamples(from: ride.date, to: endDate)

        guard !hrSamples.isEmpty else {
            print("⚠️ No Watch HR data found for this time period")
            throw ImportError.parsingFailed("No heart rate data found in HealthKit for this ride's time period. Was your Apple Watch recording?")
        }

        // Calculate stats from samples
        let avgHR = hrSamples.reduce(0.0) { $0 + $1.bpm } / Double(hrSamples.count)
        let maxHR = Int(hrSamples.map { $0.bpm }.max() ?? 0)

        // Calculate time in zones and hrTSS
        let (timeInZone, hrTSS) = calculateTimeInZones(from: hrSamples)

        // Recalculate calories with actual HR data
        let userProfile = UserProfile.load()
        let durationMinutes = ride.duration / 60.0
        let newCalories = userProfile.calculateCalories(averageHeartRate: avgHR, durationMinutes: durationMinutes)

        print("❤️ Watch HR merge: \(hrSamples.count) samples, avg \(Int(avgHR)) bpm, max \(maxHR) bpm")
        if let tss = hrTSS {
            print("❤️ Calculated TSS: \(String(format: "%.0f", tss))")
        }

        // Create updated ride with merged HR data
        let updatedRide = Ride(
            id: ride.id,
            date: ride.date,
            duration: ride.duration,
            distance: ride.distance,
            averageSpeed: ride.averageSpeed,
            maxSpeed: ride.maxSpeed,
            averageHeartRate: avgHR,
            maxHeartRate: maxHR,
            calories: newCalories > 0 ? newCalories : ride.calories,
            elevationGain: ride.elevationGain,
            routeCoordinates: ride.routeCoordinates,
            notes: (ride.notes ?? "") + " (Watch HR merged)",
            bikeName: ride.bikeName,
            bikeType: ride.bikeType,
            timeInZone: timeInZone,
            hrTSS: hrTSS,
            creatineMetrics: ride.creatineMetrics
        )

        return updatedRide
    }

    /// Calculate time spent in each HR zone from samples
    private func calculateTimeInZones(from samples: [(date: Date, bpm: Double)]) -> (TimeInZone?, Double?) {
        let userProfile = UserProfile.load()
        guard let hrZones = userProfile.hrZones, samples.count >= 2 else {
            // No LTHR configured - can't calculate zones
            return (nil, nil)
        }

        var timeInZone = TimeInZone()

        // Calculate time between consecutive samples and assign to zones
        for i in 1..<samples.count {
            let currentSample = samples[i]
            let previousSample = samples[i - 1]

            // Time between samples (using downsampled 5-second intervals)
            let interval = currentSample.date.timeIntervalSince(previousSample.date)

            // Skip unreasonable intervals (gaps in data)
            guard interval > 0 && interval <= 30 else { continue }

            // Determine zone for this HR
            let zone = hrZones.zone(for: Int(currentSample.bpm))
            timeInZone.add(seconds: interval, for: zone)
        }

        // Calculate hrTSS from time in zones
        let hrTSS = timeInZone.calculateHrTSS()

        return (timeInZone, hrTSS > 0 ? hrTSS : nil)
    }

    /// Save workout to HealthKit with detailed samples
    private func saveToHealthKit(workoutData: FITWorkoutData, ride: Ride) async throws {
        guard healthKitService.isHealthKitAvailable else {
            throw HealthKitError.notAvailable
        }

        // Always request authorization - HealthKit will skip the dialog if already authorized
        // Don't check isAuthorized first because write permission status is unreliable
        try await healthKitService.requestAuthorization()

        // Try to save - will fail with clear error if user denied permission
        try await saveWorkoutWithDetailedSamples(workoutData: workoutData)
    }

    /// Save workout to HealthKit with actual HR samples from FIT file
    private func saveWorkoutWithDetailedSamples(workoutData: FITWorkoutData) async throws {
        print("💾 HealthKit: Starting save...")
        let healthStore = HKHealthStore()

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .cycling
        configuration.locationType = workoutData.coordinates.isEmpty ? .indoor : .outdoor

        let builder = HKWorkoutBuilder(
            healthStore: healthStore,
            configuration: configuration,
            device: .local()
        )

        print("💾 HealthKit: Beginning collection...")
        try await builder.beginCollection(at: workoutData.startDate)
        print("💾 HealthKit: Collection started")

        // Add heart rate samples in chunks to avoid memory issues
        // For a 2-hour ride at 1-second intervals, this could be 7,200+ samples
        if !workoutData.heartRateSamples.isEmpty {
            print("💾 HealthKit: Adding \(workoutData.heartRateSamples.count) HR samples...")
            let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
            let hrUnit = HKUnit.count().unitDivided(by: .minute())

            let chunkSize = 500 // Process 500 samples at a time
            for chunkStart in stride(from: 0, to: workoutData.heartRateSamples.count, by: chunkSize) {
                let chunkEnd = min(chunkStart + chunkSize, workoutData.heartRateSamples.count)
                let chunk = workoutData.heartRateSamples[chunkStart..<chunkEnd]

                let hrSamples = chunk.map { sample in
                    HKQuantitySample(
                        type: hrType,
                        quantity: HKQuantity(unit: hrUnit, doubleValue: sample.bpm),
                        start: sample.date,
                        end: sample.date
                    )
                }
                try await builder.addSamples(hrSamples)
            }
            print("💾 HealthKit: HR samples added")
        } else {
            print("💾 HealthKit: No HR samples to add (workout has no heart rate data)")
        }

        // Add distance sample
        print("💾 HealthKit: Adding distance sample...")
        let distanceSample = HKQuantitySample(
            type: HKQuantityType.quantityType(forIdentifier: .distanceCycling)!,
            quantity: HKQuantity(unit: .mile(), doubleValue: workoutData.distanceMiles),
            start: workoutData.startDate,
            end: workoutData.endDate
        )
        try await builder.addSamples([distanceSample])

        // Add calories sample to workout
        if workoutData.calories > 0 {
            print("💾 HealthKit: Adding calories sample...")
            let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
            let caloriesSample = HKQuantitySample(
                type: activeEnergyType,
                quantity: HKQuantity(unit: .kilocalorie(), doubleValue: workoutData.calories),
                start: workoutData.startDate,
                end: workoutData.endDate
            )
            try await builder.addSamples([caloriesSample])
            print("🔥 Added \(workoutData.calories) kcal to workout")
        } else {
            print("⚠️ No calories in FIT file (workoutData.calories = \(workoutData.calories))")
        }

        // Add metadata
        print("💾 HealthKit: Adding metadata...")
        var metadata: [String: Any] = [
            HKMetadataKeyIndoorWorkout: workoutData.coordinates.isEmpty,
            "ImportedFrom": "Magene",
            "Tailwind": true
        ]

        if workoutData.averageCadence > 0 {
            metadata["AverageCadence"] = workoutData.averageCadence
        }
        if workoutData.averagePower > 0 {
            metadata["AveragePower"] = workoutData.averagePower
        }

        try await builder.addMetadata(metadata)

        // Finish the workout first
        print("💾 HealthKit: Finishing workout...")
        try await builder.endCollection(at: workoutData.endDate)
        let workout = try await builder.finishWorkout()
        print("💾 HealthKit: Workout saved!")

        // Now add the GPS route to the finished workout
        if !workoutData.coordinates.isEmpty, let finishedWorkout = workout {
            print("💾 HealthKit: Adding GPS route with \(workoutData.coordinates.count) points...")
            await addRoute(to: finishedWorkout, coordinates: workoutData.coordinates)
        }
        print("💾 HealthKit: Import complete!")
    }

    /// Add GPS route to a finished workout
    private func addRoute(to workout: HKWorkout, coordinates: [(date: Date, coordinate: CLLocationCoordinate2D, altitude: Double?)]) async {
        let healthStore = HKHealthStore()
        let routeBuilder = HKWorkoutRouteBuilder(healthStore: healthStore, device: nil)

        do {
            // Process coordinates in chunks to avoid memory issues
            let chunkSize = 100
            for chunkStart in stride(from: 0, to: coordinates.count, by: chunkSize) {
                let chunkEnd = min(chunkStart + chunkSize, coordinates.count)
                let chunk = coordinates[chunkStart..<chunkEnd]

                let locations = chunk.map { coord -> CLLocation in
                    CLLocation(
                        coordinate: coord.coordinate,
                        altitude: coord.altitude ?? 0,
                        horizontalAccuracy: 5,
                        verticalAccuracy: 10,
                        timestamp: coord.date
                    )
                }
                try await routeBuilder.insertRouteData(locations)
            }

            // Finish the route and associate it with the workout
            try await routeBuilder.finishRoute(with: workout, metadata: nil)
            print("🗺️ Added GPS route with \(coordinates.count) points to workout")
        } catch {
            print("⚠️ Failed to add route to workout: \(error.localizedDescription)")
            // Don't throw - workout is already saved, route is optional
        }
    }

}
