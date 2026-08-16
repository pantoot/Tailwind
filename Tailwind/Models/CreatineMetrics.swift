import Foundation

nonisolated struct CreatineMetrics: Codable {
    let max30sPower: Double
    let matchCount: Int
    let matches: [PowerMatch]
    let hrRecoveryEvents: [HRRecoveryEvent]
    let averagePower: Double
    // Optional so rides analyzed before these metrics existed decode as nil;
    // "Reanalyze Power Data" backfills them.
    let normalizedPower: Double?
    let effortBlocks: [EffortBlock]?
}

/// A sustained work interval (e.g. a Peloton Z3/Z4 block) detected from
/// smoothed power, with the HR cost of holding it and how far HR fell once
/// the effort ended. HR fields are nil on rides without a heart-rate signal.
nonisolated struct EffortBlock: Codable, Identifiable {
    let id: UUID
    let startOffset: TimeInterval    // seconds from ride start
    let duration: TimeInterval
    let averagePower: Double
    let averageHR: Double?
    let startHR: Int?
    let endHR: Int?
    /// HR drop over the 90s after the block ends. Nil when the ride ends first.
    let recoveryDelta: Int?
}

nonisolated struct PowerMatch: Codable, Identifiable {
    let id: UUID
    let startOffset: TimeInterval    // seconds from ride start
    let duration: TimeInterval
    let peakPower: Double            // 3s-smoothed peak
    let averagePower: Double
}

nonisolated struct HRRecoveryEvent: Codable, Identifiable {
    let id: UUID
    let startOffset: TimeInterval
    let peakHR: Int
    let hrAt60s: Int
    let recoveryDelta: Int           // peakHR - hrAt60s (bigger = better)
    let recoveryType: RecoveryType

    enum RecoveryType: String, Codable {
        case coasting   // avg speed > 3mph during 60s window
        case stopped    // avg speed ~0
    }
}
