import Foundation

/// Finds the highest *credible* sustained heart rate in a workout's HR stream.
///
/// Raw HealthKit maxima are polluted by strap static and optical cadence-lock
/// artifacts — one bad second in six months defines the Health app's reported
/// range. A reading only counts here if it survives a rolling median (which
/// kills 1–2 sample spikes) and holds up as a time-weighted average across a
/// full sustained window. Pure logic, tested in scripts/MaxHREstimationTests.
struct MaxHREstimationService {

    struct HRSample {
        let offset: TimeInterval  // seconds from workout start
        let bpm: Double
    }

    struct SustainedResult {
        /// Best spike-filtered, time-weighted average over a full window —
        /// the credible max. True instantaneous max is typically a beat or
        /// two above this.
        let bestSustainedHR: Double
        /// Unfiltered single-sample max, for comparison against the sustained
        /// value. A large gap between the two means spiky data.
        let rawMaxHR: Double
        /// Samples that deviated far enough from their filtered value to be
        /// counted as artifacts.
        let suspectSampleCount: Int
    }

    /// A max-effort peak must hold this long to count.
    static let sustainedWindow: TimeInterval = 15
    /// A raw sample this far off its median-filtered value is an artifact.
    static let suspectDeviation: Double = 10
    /// Sustained vs raw gaps beyond this mark a workout's data as spiky.
    static let spikyDataGap: Double = 8

    // One sample before a recording gap can't stand in for the whole gap.
    // Scaled to the window (unlike LTHR's fixed 10s cap inside a 20-minute
    // window) — at 15s, an uncapped gap sample could be most of the average.
    private static let maxWeightFractionOfWindow = 1.0 / 3.0
    // A window must genuinely span (window − tolerance) seconds…
    private static let windowSpanTolerance: TimeInterval = 3
    // …with samples covering at least this fraction of it.
    private static let minimumCoverageFraction = 0.8
    private static let medianHalfWidth = 2

    /// Returns nil when the samples can't fill a single valid window.
    static func bestSustained(samples: [HRSample],
                              window: TimeInterval = sustainedWindow) -> SustainedResult? {
        guard samples.count > 2 * medianHalfWidth else { return nil }

        let sorted = samples.sorted { $0.offset < $1.offset }
        let raw = sorted.map(\.bpm)
        let filtered = medianFiltered(raw)

        // Time-weight each sample by the seconds until the next one, so mixed
        // sampling rates (Peloton ~1 Hz, Watch ~0.2 Hz) average fairly.
        let weightCap = window * maxWeightFractionOfWindow
        var weights = [Double](repeating: 1.0, count: sorted.count)
        for i in 0..<(sorted.count - 1) {
            weights[i] = min(max(sorted[i + 1].offset - sorted[i].offset, 0), weightCap)
        }

        var best = 0.0
        var start = 0
        var weightedSum = 0.0
        var weightTotal = 0.0

        for end in sorted.indices {
            weightedSum += filtered[end] * weights[end]
            weightTotal += weights[end]

            while start < end, sorted[end].offset - sorted[start].offset > window {
                weightedSum -= filtered[start] * weights[start]
                weightTotal -= weights[start]
                start += 1
            }

            let span = sorted[end].offset - sorted[start].offset
            if span >= window - windowSpanTolerance,
               weightTotal >= window * minimumCoverageFraction {
                best = max(best, weightedSum / weightTotal)
            }
        }

        guard best > 0 else { return nil }

        let suspects = zip(raw, filtered).filter { abs($0 - $1) > suspectDeviation }.count
        return SustainedResult(bestSustainedHR: best,
                               rawMaxHR: raw.max() ?? 0,
                               suspectSampleCount: suspects)
    }

    /// Rolling median (window of 5, clipped at the edges): removes spikes of
    /// 1–2 samples while leaving genuine plateaus untouched.
    private static func medianFiltered(_ values: [Double]) -> [Double] {
        values.indices.map { i in
            let lo = max(0, i - medianHalfWidth)
            let hi = min(values.count - 1, i + medianHalfWidth)
            let neighborhood = values[lo...hi].sorted()
            return neighborhood[neighborhood.count / 2]
        }
    }
}
