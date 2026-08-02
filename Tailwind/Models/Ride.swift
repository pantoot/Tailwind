import Foundation
import CoreLocation
import Combine


/// Where a ride happened.
///
/// Route analysis must never compare a trainer ride to a road ride: a 20-minute
/// Peloton spin and a 55-minute climb can both cover 7 miles, but averaging them
/// together describes the mix of rides rather than the rider.
enum RideEnvironment: String, Codable {
    case indoor
    case outdoor
    /// Neither GPS nor the ride's notes say which — most often a manual entry.
    /// Kept distinct so ambiguous rides never contaminate a known cluster.
    case unknown
}

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

    // Power & cadence summaries (nil when the source didn't record them)
    let averagePower: Double? // watts
    let averageCadence: Double? // rpm

    // GPS data
    let elevationGain: Double? // feet
    /// Ambient temperature during the ride. Outdoor heart rate is only comparable
    /// across rides at similar temperatures — heat inflates it independently of
    /// fitness. Nil when the source recorded none (all indoor rides, older imports).
    let averageTemperatureCelsius: Double?
    /// The GPS track. Present when a ride is first imported and whenever something
    /// explicitly loads it; nil after a plain read from disk, because tracks live in
    /// `RouteCoordinateStore` and are fetched only when a map needs them.
    ///
    /// Use `hasRouteData` rather than checking this for emptiness — a nil track means
    /// "not loaded", which is not the same as "no route".
    let routeCoordinates: [Coordinate]?

    /// How many GPS points the ride recorded. Persisted with the ride so indoor and
    /// outdoor can be told apart without touching the track files.
    let routePointCount: Int

    let notes: String?

    // Bike info
    let bikeName: String?
    let bikeType: String?

    // Training metrics
    let timeInZone: TimeInZone?
    let hrTSS: Double? // Heart Rate Training Stress Score

    // Creatine analysis (nil for rides without power data)
    let creatineMetrics: CreatineMetrics?

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
         averagePower: Double? = nil,
         averageCadence: Double? = nil,
         elevationGain: Double? = nil,
         averageTemperatureCelsius: Double? = nil,
         routeCoordinates: [Coordinate]? = nil,
         routePointCount: Int? = nil,
         notes: String? = nil,
         bikeName: String? = nil,
         bikeType: String? = nil,
         timeInZone: TimeInZone? = nil,
         hrTSS: Double? = nil,
         creatineMetrics: CreatineMetrics? = nil) {
        self.id = id
        self.date = date
        self.duration = duration
        self.distance = distance
        self.averageSpeed = averageSpeed
        self.maxSpeed = maxSpeed
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
        self.calories = calories
        self.averagePower = averagePower
        self.averageCadence = averageCadence
        self.elevationGain = elevationGain
        self.averageTemperatureCelsius = averageTemperatureCelsius
        self.routeCoordinates = routeCoordinates
        // Falls back to the track's own length, so callers that pass a track don't
        // have to keep a count in sync with it.
        self.routePointCount = routePointCount ?? routeCoordinates?.count ?? 0
        self.notes = notes
        self.bikeName = bikeName
        self.bikeType = bikeType
        self.timeInZone = timeInZone
        self.hrTSS = hrTSS
        self.creatineMetrics = creatineMetrics
    }

    // MARK: - Codable

    /// `routeCoordinates` is deliberately absent from the persisted keys — tracks
    /// belong to `RouteCoordinateStore`. It survives here only so a ride can carry a
    /// freshly imported track to whoever files it away.
    private enum CodingKeys: String, CodingKey {
        case id, date, duration, distance, averageSpeed, maxSpeed
        case averageHeartRate, maxHeartRate, calories
        case averagePower, averageCadence, elevationGain, averageTemperatureCelsius
        case routePointCount, notes, bikeName, bikeType, timeInZone, hrTSS, creatineMetrics
        /// Only read, never written: the key rides used before tracks moved out.
        case routeCoordinates
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        distance = try container.decode(Double.self, forKey: .distance)
        averageSpeed = try container.decode(Double.self, forKey: .averageSpeed)
        maxSpeed = try container.decode(Double.self, forKey: .maxSpeed)
        averageHeartRate = try container.decode(Double.self, forKey: .averageHeartRate)
        maxHeartRate = try container.decode(Int.self, forKey: .maxHeartRate)
        calories = try container.decode(Double.self, forKey: .calories)
        averagePower = try container.decodeIfPresent(Double.self, forKey: .averagePower)
        averageCadence = try container.decodeIfPresent(Double.self, forKey: .averageCadence)
        elevationGain = try container.decodeIfPresent(Double.self, forKey: .elevationGain)
        averageTemperatureCelsius = try container.decodeIfPresent(Double.self, forKey: .averageTemperatureCelsius)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        bikeName = try container.decodeIfPresent(String.self, forKey: .bikeName)
        bikeType = try container.decodeIfPresent(String.self, forKey: .bikeType)
        timeInZone = try container.decodeIfPresent(TimeInZone.self, forKey: .timeInZone)
        hrTSS = try container.decodeIfPresent(Double.self, forKey: .hrTSS)
        creatineMetrics = try container.decodeIfPresent(CreatineMetrics.self, forKey: .creatineMetrics)

        // Rides written before tracks moved out still carry one inline. Keep it so
        // the migration can file it away, and derive the count from it.
        let inlineTrack = try container.decodeIfPresent([Coordinate].self, forKey: .routeCoordinates)
        routeCoordinates = inlineTrack
        routePointCount = try container.decodeIfPresent(Int.self, forKey: .routePointCount)
            ?? inlineTrack?.count
            ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(date, forKey: .date)
        try container.encode(duration, forKey: .duration)
        try container.encode(distance, forKey: .distance)
        try container.encode(averageSpeed, forKey: .averageSpeed)
        try container.encode(maxSpeed, forKey: .maxSpeed)
        try container.encode(averageHeartRate, forKey: .averageHeartRate)
        try container.encode(maxHeartRate, forKey: .maxHeartRate)
        try container.encode(calories, forKey: .calories)
        try container.encodeIfPresent(averagePower, forKey: .averagePower)
        try container.encodeIfPresent(averageCadence, forKey: .averageCadence)
        try container.encodeIfPresent(elevationGain, forKey: .elevationGain)
        try container.encodeIfPresent(averageTemperatureCelsius, forKey: .averageTemperatureCelsius)
        try container.encode(routePointCount, forKey: .routePointCount)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(bikeName, forKey: .bikeName)
        try container.encodeIfPresent(bikeType, forKey: .bikeType)
        try container.encodeIfPresent(timeInZone, forKey: .timeInZone)
        try container.encodeIfPresent(hrTSS, forKey: .hrTSS)
        try container.encodeIfPresent(creatineMetrics, forKey: .creatineMetrics)
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

    var formattedAvgPower: String {
        averagePower.map { String(format: "%.0f W", $0) } ?? "—"
    }

    var formattedAvgCadence: String {
        averageCadence.map { String(format: "%.0f rpm", $0) } ?? "—"
    }

    /// True when the ride recorded either power or cadence, so the detail view
    /// can show that pair of stats together and keep the grid rows aligned.
    var hasPowerOrCadence: Bool {
        averagePower != nil || averageCadence != nil
    }

    /// Best available power figure — the ride summary, falling back to the value
    /// the creatine pass computed from 1Hz samples.
    var bestKnownAveragePower: Double? {
        if let power = averagePower, power > 0 { return power }
        if let power = creatineMetrics?.averagePower, power > 0 { return power }
        return nil
    }

    var averageTemperatureFahrenheit: Double? {
        averageTemperatureCelsius.map { $0 * 9 / 5 + 32 }
    }

    /// Whether the ride recorded a GPS track. Answers from the ride record alone, so
    /// it stays correct whether or not the track itself has been loaded.
    var hasRouteData: Bool { routePointCount > 0 }

    /// Indoor or outdoor, inferred from the strongest signal available.
    var environment: RideEnvironment {
        // GPS is definitive — a trainer can't record a route.
        if hasRouteData { return .outdoor }

        guard let notes = notes?.lowercased() else { return .unknown }
        if notes.contains("indoor") || notes.contains("peloton") { return .indoor }
        if notes.contains("magene") || notes.contains("apple workouts") { return .outdoor }
        return .unknown
    }

    /// Copy with heart rate and its recalculated stress score replaced. Rides are
    /// immutable, and restating all seventeen fields to change three invites drift.
    func replacingHeartRate(average: Double, max: Int, hrTSS: Double?) -> Ride {
        copy(averageHeartRate: average, maxHeartRate: max, hrTSS: hrTSS)
    }

    /// Copy with only the training stress score replaced.
    func replacingTSS(_ tss: Double) -> Ride {
        copy(hrTSS: tss)
    }

    private func copy(
        averageHeartRate: Double? = nil,
        maxHeartRate: Int? = nil,
        hrTSS: Double? = nil
    ) -> Ride {
        Ride(
            id: id,
            date: date,
            duration: duration,
            distance: distance,
            averageSpeed: averageSpeed,
            maxSpeed: maxSpeed,
            averageHeartRate: averageHeartRate ?? self.averageHeartRate,
            maxHeartRate: maxHeartRate ?? self.maxHeartRate,
            calories: calories,
            averagePower: averagePower,
            averageCadence: averageCadence,
            elevationGain: elevationGain,
            averageTemperatureCelsius: averageTemperatureCelsius,
            routeCoordinates: routeCoordinates,
            routePointCount: routePointCount,
            notes: notes,
            bikeName: bikeName,
            bikeType: bikeType,
            timeInZone: timeInZone,
            hrTSS: hrTSS ?? self.hrTSS,
            creatineMetrics: creatineMetrics
        )
    }
}

// Storage for rides
class RideHistory: ObservableObject {
    @Published var rides: [Ride] = []

    private let store: RideStore

    /// Upper bound on stored rides — roughly three years at Rick's volume. Rides
    /// live in a file now rather than UserDefaults, so this is a guard against
    /// unbounded decode cost at launch, not a storage limit. Truncation is logged
    /// because the old silent version quietly ate the back of the training history.
    private let maxRides = 1000

    private let trackStore: RouteCoordinateStore

    init(store: RideStore = RideStore(), trackStore: RouteCoordinateStore = RouteCoordinateStore()) {
        self.store = store
        self.trackStore = trackStore
        rides = store.load()
        migrateInlineTracks()
    }

    /// The GPS track for a ride, read from disk on demand.
    ///
    /// Tracks are not held in memory with the ride log — that's the whole point of
    /// moving them out — so map views ask for them when they're about to draw.
    func coordinates(for ride: Ride) -> [Ride.Coordinate]? {
        if let loaded = ride.routeCoordinates, !loaded.isEmpty { return loaded }
        guard ride.hasRouteData else { return nil }
        return trackStore.coordinates(for: ride.id)
    }

    /// Moves any track still stored inline in the ride log out to its own file.
    /// Runs once; afterwards the ride log holds only a point count.
    private func migrateInlineTracks() {
        let inline = rides.filter { ($0.routeCoordinates?.isEmpty == false) }
        guard !inline.isEmpty else { return }

        print("📦 Moving \(inline.count) GPS tracks out of the ride log...")
        var moved = 0
        for ride in inline {
            do {
                try trackStore.save(ride.routeCoordinates, for: ride.id)
                moved += 1
            } catch {
                print("❌ ERROR: Could not store track for \(ride.formattedDate): \(error.localizedDescription)")
            }
        }

        // Only rewrite the log once every track is safely filed, so a failure
        // partway through leaves the inline copies intact to retry next launch.
        guard moved == inline.count else {
            print("⚠️ Kept tracks inline — \(inline.count - moved) could not be written")
            return
        }

        persistRides()
        print("✅ Moved \(moved) GPS tracks to \(RouteCoordinateStore.directoryName)")
    }

    func saveRide(_ ride: Ride) {
        storeTrack(for: ride)
        rides.insert(ride, at: 0) // Add to beginning (most recent first)

        if rides.count > maxRides {
            let dropped = rides.count - maxRides
            let oldest = rides.suffix(dropped)
            for ride in oldest {
                print("⚠️ Ride log at \(maxRides); dropping oldest: \(ride.formattedDate)")
            }
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

    // Delete all rides for a specific date, returns count removed
    func deleteRidesForDate(_ date: Date) -> Int {
        let calendar = Calendar.current
        let before = rides.count
        rides.removeAll { calendar.isDate($0.date, inSameDayAs: date) }
        let removed = before - rides.count
        if removed > 0 {
            persistRides()
            print("🗑️ Removed \(removed) rides for \(date)")
        }
        return removed
    }

    /// Rides too short to be a session — Peloton warm-up and cool-down segments
    /// that were imported as standalone rides before they were filtered out.
    func shortRides(shorterThan minimumDuration: TimeInterval) -> [Ride] {
        rides.filter { $0.duration < minimumDuration }
    }

    /// Removes those warm-up/cool-down entries. Returns the count removed so the
    /// caller can report it and resync training load.
    @discardableResult
    func removeShortRides(shorterThan minimumDuration: TimeInterval) -> Int {
        let doomed = shortRides(shorterThan: minimumDuration)
        guard !doomed.isEmpty else { return 0 }

        for ride in doomed {
            print("🗑️ Removing short ride: \(ride.formattedDate) (\(ride.formattedDuration), \(String(format: "%.1f", ride.distance)) mi)")
        }

        rides = rides.filter { $0.duration >= minimumDuration }
        persistRides()
        return doomed.count
    }

    // Clear all rides (for re-import with new settings)
    func clearAllRides() {
        let count = rides.count
        rides.removeAll()
        persistRides()
        print("🗑️ Cleared all \(count) rides")
    }

    // Update a specific ride (e.g., to fix calories)
    func updateRide(_ rideId: UUID, with updatedRide: Ride) {
        if let index = rides.firstIndex(where: { $0.id == rideId }) {
            rides[index] = updatedRide
            persistRides()
            print("✅ Updated ride: \(updatedRide.formattedDate)")
        }
    }

    // Sort rides by date (most recent first)
    // Call this after bulk imports to ensure proper ordering
    func sortByDate() {
        rides.sort { $0.date > $1.date }
        persistRides()
    }

    /// Two rides are the same ride when they start within this window of each other.
    /// HealthKit hands back the same workout from several sources with slightly
    /// different start times.
    private static let duplicateStartWindow: TimeInterval = 300 // 5 minutes

    /// ...and when their durations agree this closely.
    private static let duplicateDurationSimilarity = 0.9 // within 10%

    /// Rides bucketed so that each bucket holds one real ride and its duplicates.
    /// A bucket of one means no duplicate.
    private func duplicateGroups() -> [[Ride]] {
        rides.reduce(into: [[Ride]]()) { groups, ride in
            let match = groups.firstIndex { group in
                group.contains { existing in
                    abs(existing.date.timeIntervalSince(ride.date)) < Self.duplicateStartWindow
                        && min(existing.duration, ride.duration) / max(existing.duration, ride.duration) > Self.duplicateDurationSimilarity
                }
            }

            guard let match else {
                groups.append([ride])
                return
            }
            groups[match].append(ride)
        }
    }

    /// How many rides `removeDuplicates()` would actually discard. Drives the
    /// Settings badge, which previously showed the total ride count and read as
    /// though every ride were a duplicate.
    var duplicateCount: Int {
        duplicateGroups().reduce(0) { $0 + ($1.count - 1) }
    }

    // Remove duplicate rides (same start time within 5 minutes and similar duration)
    // Keeps the ride with the most complete data
    func removeDuplicates() -> Int {
        let originalCount = rides.count

        // For each group, keep the ride with the most data
        rides = duplicateGroups().map { group in
            if group.count == 1 {
                return group[0]
            }

            // Score each ride by data completeness
            let scored = group.map { ride -> (Ride, Int) in
                var score = 0
                if ride.averageHeartRate > 0 { score += 10 }
                if ride.maxHeartRate > 0 { score += 5 }
                if ride.hrTSS != nil { score += 20 }
                if ride.timeInZone != nil { score += 15 }
                if ride.calories > 0 { score += 10 }
                if ride.hasRouteData { score += 15 }
                if ride.elevationGain != nil && ride.elevationGain! > 0 { score += 10 }
                if ride.bikeName != nil { score += 5 }
                if ride.notes != nil && !ride.notes!.isEmpty { score += 5 }
                if ride.creatineMetrics != nil { score += 10 }
                return (ride, score)
            }

            let best = scored.max(by: { $0.1 < $1.1 })!.0
            let removed = group.filter { $0.id != best.id }
            for r in removed {
                print("🗑️ Removing duplicate: \(r.formattedDate) (\(String(format: "%.1f", r.distance)) mi)")
            }
            print("✅ Keeping best: \(best.formattedDate) (\(String(format: "%.1f", best.distance)) mi, HR:\(Int(best.averageHeartRate)), TSS:\(best.hrTSS.map { String(format: "%.0f", $0) } ?? "none"))")

            return best
        }

        // Sort by date (most recent first)
        rides.sort { $0.date > $1.date }

        let removed = originalCount - rides.count
        if removed > 0 {
            persistRides()
            print("📊 Removed \(removed) duplicate rides, kept \(rides.count)")
        }
        return removed
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
                    averagePower: ride.averagePower,
                    averageCadence: ride.averageCadence,
                    elevationGain: ride.elevationGain,
                    routeCoordinates: ride.routeCoordinates,
                    notes: ride.notes,
                    bikeName: ride.bikeName,
                    bikeType: ride.bikeType,
                    timeInZone: ride.timeInZone,
                    hrTSS: ride.hrTSS,
                    creatineMetrics: ride.creatineMetrics
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

    /// Files a freshly imported ride's track away, if it carries one.
    private func storeTrack(for ride: Ride) {
        guard let track = ride.routeCoordinates, !track.isEmpty else { return }
        do {
            try trackStore.save(track, for: ride.id)
        } catch {
            print("❌ ERROR: Could not store GPS track for \(ride.formattedDate): \(error.localizedDescription)")
        }
    }

    private func persistRides() {
        do {
            try store.save(rides)
            print("✅ Successfully saved \(rides.count) rides")
        } catch {
            print("❌ ERROR: Failed to save rides: \(error.localizedDescription)")
        }

        // Tracks outlive their ride unless something removes them, and rides are
        // deleted from five different places. Pruning here covers all of them
        // rather than trusting each caller to remember.
        let removed = trackStore.removeOrphans(keeping: Set(rides.map(\.id)))
        if removed > 0 {
            print("🗑️ Removed \(removed) orphaned GPS tracks")
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
