import Foundation

/// Sanity-checks a hand-typed average power against the rider's own measured
/// power-to-heart-rate relationship.
///
/// Manual entry feeds its power field straight into `HealthKitService.calculateTSS`,
/// which prefers power over heart rate unconditionally. One mistyped or misread
/// number — a max output pasted where an average belongs — therefore sets the ride's
/// training stress outright, and nothing downstream disputes it: `TSSAuditService`
/// recomputes from that same stored figure and finds it perfectly self-consistent.
/// The bad number then feeds CTL, ATL and form for the next six weeks.
///
/// A fixed rule of thumb can't catch this. Comparing the intensity factor implied by
/// power against the one implied by heart rate sounds principled, but on real
/// measured rides those two routinely disagree by 10% or more in either direction —
/// wide enough that any threshold loose enough to avoid false alarms would wave the
/// typo through.
///
/// What does separate them is the rider's *own* history. Watts per beat is a crude
/// model — heart rate carries a resting offset, so the ratio drifts across a wide
/// intensity range — but it is the same efficiency figure the route analysis already
/// trends, it needs no FTP, and it is far sharper than any universal threshold on
/// the one thing that matters here: a typo sits well outside the rider's own spread.
enum PowerPlausibilityService {

    /// Below this many measured rides the median is too noisy to accuse anyone of a typo.
    static let minimumBaselineRides = 5

    /// Most recent measured rides to learn from. Bounds how stale the baseline can
    /// get as fitness moves, without needing a calendar window.
    static let baselineRideLimit = 30

    /// How far a typed figure may sit from the rider's own ratio before it's called out.
    static let tolerance = 0.20

    struct Baseline {
        /// Median watts per heartbeat across measured rides.
        let wattsPerBeat: Double
        let rideCount: Int
    }

    struct Verdict {
        let typedPower: Double
        /// What the rider's own ratio predicts at this heart rate.
        let expectedPower: Double
        let baseline: Baseline
        /// Signed fraction: +0.21 means the typed figure is 21% high.
        let deviation: Double

        var isOverstated: Bool { deviation > 0 }

        var message: String {
            """
            \(Int(typedPower))W is \(Int(abs(deviation) * 100))% \
            \(isOverstated ? "higher" : "lower") than your last \(baseline.rideCount) measured \
            rides suggest for this heart rate — they'd put you near \(Int(expectedPower))W. \
            TSS is scored from power, not heart rate, so a wrong figure here sets this ride's \
            training load. Check it's average output, not max.
            """
        }
    }

    /// The rider's own watts-per-beat, from rides whose power came off a real sample
    /// stream. Rides carrying a hand-typed figure are excluded by requiring
    /// `creatineMetrics`, which only the 1 Hz analysis pass produces — the baseline
    /// must not learn from the mistakes it exists to catch.
    static func baseline(from rides: [Ride]) -> Baseline? {
        // Kept as separate statements with explicit types: as one chained expression
        // this defeats the Swift type checker.
        let measured: [Ride] = rides.filter { $0.averageHeartRate > 0 && $0.creatineMetrics != nil }
        let newestFirst: [Ride] = measured.sorted { $0.date > $1.date }
        let recent: [Ride] = Array(newestFirst.prefix(baselineRideLimit))

        var ratios: [Double] = []
        for ride in recent {
            guard let power = ride.creatineMetrics?.averagePower, power > 0 else { continue }
            ratios.append(power / ride.averageHeartRate)
        }

        guard ratios.count >= minimumBaselineRides else { return nil }
        return Baseline(wattsPerBeat: median(of: ratios.sorted()), rideCount: ratios.count)
    }

    /// A complaint about the typed power, or nil when it's plausible — or when there
    /// isn't enough measured history to hold an opinion. Staying silent is the right
    /// answer for a new install; a warning drawn from two rides would be noise.
    static func check(typedPower: Double, averageHeartRate: Double, rides: [Ride]) -> Verdict? {
        guard typedPower > 0, averageHeartRate > 0,
              let baseline = baseline(from: rides) else { return nil }

        let expected = baseline.wattsPerBeat * averageHeartRate
        guard expected > 0 else { return nil }

        let deviation = (typedPower - expected) / expected
        guard abs(deviation) > tolerance else { return nil }

        return Verdict(
            typedPower: typedPower,
            expectedPower: expected,
            baseline: baseline,
            deviation: deviation
        )
    }

    private static func median(of sorted: [Double]) -> Double {
        let mid = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
    }
}
