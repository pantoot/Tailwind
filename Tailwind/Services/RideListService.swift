import Foundation

/// Pure helpers for grouping a ride list into months and formatting it.
///
/// Kept free of `Ride` and SwiftUI so scripts/run-tests.sh can cover it —
/// the view maps rides to month keys at the boundary.
///
/// Grouping goes through `Calendar` components rather than the
/// `DateFormatter` string round-trip the two previous list implementations
/// used, which was both locale-sensitive and re-created a formatter inside a
/// `ForEach`.
nonisolated struct RideListService {

    private static let monthNames = [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December",
    ]

    /// Sortable month identifier, e.g. "2026-08". Year-first and zero-padded
    /// so plain string ordering is chronological across year boundaries.
    static func monthKey(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 0)
    }

    /// Display header for a month key. Falls back to the raw key rather than
    /// rendering a blank header if the key is ever malformed.
    static func monthTitle(forKey key: String) -> String {
        let parts = key.split(separator: "-")
        guard parts.count == 2,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              (1...12).contains(month) else { return key }
        return "\(monthNames[month - 1]) \(year)"
    }

    /// Newest month first.
    static func sortedMonthKeys(_ keys: some Collection<String>) -> [String] {
        keys.sorted(by: >)
    }

    /// Which month sections start expanded: the current one, or — when this
    /// month has no rides yet — the most recent month that does, so the list
    /// never opens fully collapsed.
    static func defaultExpandedKeys(
        allKeys: some Collection<String>,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Set<String> {
        let currentKey = monthKey(for: now, calendar: calendar)
        if allKeys.contains(currentKey) { return [currentKey] }
        return Set(sortedMonthKeys(allKeys).prefix(1))
    }

    /// "2h 5m" / "45m". Replaces duplicate implementations that had drifted
    /// between the two ride lists and the LTHR result view.
    static func formatDuration(_ duration: TimeInterval) -> String {
        let total = max(0, Int(duration))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }
}
