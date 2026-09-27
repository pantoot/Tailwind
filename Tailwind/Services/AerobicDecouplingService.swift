import Foundation

/// Friel's aerobic (Pw:HR) decoupling: how much the power-to-heart-rate
/// ratio slipped between the first and second half of a ride. Efficiency
/// factor (EF) is normalized power over average HR for each half;
/// decoupling is the drop in EF from the first half to the second, as a
/// percentage of the first. Positive means HR rose relative to power (or
/// power faded at the same HR) — cardiac drift from heat, dehydration,
/// glycogen, or fatigue. Under 5% on a steady endurance ride is the
/// conventional mark of well-developed aerobic endurance.
nonisolated struct AerobicDecoupling: Codable, Equatable {
    let firstHalfEfficiency: Double
    let secondHalfEfficiency: Double
    /// (EF1 − EF2) / EF1 × 100. Negative when HR settled lower late in the ride.
    let percent: Double

    enum Rating: Equatable {
        case coupled    // < 5%
        case moderate   // 5–10%
        case high       // ≥ 10%
    }

    static let moderateThresholdPercent = 5.0
    static let highThresholdPercent = 10.0

    static func rating(forPercent percent: Double) -> Rating {
        if percent >= highThresholdPercent { return .high }
        if percent >= moderateThresholdPercent { return .moderate }
        return .coupled
    }

    var rating: Rating { Self.rating(forPercent: percent) }
}

nonisolated struct AerobicDecouplingService {

    /// Friel's protocol assumes a sustained steady ride; anything shorter has
    /// halves too brief for the ratio to settle. 45 min keeps the common
    /// 45-minute endurance class in and drops warm-ups and short sessions.
    /// Must stay well above 2 × `trimSeconds` + 2 × the normalized-power
    /// window (`PowerMath.normalizedPowerWindowSeconds`), or a trimmed half
    /// has no NP and the ride silently yields nil.
    static let minimumRideSeconds = 45 * 60

    /// Dropped from each end before splitting. HR lags power on a cold start
    /// and stays up through a soft-pedal cool-down; either one, left in,
    /// manufactures drift on a ride that was steady in the middle.
    static let trimSeconds = 5 * 60

    /// A dense HR array that never exceeds this is a missing signal, not data.
    static let minimumPlausibleHR = 30.0

    /// - Parameters:
    ///   - densePower: 1Hz power (from `buildDenseArray`).
    ///   - denseHR: 1Hz heart rate on the same grid; all-zero when absent.
    /// - Returns: nil when the ride is too short or lacks a usable HR or power
    ///   signal, so callers never see a decoupling built on a divide-by-zero.
    static func decoupling(densePower: [Double], denseHR: [Double]) -> AerobicDecoupling? {
        let count = min(densePower.count, denseHR.count)
        guard count >= minimumRideSeconds else { return nil }
        guard (denseHR.max() ?? 0) > minimumPlausibleHR else { return nil }

        let body = trimSeconds..<(count - trimSeconds)
        let midpoint = body.lowerBound + body.count / 2
        let first = body.lowerBound..<midpoint
        let second = midpoint..<body.upperBound

        guard let ef1 = efficiencyFactor(power: densePower[first], hr: denseHR[first]),
              let ef2 = efficiencyFactor(power: densePower[second], hr: denseHR[second]),
              ef1 > 0 else { return nil }

        return AerobicDecoupling(
            firstHalfEfficiency: ef1,
            secondHalfEfficiency: ef2,
            percent: (ef1 - ef2) / ef1 * 100
        )
    }

    /// Normalized power over average HR for one half. Nil when either side
    /// is missing — a half with no beats or no watts has no ratio.
    private static func efficiencyFactor(power: ArraySlice<Double>, hr: ArraySlice<Double>) -> Double? {
        guard let np = PowerMath.normalizedPower(Array(power)), np > 0 else { return nil }
        let averageHR = PowerMath.mean(hr)
        guard averageHR > minimumPlausibleHR else { return nil }
        return np / averageHR
    }
}
