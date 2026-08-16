import Foundation

/// Turns today's training-load numbers into a directive: a form state, a
/// target-TSS range for today, a one-line prescription, and a "why" sentence
/// that explains the number. Pure functions over values — no persistence, no
/// HealthKit — so it is covered by scripts/run-tests.sh.
///
/// The target range is expressed as multipliers of CTL because CTL *is*
/// daily-average TSS at steady state: riding at 1.0 × CTL maintains fitness,
/// above it builds, below it recovers.
nonisolated struct TrainingDirectiveService {
    struct RecentRide {
        let date: Date
        let tss: Double?
    }

    struct Directive: Equatable {
        let status: PerformanceMetrics.FormStatus
        let targetTSSRange: ClosedRange<Int>?
        let prescription: String
        let why: String
        let isRampCapped: Bool
    }

    /// Mirrors the existing dashboard warning: ramp strictly above 5 CTL/wk.
    static let rampCapThreshold = 5.0
    /// Below this CTL the EMA is still mostly warm-up bias; a target range
    /// computed from it would be noise.
    static let minimumCTLForTarget = 10.0
    /// How far back a ride can be and still explain today's form.
    static let whyLookbackDays = 7

    private static let rampCapMultipliers: ClosedRange<Double> = 0.0...0.6

    private static func multipliers(for status: PerformanceMetrics.FormStatus) -> ClosedRange<Double> {
        switch status {
        case .fresh: return 1.2...1.8
        case .rested: return 1.0...1.5
        case .optimal: return 0.8...1.2
        case .productive: return 0.5...0.9
        case .overreaching: return 0.0...0.4
        }
    }

    static func directive(
        metrics: PerformanceMetrics,
        rampRate: Double,
        recentRides: [RecentRide],
        today: Date,
        calendar: Calendar = .current
    ) -> Directive {
        let status = metrics.formStatus
        let isRampCapped = rampRate > rampCapThreshold

        guard metrics.ctl >= minimumCTLForTarget else {
            return Directive(
                status: status,
                targetTSSRange: nil,
                prescription: "Not enough training history yet — keep importing rides to build your baseline.",
                why: whySentence(metrics: metrics, rampRate: rampRate, recentRides: recentRides,
                                 today: today, calendar: calendar),
                isRampCapped: isRampCapped
            )
        }

        let range = targetRange(ctl: metrics.ctl, status: status, isRampCapped: isRampCapped)
        return Directive(
            status: status,
            targetTSSRange: range,
            prescription: prescription(for: status, range: range, isRampCapped: isRampCapped),
            why: whySentence(metrics: metrics, rampRate: rampRate, recentRides: recentRides,
                             today: today, calendar: calendar),
            isRampCapped: isRampCapped
        )
    }

    // MARK: - Target range

    private static func targetRange(
        ctl: Double,
        status: PerformanceMetrics.FormStatus,
        isRampCapped: Bool
    ) -> ClosedRange<Int> {
        let band = multipliers(for: status)
        var lower = Int((ctl * band.lowerBound).rounded())
        var upper = Int((ctl * band.upperBound).rounded())

        if isRampCapped {
            // The cap can only ever lower a prescription, never raise one.
            lower = min(lower, Int((ctl * rampCapMultipliers.lowerBound).rounded()))
            upper = min(upper, Int((ctl * rampCapMultipliers.upperBound).rounded()))
        }

        return min(lower, upper)...upper
    }

    // MARK: - Prescription

    private static func prescription(
        for status: PerformanceMetrics.FormStatus,
        range: ClosedRange<Int>,
        isRampCapped: Bool
    ) -> String {
        let span = "\(range.lowerBound)–\(range.upperBound) TSS"

        if isRampCapped {
            return "CTL is climbing too fast — back off. Keep today at \(span)."
        }

        switch status {
        case .fresh:
            return "Fresh and primed — great day to go hard. Target \(span)."
        case .rested:
            return "Good day for threshold or VO2 work. Target \(span)."
        case .optimal:
            return "Balanced — keep it rolling. Target \(span)."
        case .productive:
            return "Fatigue is building — favor endurance. Target \(span)."
        case .overreaching:
            return "Rest day or very easy spin. Stay at \(span)."
        }
    }

    // MARK: - Why sentence

    private static func whySentence(
        metrics: PerformanceMetrics,
        rampRate: Double,
        recentRides: [RecentRide],
        today: Date,
        calendar: Calendar
    ) -> String {
        let ctlClause = ctlClause(ctl: metrics.ctl, rampRate: rampRate)

        guard let lastRide = mostRecentScoredRide(in: recentRides, today: today, calendar: calendar),
              let tss = lastRide.tss else {
            return "No recent rides on the books; \(ctlClause)."
        }

        let tssText = "\(Int(tss.rounded()))-TSS"
        let dayText = dayPhrase(for: lastRide.date, today: today, calendar: calendar)

        if calendar.isDate(lastRide.date, inSameDayAs: today) {
            return "\(dayText) \(tssText) ride is already in the books; \(ctlClause)."
        }
        return "\(dayText) \(tssText) ride is still in your legs; \(ctlClause)."
    }

    /// Most recent ride inside the lookback window that actually has a TSS.
    private static func mostRecentScoredRide(
        in rides: [RecentRide],
        today: Date,
        calendar: Calendar
    ) -> RecentRide? {
        let cutoff = calendar.date(byAdding: .day, value: -whyLookbackDays, to: today) ?? today
        return rides
            .filter { $0.tss != nil && $0.date >= cutoff }
            .max(by: { $0.date < $1.date })
    }

    private static func ctlClause(ctl: Double, rampRate: Double) -> String {
        let ctlText = "\(Int(ctl.rounded()))"
        if rampRate > 1 {
            return "CTL climbing to \(ctlText)"
        } else if rampRate < -1 {
            return "CTL easing to \(ctlText)"
        }
        return "CTL steady at \(ctlText)"
    }

    private static func dayPhrase(for date: Date, today: Date, calendar: Calendar) -> String {
        "\(relativeDayName(for: date, today: today, calendar: calendar))'s"
    }

    /// "Today", "Yesterday", or the weekday name — shared by the hero card's
    /// why sentence and the Last Ride glance tile so the two can never
    /// disagree. The app's UI is intentionally English-only (every string is
    /// hardcoded English), so the weekday is pinned to en_US_POSIX rather
    /// than the device locale; this also keeps the harness deterministic.
    /// Allocated per call, not cached: this runs once per render, unlike the
    /// model layer's hot-path shared formatter.
    static func relativeDayName(for date: Date, today: Date, calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: today) {
            return "Today"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "Yesterday"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
}
