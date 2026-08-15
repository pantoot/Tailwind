import Foundation

/// Finds rides whose stored training stress score understates the work done.
///
/// Two scoring routes are in use and neither is wrong. FIT imports score by time
/// in heart-rate zones; HealthKit imports score by intensity factor over the whole
/// ride. A zone-weighted figure legitimately differs from an IF² one, so a
/// disagreement between them is not a defect and must not be "repaired" — doing so
/// would rewrite training history to a different methodology.
///
/// What *is* a defect:
///
/// - **Sparse coverage.** A zone-weighted score sums real sample intervals, so a
///   heart-rate strap that drops out mid-ride scores only the connected minutes
///   while the ride's average heart rate still reads normally. A 70-minute effort
///   lands as 16 TSS. The score isn't a different opinion, it's most of the ride
///   missing.
/// - **Unreproducible.** A ride with no zone data whose score matches neither an
///   HR-based nor a power-based calculation of its own numbers.
enum TSSAuditService {

    /// Zone data must cover at least this much of the ride for its score to stand.
    static let minimumZoneCoverage = 0.80

    /// How far a stored score may sit from a recomputed one before it's suspect.
    static let tolerance = 0.20

    /// Below this the relative test is meaningless — a short ride swings past 20%
    /// on rounding alone.
    static let minimumAbsoluteDelta: Double = 5

    enum Defect {
        /// Zone data covered only this fraction of the ride's duration.
        case sparseHeartRateCoverage(Double)
        /// Score matches neither scoring route.
        case unreproducible

        var label: String {
            switch self {
            case .sparseHeartRateCoverage(let fraction):
                return "HR data covered only \(Int(fraction * 100))% of the ride"
            case .unreproducible:
                return "matches neither HR nor power"
            }
        }
    }

    struct Discrepancy {
        let ride: Ride
        let storedTSS: Double
        let defect: Defect
        /// What the ride's own heart rate and duration imply, when available.
        let heartRateTSS: Double?
        /// What the ride's own power and the current FTP imply, when available.
        let powerTSS: Double?

        /// The figure to repair to. Heart rate wins because these rides were
        /// originally HR-scored, so a repair stays consistent with its neighbours
        /// rather than silently switching to power against an unvalidated FTP.
        var suggestedTSS: Double? { heartRateTSS ?? powerTSS }

        var delta: Double { (suggestedTSS ?? storedTSS) - storedTSS }
    }

    /// Rides whose stored score understates the work, worst first.
    static func audit(_ rides: [Ride], profile: UserProfile) -> [Discrepancy] {
        rides
            .compactMap { ride -> Discrepancy? in
                guard let stored = ride.hrTSS else { return nil }

                let fromHR = HealthKitService.heartRateTSS(
                    duration: ride.duration,
                    averageHeartRate: ride.averageHeartRate,
                    profile: profile
                )
                // Average-power and normalized-power scores are both legitimate
                // methodologies (avg predates NP scoring), so a stored value
                // matching either one is reproducible.
                let fromAveragePower = HealthKitService.powerTSS(
                    duration: ride.duration,
                    averagePower: ride.bestKnownAveragePower,
                    profile: profile
                )
                let fromNormalizedPower = HealthKitService.powerTSS(
                    duration: ride.duration,
                    averagePower: nil,
                    normalizedPower: ride.creatineMetrics?.normalizedPower,
                    profile: profile
                )
                let fromPower = fromNormalizedPower ?? fromAveragePower

                // Nothing to check against — no thresholds set, or no signal recorded.
                guard fromHR != nil || fromPower != nil else { return nil }

                guard let defect = defect(
                    for: ride,
                    stored: stored,
                    fromHR: fromHR,
                    powerScores: [fromNormalizedPower, fromAveragePower].compactMap { $0 }
                ) else {
                    return nil
                }

                return Discrepancy(
                    ride: ride,
                    storedTSS: stored,
                    defect: defect,
                    heartRateTSS: fromHR,
                    powerTSS: fromPower
                )
            }
            .sorted { abs($0.delta) > abs($1.delta) }
    }

    private static func defect(
        for ride: Ride,
        stored: Double,
        fromHR: Double?,
        powerScores: [Double]
    ) -> Defect? {
        // A zone-scored ride is judged on how much of itself it actually measured,
        // not on whether it agrees with a different formula.
        if let zones = ride.timeInZone, ride.duration > 0 {
            let coverage = zones.totalSeconds / ride.duration
            guard coverage < minimumZoneCoverage else { return nil }

            // Only worth flagging if rescoring would meaningfully raise it.
            guard let suggested = fromHR ?? powerScores.first,
                  suggested - stored > minimumAbsoluteDelta else { return nil }

            return .sparseHeartRateCoverage(coverage)
        }

        let plausible = ([fromHR].compactMap { $0 } + powerScores)
            .contains { matches(stored: stored, expected: $0) }
        return plausible ? nil : .unreproducible
    }

    private static func matches(stored: Double, expected: Double) -> Bool {
        let difference = abs(stored - expected)
        if difference <= minimumAbsoluteDelta { return true }
        return difference / max(expected, 1) <= tolerance
    }
}
