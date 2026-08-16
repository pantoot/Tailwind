import Foundation

/// Detects sustained work intervals ("effort blocks") in a ride's 1Hz power
/// stream — the Z3/Z4 blocks of a structured class — and measures the HR cost
/// of each block plus the recovery once it ends.
///
/// Detection: 30s-centered smoothed power held above a threshold for at least
/// 2 minutes, with sub-30s dips merged so a momentary soft-pedal doesn't split
/// a block. The threshold is the Zone 3 floor (76% FTP) when FTP is set —
/// low enough to catch tempo blocks, high enough that recovery valleys
/// (Z1/Z2) break them apart. Without an FTP it falls back to 110% of the
/// ride's own average power, so a steady ride yields no blocks.
nonisolated struct EffortBlockService {

    static let smoothingWindowSeconds = 30
    static let minimumBlockSeconds = 120
    static let mergeGapSeconds = 30
    static let recoveryWindowSeconds = 90
    static let zone3FloorFraction = 0.76
    static let fallbackThresholdFraction = 1.10
    /// Below this average power the ride is too sparse to segment meaningfully.
    static let minimumAveragePowerWatts = 50.0
    /// A dense HR array that never exceeds this is a missing signal, not data.
    static let minimumPlausibleHR = 30.0

    /// - Parameters:
    ///   - densePower: 1Hz power aligned to `baseTime` (from buildDenseArray).
    ///   - denseHR: 1Hz heart rate on the same grid; all-zero when absent.
    ///   - ftp: the rider's FTP, if set.
    ///   - offset: seconds from ride start to the first array element, so
    ///     block offsets line up with match/recovery offsets.
    static func detectBlocks(
        densePower: [Double],
        denseHR: [Double],
        ftp: Int?,
        offset: TimeInterval
    ) -> [EffortBlock] {
        guard densePower.count >= minimumBlockSeconds else { return [] }

        let averagePower = densePower.reduce(0, +) / Double(densePower.count)
        guard averagePower >= minimumAveragePowerWatts else { return [] }

        let threshold: Double
        if let ftp = ftp, ftp > 0 {
            threshold = Double(ftp) * zone3FloorFraction
        } else {
            threshold = averagePower * fallbackThresholdFraction
        }

        let smoothed = centeredMovingAverage(densePower, window: smoothingWindowSeconds)
        let ranges = blockRanges(in: smoothed, threshold: threshold)
        let hasHR = (denseHR.max() ?? 0) > minimumPlausibleHR

        return ranges.map { range in
            let powerSlice = densePower[range]
            let avgPower = powerSlice.reduce(0, +) / Double(powerSlice.count)

            var averageHR: Double?
            var startHR: Int?
            var endHR: Int?
            var recoveryDelta: Int?
            if hasHR {
                let hrSlice = denseHR[range]
                averageHR = hrSlice.reduce(0, +) / Double(hrSlice.count)
                startHR = Int(edgeMean(denseHR, at: range.lowerBound, leading: true))
                let blockEndHR = edgeMean(denseHR, at: range.upperBound, leading: false)
                endHR = Int(blockEndHR)
                if range.upperBound + recoveryWindowSeconds <= denseHR.count {
                    let recoveredHR = edgeMean(denseHR, at: range.upperBound + recoveryWindowSeconds, leading: false)
                    recoveryDelta = Int((blockEndHR - recoveredHR).rounded())
                }
            }

            return EffortBlock(
                id: UUID(),
                startOffset: TimeInterval(range.lowerBound) + offset,
                duration: TimeInterval(range.count),
                averagePower: avgPower,
                averageHR: averageHR,
                startHR: startHR,
                endHR: endHR,
                recoveryDelta: recoveryDelta
            )
        }
    }

    // MARK: - Segmentation

    /// Contiguous stretches where `smoothed` stays at or above `threshold`,
    /// tolerating dips up to `mergeGapSeconds`, keeping only stretches of at
    /// least `minimumBlockSeconds`.
    private static func blockRanges(in smoothed: [Double], threshold: Double) -> [Range<Int>] {
        var ranges: [Range<Int>] = []
        var start: Int?
        var lastAbove = 0

        for (i, value) in smoothed.enumerated() {
            if value >= threshold {
                if start == nil { start = i }
                lastAbove = i
            } else if let s = start, i - lastAbove > mergeGapSeconds {
                if lastAbove + 1 - s >= minimumBlockSeconds {
                    ranges.append(s..<(lastAbove + 1))
                }
                start = nil
            }
        }
        if let s = start, lastAbove + 1 - s >= minimumBlockSeconds {
            ranges.append(s..<(lastAbove + 1))
        }
        return ranges
    }

    // MARK: - Helpers

    private static func centeredMovingAverage(_ data: [Double], window: Int) -> [Double] {
        guard data.count > 1, window > 1 else { return data }
        let half = window / 2
        var result = [Double](repeating: 0, count: data.count)
        for i in 0..<data.count {
            let lo = max(0, i - half)
            let hi = min(data.count, i + half)
            result[i] = data[lo..<hi].reduce(0, +) / Double(hi - lo)
        }
        return result
    }

    /// Mean of ~10s of samples touching `index`: the 10s after it when
    /// `leading`, the 10s before it otherwise. Used for stable HR readings at
    /// block edges instead of a single noisy sample.
    private static func edgeMean(_ data: [Double], at index: Int, leading: Bool) -> Double {
        let lo = leading ? index : max(0, index - 10)
        let hi = leading ? min(data.count, index + 10) : index
        guard hi > lo else { return data[max(0, min(index, data.count - 1))] }
        return data[lo..<hi].reduce(0, +) / Double(hi - lo)
    }
}
