import Foundation

/// Pure power arithmetic shared by the analysis services. Lives apart from
/// `CreatineAnalysisService` so the standalone test harness can compile it
/// without dragging in settings, profile, and HealthKit types.
nonisolated enum PowerMath {

    static let normalizedPowerWindowSeconds = 30

    /// Coggan normalized power: 30s rolling average, then the fourth root of
    /// the mean fourth power. Nil for rides shorter than one rolling window.
    static func normalizedPower(_ densePower: [Double]) -> Double? {
        let window = normalizedPowerWindowSeconds
        guard densePower.count >= window else { return nil }

        var rollingSum = densePower[0..<window].reduce(0, +)
        var fourthPowerTotal = pow(rollingSum / Double(window), 4)
        var rollingCount = 1
        for i in window..<densePower.count {
            rollingSum += densePower[i] - densePower[i - window]
            fourthPowerTotal += pow(rollingSum / Double(window), 4)
            rollingCount += 1
        }
        return pow(fourthPowerTotal / Double(rollingCount), 0.25)
    }

    static func mean(_ values: ArraySlice<Double>) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }
}
