import Foundation
import Combine

struct WeightEntry: Codable, Identifiable {
    let id: UUID
    let date: Date
    let weightLbs: Double
    let leanBodyMassLbs: Double?
    let bodyFatPercentage: Double?

    init(id: UUID = UUID(), date: Date = Date(), weightLbs: Double,
         leanBodyMassLbs: Double? = nil, bodyFatPercentage: Double? = nil) {
        self.id = id
        self.date = date
        self.weightLbs = weightLbs
        self.leanBodyMassLbs = leanBodyMassLbs
        self.bodyFatPercentage = bodyFatPercentage
    }

    var weightKg: Double { weightLbs * 0.453592 }
    var leanBodyMassKg: Double? { leanBodyMassLbs.map { $0 * 0.453592 } }

    /// Fat mass derived from total weight and lean mass
    var fatMassLbs: Double? {
        guard let lean = leanBodyMassLbs else { return nil }
        return weightLbs - lean
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

class WeightLogManager: ObservableObject {
    @Published var entries: [WeightEntry] = []

    private let storageKey = "WeightLogEntries"

    init() {
        loadEntries()
    }

    func addEntry(_ entry: WeightEntry) {
        entries.insert(entry, at: 0)
        entries.sort { $0.date > $1.date }
        saveEntries()
    }

    func deleteEntry(_ entry: WeightEntry) {
        entries.removeAll { $0.id == entry.id }
        saveEntries()
    }

    func latestWeight() -> Double? {
        entries.first?.weightLbs
    }

    /// Latest entry that has body composition data
    func latestComposition() -> WeightEntry? {
        entries.first { $0.bodyFatPercentage != nil || $0.leanBodyMassLbs != nil }
    }

    /// Get weight on or before a given date (for W/kg calc on historical rides)
    func weightOnOrBefore(_ date: Date) -> Double? {
        let calendar = Calendar.current
        // Find the most recent entry on or before this date
        return entries
            .filter { calendar.compare($0.date, to: date, toGranularity: .day) != .orderedDescending }
            .first?.weightLbs
    }

    /// Merge body composition samples from HealthKit into the log, deduplicating by date.
    /// Returns the number of new entries added.
    @discardableResult
    func syncFromHealthKit(
        weightSamples: [(date: Date, lbs: Double)],
        leanMassSamples: [(date: Date, lbs: Double)] = [],
        bodyFatSamples: [(date: Date, pct: Double)] = []
    ) -> Int {
        let calendar = Calendar.current
        // Build a set of existing dates (day granularity) for fast lookup
        let existingDays = Set(entries.map { calendar.startOfDay(for: $0.date) })

        // Index lean mass and body fat by day for fast matching
        var leanByDay: [Date: Double] = [:]
        for sample in leanMassSamples {
            let day = calendar.startOfDay(for: sample.date)
            leanByDay[day] = sample.lbs // latest wins since samples sorted newest-first
        }

        var fatByDay: [Date: Double] = [:]
        for sample in bodyFatSamples {
            let day = calendar.startOfDay(for: sample.date)
            fatByDay[day] = sample.pct
        }

        // Backfill composition on existing entries that lack it
        var backfilled = 0
        for i in entries.indices {
            let day = calendar.startOfDay(for: entries[i].date)
            if entries[i].leanBodyMassLbs == nil, let lean = leanByDay[day] {
                entries[i] = WeightEntry(
                    id: entries[i].id,
                    date: entries[i].date,
                    weightLbs: entries[i].weightLbs,
                    leanBodyMassLbs: lean,
                    bodyFatPercentage: fatByDay[day] ?? entries[i].bodyFatPercentage
                )
                backfilled += 1
            } else if entries[i].bodyFatPercentage == nil, let fat = fatByDay[day] {
                entries[i] = WeightEntry(
                    id: entries[i].id,
                    date: entries[i].date,
                    weightLbs: entries[i].weightLbs,
                    leanBodyMassLbs: entries[i].leanBodyMassLbs,
                    bodyFatPercentage: fat
                )
                backfilled += 1
            }
        }

        var added = 0
        for sample in weightSamples {
            let day = calendar.startOfDay(for: sample.date)
            guard !existingDays.contains(day) else { continue }
            // Skip unreasonable values
            guard sample.lbs > 50 && sample.lbs < 500 else { continue }

            let entry = WeightEntry(
                date: sample.date,
                weightLbs: sample.lbs,
                leanBodyMassLbs: leanByDay[day],
                bodyFatPercentage: fatByDay[day]
            )
            entries.append(entry)
            added += 1
        }

        if added > 0 || backfilled > 0 {
            entries.sort { $0.date > $1.date }
            saveEntries()
            if added > 0 { print("⚖️ Synced \(added) new weight entries from HealthKit") }
            if backfilled > 0 { print("⚖️ Backfilled composition on \(backfilled) existing entries") }
        }
        return added
    }

    private func loadEntries() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([WeightEntry].self, from: data) else {
            return
        }
        entries = decoded
    }

    private func saveEntries() {
        if let encoded = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
}
