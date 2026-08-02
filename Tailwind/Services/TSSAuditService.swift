import Foundation

/// Finds rides whose stored training stress score can't be reproduced from the
/// ride's own data.
///
/// The check deliberately accepts a score that matches *either* scoring route.
/// Most of the ride log predates the switch to power-preferred scoring, so those
/// rides hold an HR-based figure even though they carry power — that's stale, not
/// corrupt, and rescoring it against an unvalidated FTP would quietly rewrite
/// training history. Only a score that matches neither route is a real defect.
enum TSSAuditService {

    /// How far a stored score may sit from a recomputed one before it's suspect.
    static let tolerance = 0.20

    /// Below this the relative test is meaningless — a 3 TSS cool-down swings
    /// past 20% on rounding alone.
    static let minimumAbsoluteDelta: Double = 5

    struct Discrepancy {
        let ride: Ride
        let storedTSS: Double
        /// What the ride's own heart rate and duration imply, when available.
        let heartRateTSS: Double?
        /// What the ride's own power and the current FTP imply, when available.
        let powerTSS: Double?

        /// The figure to repair to. Heart rate wins because it's what these
        /// rides were originally scored from, so a repair stays consistent with
        /// its neighbours instead of silently switching methodology.
        var suggestedTSS: Double? { heartRateTSS ?? powerTSS }

        var delta: Double { (suggestedTSS ?? storedTSS) - storedTSS }
    }

    /// Rides whose stored score matches neither scoring route, worst first.
    static func audit(_ rides: [Ride], profile: UserProfile) -> [Discrepancy] {
        rides
            .compactMap { ride -> Discrepancy? in
                guard let stored = ride.hrTSS else { return nil }

                let fromHR = HealthKitService.heartRateTSS(
                    duration: ride.duration,
                    averageHeartRate: ride.averageHeartRate,
                    profile: profile
                )
                let fromPower = HealthKitService.powerTSS(
                    duration: ride.duration,
                    averagePower: ride.bestKnownAveragePower,
                    profile: profile
                )

                // No way to check this ride — neither threshold is set, or the
                // ride recorded neither signal.
                guard fromHR != nil || fromPower != nil else { return nil }

                let plausible = [fromHR, fromPower]
                    .compactMap { $0 }
                    .contains { matches(stored: stored, expected: $0) }
                guard !plausible else { return nil }

                return Discrepancy(
                    ride: ride,
                    storedTSS: stored,
                    heartRateTSS: fromHR,
                    powerTSS: fromPower
                )
            }
            .sorted { abs($0.delta) > abs($1.delta) }
    }

    private static func matches(stored: Double, expected: Double) -> Bool {
        let difference = abs(stored - expected)
        if difference <= minimumAbsoluteDelta { return true }
        return difference / max(expected, 1) <= tolerance
    }
}
