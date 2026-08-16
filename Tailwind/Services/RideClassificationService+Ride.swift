import Foundation

/// Bridges app types to the pure classifier. Kept in its own file so
/// RideClassificationService.swift stays free of `Ride` and remains
/// compilable by scripts/run-tests.sh — if a `Ride` reference ever lands in
/// the core, the harness breaks immediately, which is the intended signal.
extension RideClassificationService {
    static func classify(ride: Ride, profile: UserProfile) -> Classification {
        classify(input(for: ride, profile: profile))
    }

    static func input(for ride: Ride, profile: UserProfile) -> Input {
        Input(
            duration: ride.duration,
            // Deliberately NOT `bestKnownAveragePower`, which prefers the
            // device's summary average — a plain mean over raw samples that
            // skips auto-paused gaps. Normalized power and max-30s both come
            // from the zero-filled dense array, so mixing the two sources
            // would divide a stopped-time-inclusive numerator by a
            // stopped-time-excluding denominator, biasing VI low and making
            // punchy rides read steadier than they were.
            averagePower: ride.creatineMetrics?.averagePower ?? ride.averagePower,
            normalizedPower: ride.creatineMetrics?.normalizedPower,
            max30sPower: ride.creatineMetrics?.max30sPower,
            matchCount: ride.creatineMetrics?.matchCount ?? 0,
            averageHeartRate: ride.averageHeartRate > 0 ? ride.averageHeartRate : nil,
            ftp: profile.ftp,
            lthr: profile.lactateThresholdHR
        )
    }
}
