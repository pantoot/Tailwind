import Foundation
import Combine

struct WeightEntry: Codable, Identifiable {
    let id: UUID
    let date: Date
    let weightLbs: Double

    init(id: UUID = UUID(), date: Date = Date(), weightLbs: Double) {
        self.id = id
        self.date = date
        self.weightLbs = weightLbs
    }

    var weightKg: Double { weightLbs * 0.453592 }

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

    /// Get weight on or before a given date (for W/kg calc on historical rides)
    func weightOnOrBefore(_ date: Date) -> Double? {
        let calendar = Calendar.current
        // Find the most recent entry on or before this date
        return entries
            .filter { calendar.compare($0.date, to: date, toGranularity: .day) != .orderedDescending }
            .first?.weightLbs
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
