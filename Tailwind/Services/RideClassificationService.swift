import Foundation

/// Classifies a ride on two independent axes — how *hard* it was (intensity,
/// from IF) and how *even* it was (structure, from variability index) — plus
/// the one flag the power charts need: whether the ride's 30-second peak is a
/// real burst or just its cruising power sampled at its best half-minute.
///
/// Computed on demand, never stored: intensity is a function of current FTP,
/// so a stored label would go stale the moment FTP is retested. Classification
/// never feeds TSS — rescoring training load is a separate decision blocked on
/// the FTP retest.
///
/// **Effort blocks are deliberately not a structure signal.** `EffortBlockService`
/// uses an absolute Z3 floor (76% FTP), so a steady ride cruising just under
/// that floor emits blocks at 1.08–1.16× its own average: a measured 1-hour
/// steady ride (NP 192, avg 188, VI 1.02) produced six of them. Any block-count
/// rule loose enough to catch real intervals misfires on exactly that ride, so
/// structure is variability-led and blocks stay a display-only feature.
nonisolated struct RideClassificationService {

    /// Primitives only — no `Ride`, no `UserProfile`. Keeps the core
    /// compilable by the standalone test harness, which cannot pull in
    /// Ride.swift's CoreLocation/HealthKit dependency chain. The `Ride`-shaped
    /// convenience lives in RideClassificationService+Ride.swift.
    struct Input {
        let duration: TimeInterval
        let averagePower: Double?
        let normalizedPower: Double?
        let max30sPower: Double?
        let matchCount: Int
        let averageHeartRate: Double?
        let ftp: Int?
        let lthr: Int?

        init(
            duration: TimeInterval,
            averagePower: Double? = nil,
            normalizedPower: Double? = nil,
            max30sPower: Double? = nil,
            matchCount: Int = 0,
            averageHeartRate: Double? = nil,
            ftp: Int? = nil,
            lthr: Int? = nil
        ) {
            self.duration = duration
            self.averagePower = averagePower
            self.normalizedPower = normalizedPower
            self.max30sPower = max30sPower
            self.matchCount = matchCount
            self.averageHeartRate = averageHeartRate
            self.ftp = ftp
            self.lthr = lthr
        }
    }

    enum Structure: String {
        case steady = "Steady"
        case mixed = "Mixed"
        case intervals = "Interval"
        case unknown = ""
    }

    enum Intensity: String {
        case recovery = "Recovery"
        case endurance = "Endurance"
        case tempo = "Tempo"
        case threshold = "Threshold"
        case hard = "Hard"
        case unknown = ""
    }

    /// How much the label should be trusted. `.low` means heart-rate derived,
    /// which for this rider runs hot: +9 rpm adds ~2.8 bpm at matched power in
    /// Z2, and indoor rides run hotter still.
    enum Confidence {
        case high      // normalized power + FTP
        case medium    // average power + FTP (understates IF on variable rides)
        case low       // heart rate only
        case none      // nothing to go on
    }

    struct Classification: Equatable {
        let structure: Structure
        let intensity: Intensity
        let confidence: Confidence
        /// False when max30sPower is a floor artifact rather than a real
        /// effort — gates whether the ride belongs on a burst-power trend.
        let isBurstRepresentative: Bool
        let variabilityIndex: Double?
        let intensityFactor: Double?
        let label: String
        let confidenceNote: String?
    }

    // MARK: - Cut points

    /// Zone-aligned %FTP floors, matching EffortBlockService's 0.76 Z3 floor
    /// and the Z6 match threshold, so a ride's label and its effort blocks
    /// never describe the same watts with different words.
    static let recoveryCeiling = 0.55
    static let enduranceCeiling = 0.76
    static let tempoCeiling = 0.90
    static let thresholdCeiling = 1.05

    /// Variability index: 1.00 is metronomic, >1.15 is interval territory.
    static let steadyCeiling = 1.05
    static let mixedCeiling = 1.15

    /// Two efforts above 120% FTP make a *mixed* ride read as structured — the
    /// escalator applies inside the mixed band only; a steady VI always wins.
    /// There is no matching de-escalator: with FTP unset the match threshold
    /// defaults to 500W, so a zero count never proves steadiness.
    static let matchesForIntervals = 2

    /// A real 30s effort by a rider cruising in Z2/Z3 lands at least half again
    /// above ride average. Below that the "peak" is the cruise itself.
    static let burstPowerRatio = 1.5

    private static let hrNote = "Estimated from heart rate — high cadence and indoor heat both inflate it."
    private static let avgPowerNote = "Estimated from average power — variable rides read easier than they were."

    // MARK: - Classify

    static func classify(_ input: Input) -> Classification {
        guard input.duration >= Constants.Import.minimumWorkoutDuration else {
            return unclassified()
        }

        let vi = variabilityIndex(input)
        let (intensity, factor, confidence, note) = intensityAxis(input)
        let structure = structureAxis(input, vi: vi)

        return Classification(
            structure: structure,
            intensity: intensity,
            confidence: confidence,
            isBurstRepresentative: isBurstRepresentative(input),
            variabilityIndex: vi,
            intensityFactor: factor,
            label: label(structure: structure, intensity: intensity),
            confidenceNote: note
        )
    }

    private static func unclassified() -> Classification {
        Classification(
            structure: .unknown,
            intensity: .unknown,
            confidence: .none,
            isBurstRepresentative: false,
            variabilityIndex: nil,
            intensityFactor: nil,
            label: "Unclassified",
            confidenceNote: nil
        )
    }

    // MARK: - Axes

    static func variabilityIndex(_ input: Input) -> Double? {
        guard let np = input.normalizedPower,
              let avg = input.averagePower,
              avg > 0 else { return nil }
        return np / avg
    }

    /// Power always beats heart rate. A high-cadence Z2 hour reads a full band
    /// too hard on HR, so HR is consulted only when no power IF is computable.
    private static func intensityAxis(
        _ input: Input
    ) -> (Intensity, Double?, Confidence, String?) {
        if let ftp = input.ftp, ftp > 0 {
            if let np = input.normalizedPower, np > 0 {
                let factor = np / Double(ftp)
                return (band(forIF: factor), factor, .high, nil)
            }
            if let avg = input.averagePower, avg > 0 {
                let factor = avg / Double(ftp)
                return (band(forIF: factor), factor, .medium, avgPowerNote)
            }
        }

        if let lthr = input.lthr, lthr > 0,
           let hr = input.averageHeartRate, hr > 0 {
            return (band(forIF: hr / Double(lthr)), nil, .low, hrNote)
        }

        return (.unknown, nil, .none, nil)
    }

    private static func band(forIF factor: Double) -> Intensity {
        switch factor {
        case ..<recoveryCeiling: return .recovery
        case ..<enduranceCeiling: return .endurance
        case ..<tempoCeiling: return .tempo
        case ..<thresholdCeiling: return .threshold
        default: return .hard
        }
    }

    /// Heart rate carries no variability information, so an HR-only ride has
    /// no structure — never a guess.
    private static func structureAxis(_ input: Input, vi: Double?) -> Structure {
        guard let vi else {
            return input.matchCount >= matchesForIntervals ? .intervals : .unknown
        }

        switch vi {
        case ..<steadyCeiling: return .steady
        case ..<mixedCeiling:
            return input.matchCount >= matchesForIntervals ? .intervals : .mixed
        default: return .intervals
        }
    }

    static func isBurstRepresentative(_ input: Input) -> Bool {
        guard input.duration >= Constants.Import.minimumWorkoutDuration,
              let avg = input.averagePower, avg > 0,
              let max30s = input.max30sPower, max30s > 0 else { return false }

        return input.matchCount >= 1 || max30s >= burstPowerRatio * avg
    }

    // MARK: - Import summary copy

    /// Semantic tone, mapped to a color by the view. A three-hour endurance
    /// ride is a big day but not a hard one, so tone follows intensity — never
    /// raw TSS, which conflates volume with intensity.
    enum SummaryTone {
        case easy, moderate, hard, veryHard
    }

    struct SummaryCopy: Equatable {
        let label: String
        let interpretation: String
        let tone: SummaryTone
        /// 0–1 for the gauge ring. Tracks intensity when known so the ring and
        /// the word inside it measure the same thing.
        let ringProgress: Double
    }

    static func summaryCopy(for classification: Classification, tss: Double) -> SummaryCopy {
        guard classification.intensity != .unknown else {
            return legacyCopy(tss: tss)
        }

        let tone: SummaryTone
        switch classification.intensity {
        case .recovery, .endurance: tone = .easy
        case .tempo: tone = .moderate
        case .threshold: tone = .hard
        case .hard: tone = .veryHard
        case .unknown: tone = .moderate
        }

        let ring: Double
        if let factor = classification.intensityFactor {
            ring = min(factor / thresholdCeiling, 1.0)
        } else {
            ring = min(tss / 150, 1.0)
        }

        return SummaryCopy(
            label: classification.intensity.rawValue,
            interpretation: "\(classification.label) — \(Int(tss.rounded())) TSS, \(volumeClause(tss: tss))",
            tone: tone,
            ringProgress: ring
        )
    }

    private static func volumeClause(tss: Double) -> String {
        if tss < 50 { return "low stress" }
        if tss < 100 { return "moderate stress" }
        if tss < 150 { return "significant stress" }
        return "a big day"
    }

    /// Verbatim pre-classification copy, kept for rides with nothing to
    /// classify from so they never regress to a blank label.
    private static func legacyCopy(tss: Double) -> SummaryCopy {
        if tss < 50 {
            return SummaryCopy(label: "Easy", interpretation: "Recovery ride - low stress",
                               tone: .easy, ringProgress: min(tss / 150, 1.0))
        }
        if tss < 100 {
            return SummaryCopy(label: "Moderate", interpretation: "Moderate effort - good training",
                               tone: .moderate, ringProgress: min(tss / 150, 1.0))
        }
        if tss < 150 {
            return SummaryCopy(label: "Hard", interpretation: "Hard workout - significant stress",
                               tone: .hard, ringProgress: min(tss / 150, 1.0))
        }
        return SummaryCopy(label: "Very Hard", interpretation: "Very hard - extended recovery needed",
                           tone: .veryHard, ringProgress: 1.0)
    }

    private static func label(structure: Structure, intensity: Intensity) -> String {
        switch (structure, intensity) {
        case (.unknown, .unknown):
            return "Unclassified"
        case (.unknown, _):
            return intensity.rawValue
        case (_, .unknown):
            return structure.rawValue
        default:
            return "\(structure.rawValue) \(intensity.rawValue.lowercased())"
        }
    }
}
