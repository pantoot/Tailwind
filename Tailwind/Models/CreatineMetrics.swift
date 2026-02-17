import Foundation

struct CreatineMetrics: Codable {
    let max30sPower: Double
    let matchCount: Int
    let matches: [PowerMatch]
    let hrRecoveryEvents: [HRRecoveryEvent]
    let averagePower: Double
}

struct PowerMatch: Codable, Identifiable {
    let id: UUID
    let startOffset: TimeInterval    // seconds from ride start
    let duration: TimeInterval
    let peakPower: Double            // 3s-smoothed peak
    let averagePower: Double
}

struct HRRecoveryEvent: Codable, Identifiable {
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
