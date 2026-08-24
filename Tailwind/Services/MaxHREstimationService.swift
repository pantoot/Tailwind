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
        /// Best spike-filtered, time-weighted average over a full window of
        /// credible samples — the credible max. True instantaneous max is
        /// typically a beat or two above this.
        let bestSustainedHR: Double
        /// Unfiltered single-sample max, for comparison against the sustained
        /// value. A large gap between the two means spiky data.
        let rawMaxHR: Double
        /// Samples that deviated far enough from their filtered value to be
        /// counted as artifacts.
        let suspectSampleCount: Int
        /// Highest sustained window rejected by the continuity check (nil when
        /// nothing higher than the credible best was rejected). Surfaced so a
        /// discarded strap-doubling block is visible, not silently dropped.
        let rejectedPeakHR: Double?
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

    // Continuity: real HR is continuous — reaching a peak means climbing
    // through the values below it. A sample is credible only if it sits
    // within this margin of the workout's median HR or of a credible sample
    // in the trailing minute. A chest strap doubling to 2× real HR, or an
    // optical sensor locking onto cadence, steps there discontinuously and
    // fails this check even when the bogus block lasts minutes.
    private static let continuityMargin: Double = 30
    private static let continuityLookback: TimeInterval = 60

    /// Returns nil when the samples can't fill a single valid window.
    static func bestSustained(samples: [HRSample],
                              window: TimeInterval = sustainedWindow) -> SustainedResult? {
        guard samples.count > 2 * medianHalfWidth else { return nil }

        let sorted = samples.sorted { $0.offset < $1.offset }
        let raw = sorted.map(\.bpm)
        let filtered = medianFiltered(raw)
        let credible = credibilityMask(offsets: sorted.map(\.offset), filtered: filtered)

        // Time-weight each sample by the seconds until the next one, so mixed
        // sampling rates (Peloton ~1 Hz, Watch ~0.2 Hz) average fairly.
        let weightCap = window * maxWeightFractionOfWindow
        var weights = [Double](repeating: 1.0, count: sorted.count)
        for i in 0..<(sorted.count - 1) {
            weights[i] = min(max(sorted[i + 1].offset - sorted[i].offset, 0), weightCap)
        }

        var best = 0.0
        var bestRejected = 0.0
        var start = 0
        var weightedSum = 0.0
        var weightTotal = 0.0
        var nonCredibleInWindow = 0

        for end in sorted.indices {
            weightedSum += filtered[end] * weights[end]
            weightTotal += weights[end]
            if !credible[end] { nonCredibleInWindow += 1 }

            while start < end, sorted[end].offset - sorted[start].offset > window {
                weightedSum -= filtered[start] * weights[start]
                weightTotal -= weights[start]
                if !credible[start] { nonCredibleInWindow -= 1 }
                start += 1
            }

            let span = sorted[end].offset - sorted[start].offset
            if span >= window - windowSpanTolerance,
               weightTotal >= window * minimumCoverageFraction {
                let avg = weightedSum / weightTotal
                if nonCredibleInWindow == 0 {
                    best = max(best, avg)
                } else {
                    bestRejected = max(bestRejected, avg)
                }
            }
        }

        guard best > 0 else { return nil }

        let suspects = zip(raw, filtered).filter { abs($0 - $1) > suspectDeviation }.count
        return SustainedResult(bestSustainedHR: best,
                               rawMaxHR: raw.max() ?? 0,
                               suspectSampleCount: suspects,
                               rejectedPeakHR: bestRejected > best ? bestRejected : nil)
    }

    /// Continuity mask: true where the filtered value was reached plausibly.
    /// Support for a sample is the workout's median HR or any credible sample
    /// in the trailing minute, whichever is higher; a sample more than the
    /// continuity margin above its support stepped there discontinuously and
    /// is not credible. Non-credible samples never become support themselves,
    /// so a sustained bogus block cannot legitimize its own tail.
    private static func credibilityMask(offsets: [TimeInterval], filtered: [Double]) -> [Bool] {
        let median = filtered.sorted()[filtered.count / 2]

        var mask = [Bool](repeating: false, count: filtered.count)
        // Indices of credible samples in the trailing lookback, values
        // non-increasing (monotonic max deque).
        var trailing: [Int] = []

        for i in filtered.indices {
            while let first = trailing.first,
                  offsets[i] - offsets[first] > continuityLookback {
                trailing.removeFirst()
            }
            let support = max(median, trailing.first.map { filtered[$0] } ?? median)
            guard filtered[i] <= support + continuityMargin else { continue }

            mask[i] = true
            while let last = trailing.last, filtered[last] <= filtered[i] {
                trailing.removeLast()
            }
            trailing.append(i)
        }
        return mask
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
