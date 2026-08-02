import Foundation

/// Analyzes raw 1Hz FIT data for creatine-relevant metrics:
/// burst power, sprint matches, max 30s power, and HR recovery events.
struct CreatineAnalysisService {

    /// Main entry point — called during FIT import with raw 1Hz streams.
    /// Returns nil if no power data exists (no power meter on ride).
    static func analyze(
        power: [(date: Date, watts: Double)],
        heartRate: [(date: Date, bpm: Double)],
        speed: [(date: Date, metersPerSecond: Double)],
        rideStart: Date,
        settings: CreatineSettings
    ) -> CreatineMetrics? {
        guard !power.isEmpty else { return nil }

        // Build dense 1-second arrays aligned to ride start
        let duration = Int(power.last!.date.timeIntervalSince(power.first!.date)) + 1
        guard duration > 0 else { return nil }

        let baseTime = power.first!.date
        let densePower = buildDenseArray(from: power.map { (date: $0.date, value: $0.watts) }, baseTime: baseTime, count: duration)
        let denseHR = buildDenseArray(from: heartRate.map { (date: $0.date, value: $0.bpm) }, baseTime: baseTime, count: duration)
        let denseSpeed = buildDenseArray(from: speed.map { (date: $0.date, value: $0.metersPerSecond) }, baseTime: baseTime, count: duration)

        // 3-second smoothed power
        let smoothedPower = smooth3s(densePower)

        // Algorithm 1: Match detection
        let matches = detectMatches(
            smoothedPower: smoothedPower,
            threshold: settings.effectiveMatchThreshold,
            rideStart: rideStart,
            baseTime: baseTime
        )

        // Algorithm 2: Max 30-second power
        let max30s = maxRollingAverage(densePower, windowSize: 30)

        // Algorithm 3: HR recovery events
        let userProfile = UserProfile.load()
        // Recovery power threshold: Zone 1 ceiling (55% FTP) for indoor/Peloton, or 25W fallback
        let recoveryPowerThreshold: Double = {
            if let ftp = userProfile.ftp {
                return Double(ftp) * 0.55
            }
            return 25.0
        }()
        let hrRecoveryEvents = detectHRRecovery(
            denseHR: denseHR,
            densePower: densePower,
            denseSpeed: denseSpeed,
            maxHR: userProfile.estimatedMaxHR,
            recoveryPowerThreshold: recoveryPowerThreshold,
            rideStart: rideStart,
            baseTime: baseTime
        )

        // Average power (from raw, not smoothed)
        let avgPower = densePower.reduce(0, +) / Double(densePower.count)

        return CreatineMetrics(
            max30sPower: max30s,
            matchCount: matches.count,
            matches: matches,
            hrRecoveryEvents: hrRecoveryEvents,
            averagePower: avgPower
        )
    }

    // MARK: - Dense Array Builder

    /// Interpolates sparse timestamped samples into a dense 1-second array.
    /// Fills gaps with linear interpolation, handles Magene connection drops.
    private static func buildDenseArray(
        from samples: [(date: Date, value: Double)],
        baseTime: Date,
        count: Int
    ) -> [Double] {
        var result = [Double](repeating: 0, count: count)
        guard !samples.isEmpty else { return result }

        // Place known samples
        var knownIndices: [(index: Int, value: Double)] = []
        for sample in samples {
            let index = Int(sample.date.timeIntervalSince(baseTime))
            if index >= 0 && index < count {
                result[index] = sample.value
                knownIndices.append((index: index, value: sample.value))
            }
        }

        guard knownIndices.count >= 2 else {
            // Single sample or empty — fill entire array with that value
            if let single = knownIndices.first {
                result = [Double](repeating: single.value, count: count)
            }
            return result
        }

        // Linear interpolation between known points
        for i in 0..<(knownIndices.count - 1) {
            let from = knownIndices[i]
            let to = knownIndices[i + 1]
            let gap = to.index - from.index
            if gap <= 1 { continue }
            for j in (from.index + 1)..<to.index {
                let t = Double(j - from.index) / Double(gap)
                result[j] = from.value + t * (to.value - from.value)
            }
        }

        // Extend edges
        if let first = knownIndices.first {
            for i in 0..<first.index { result[i] = first.value }
        }
        if let last = knownIndices.last {
            for i in (last.index + 1)..<count { result[i] = last.value }
        }

        return result
    }

    // MARK: - 3-Second Smoothing

    /// Centered 3-second moving average. Edges use 2-sample window.
    private static func smooth3s(_ data: [Double]) -> [Double] {
        guard data.count >= 2 else { return data }
        var smoothed = [Double](repeating: 0, count: data.count)

        smoothed[0] = (data[0] + data[1]) / 2.0
        smoothed[data.count - 1] = (data[data.count - 2] + data[data.count - 1]) / 2.0

        for i in 1..<(data.count - 1) {
            smoothed[i] = (data[i - 1] + data[i] + data[i + 1]) / 3.0
        }

        return smoothed
    }

    // MARK: - Match Detection

    /// Detect power "matches" — contiguous periods above threshold lasting >5 seconds.
    private static func detectMatches(
        smoothedPower: [Double],
        threshold: Double,
        rideStart: Date,
        baseTime: Date
    ) -> [PowerMatch] {
        var matches: [PowerMatch] = []
        let offset = baseTime.timeIntervalSince(rideStart)
        var i = 0

        while i < smoothedPower.count {
            if smoothedPower[i] >= threshold {
                let start = i
                var peak = smoothedPower[i]
                var sum = smoothedPower[i]

                i += 1
                while i < smoothedPower.count && smoothedPower[i] >= threshold {
                    peak = max(peak, smoothedPower[i])
                    sum += smoothedPower[i]
                    i += 1
                }

                let duration = i - start
                if duration > 5 {
                    matches.append(PowerMatch(
                        id: UUID(),
                        startOffset: Double(start) + offset,
                        duration: Double(duration),
                        peakPower: peak,
                        averagePower: sum / Double(duration)
                    ))
                }
            } else {
                i += 1
            }
        }

        return matches
    }

    // MARK: - Max Rolling Average

    /// Sliding window maximum average power.
    private static func maxRollingAverage(_ data: [Double], windowSize: Int) -> Double {
        guard data.count >= windowSize else {
            // If ride is shorter than window, use entire ride
            guard !data.isEmpty else { return 0 }
            return data.reduce(0, +) / Double(data.count)
        }

        var maxAvg = 0.0
        var windowSum = data[0..<windowSize].reduce(0, +)
        maxAvg = windowSum / Double(windowSize)

        for i in windowSize..<data.count {
            windowSum += data[i] - data[i - windowSize]
            let avg = windowSum / Double(windowSize)
            if avg > maxAvg { maxAvg = avg }
        }

        return maxAvg
    }

    // MARK: - HR Recovery Detection

    /// Detect recovery events: HR spikes followed by power drops with 60s measurement window.
    private static func detectHRRecovery(
        denseHR: [Double],
        densePower: [Double],
        denseSpeed: [Double],
        maxHR: Int,
        recoveryPowerThreshold: Double,
        rideStart: Date,
        baseTime: Date
    ) -> [HRRecoveryEvent] {
        guard denseHR.count > 60 else { return [] }

        let hrThreshold = Double(maxHR) * 0.85
        let offset = baseTime.timeIntervalSince(rideStart)
        var events: [HRRecoveryEvent] = []
        var i = 0

        while i < denseHR.count - 60 {
            // Step 1: Find HR above threshold
            guard denseHR[i] >= hrThreshold else {
                i += 1
                continue
            }

            // Step 2: Look for power drop to recovery zone within next few seconds
            var powerDropIndex: Int? = nil
            let searchEnd = min(i + 5, densePower.count - 60)
            for j in i..<searchEnd {
                if j < densePower.count && densePower[j] < recoveryPowerThreshold {
                    powerDropIndex = j
                    break
                }
            }

            guard let dropStart = powerDropIndex else {
                i += 1
                continue
            }

            // Step 3: Verify power stays in recovery zone for 60+ seconds
            // Allow brief spikes <5 seconds (shifting gears, standing, etc.)
            var lowPowerSeconds = 0
            var spikeSeconds = 0
            var valid = true

            for j in dropStart..<min(dropStart + 60, densePower.count) {
                if densePower[j] < recoveryPowerThreshold {
                    lowPowerSeconds += 1
                    spikeSeconds = 0
                } else {
                    spikeSeconds += 1
                    if spikeSeconds > 5 {
                        valid = false
                        break
                    }
                }
            }

            guard valid && lowPowerSeconds >= 50 else {
                i += 10
                continue
            }

            // Step 4: Record peak HR (check 2s window around drop for sensor lag)
            let lagStart = max(0, dropStart - 2)
            let lagEnd = min(denseHR.count, dropStart + 3)
            let peakHR = Int(denseHR[lagStart..<lagEnd].max() ?? denseHR[dropStart])

            // HR at 60 seconds after power drop
            let hr60Index = min(dropStart + 60, denseHR.count - 1)
            let hrAt60s = Int(denseHR[hr60Index])

            // Step 5: Classify recovery type based on speed during 60s window
            let speedWindow = denseSpeed[dropStart..<min(dropStart + 60, denseSpeed.count)]
            let avgSpeedMph = (speedWindow.reduce(0, +) / Double(speedWindow.count)) * 2.23694
            let recoveryType: HRRecoveryEvent.RecoveryType = avgSpeedMph > 3.0 ? .coasting : .stopped

            events.append(HRRecoveryEvent(
                id: UUID(),
                startOffset: Double(dropStart) + offset,
                peakHR: peakHR,
                hrAt60s: hrAt60s,
                recoveryDelta: peakHR - hrAt60s,
                recoveryType: recoveryType
            ))

            // Step 6: Skip ahead 90s to avoid overlapping detections
            i = dropStart + 90
        }

        return events
    }
}
