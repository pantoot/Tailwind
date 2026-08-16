import Foundation
import SwiftUI

// Heart Rate Training Zones based on Lactate Threshold Heart Rate (LTHR)
nonisolated struct HeartRateZones: Codable {
    let lthr: Int

    // 5-Zone model based on LTHR
    enum Zone: Int, CaseIterable, Codable {
        case zone1 = 1  // Recovery
        case zone2 = 2  // Endurance
        case zone3 = 3  // Tempo
        case zone4 = 4  // Threshold
        case zone5 = 5  // VO2 Max

        var name: String {
            switch self {
            case .zone1: return "Recovery"
            case .zone2: return "Endurance"
            case .zone3: return "Tempo"
            case .zone4: return "Threshold"
            case .zone5: return "VO2 Max"
            }
        }

        var description: String {
            switch self {
            case .zone1: return "Active recovery, easy spinning"
            case .zone2: return "Base building, fat burning"
            case .zone3: return "Sustained aerobic effort"
            case .zone4: return "Lactate threshold, race pace"
            case .zone5: return "Maximum aerobic capacity"
            }
        }

        var color: Color {
            switch self {
            case .zone1: return .gray
            case .zone2: return .blue
            case .zone3: return .green
            case .zone4: return .yellow
            case .zone5: return .red
            }
        }

        // TSS multiplier for hrTSS calculation
        // Based on relative intensity in each zone
        var tssMultiplier: Double {
            switch self {
            case .zone1: return 0.4   // 40 TSS per hour
            case .zone2: return 0.6   // 60 TSS per hour
            case .zone3: return 0.8   // 80 TSS per hour
            case .zone4: return 1.0   // 100 TSS per hour (by definition)
            case .zone5: return 1.2   // 120 TSS per hour
            }
        }

        /// Where the zone starts, as a fraction of LTHR.
        ///
        /// These are Joe Friel's LTHR zone floors, chosen deliberately — NOT the
        /// Coggan levels (which put Z2 at 69% and Z5 at 106%). Friel's tighter
        /// bands suit HR-based scoring for steady riding; anything comparing these
        /// zones to Coggan-labeled sources should expect the offset.
        ///
        /// Zones are defined by their floor alone. The textbook table quotes closed
        /// bands (Z2 = 81–89%, Z3 = 90–93%), but truncating *both* edges to whole
        /// beats leaves beats that no band claims — at LTHR 150 nothing owned 134,
        /// 140, or 149, and those samples fell through to Zone 1 and were scored as
        /// recovery. Deriving each ceiling from the next zone's floor makes the
        /// bands tile the integers, so a gap cannot reappear.
        var lowerBoundFraction: Double {
            switch self {
            case .zone1: return 0
            case .zone2: return 0.81
            case .zone3: return 0.90
            case .zone4: return 0.94
            case .zone5: return 1.00  // LTHR itself
            }
        }
    }

    /// Ceiling of the top zone. Heart rates above it still score as Zone 5 —
    /// `zone(for:)` compares against floors, so it has no upper bound to escape.
    static let maximumHeartRate = 220

    /// First beat belonging to the zone.
    func lowerBound(for zone: Zone) -> Int {
        Int(Double(lthr) * zone.lowerBoundFraction)
    }

    // Zone ranges as percentages of LTHR
    func range(for zone: Zone) -> ClosedRange<Int> {
        let lower = lowerBound(for: zone)

        guard let next = Zone(rawValue: zone.rawValue + 1) else {
            return lower...max(lower, Self.maximumHeartRate)
        }

        // `max` guards a nonsensically low LTHR, where two floors can truncate to
        // the same beat and would otherwise form an invalid (crashing) range.
        return lower...max(lower, lowerBound(for: next) - 1)
    }

    // Get zone for a given heart rate
    func zone(for heartRate: Int) -> Zone {
        // Highest zone whose floor the heart rate has reached. Gap-free by
        // construction, and unlike a range scan it still classifies a sensor
        // glitch above `maximumHeartRate` as Zone 5 rather than recovery.
        Zone.allCases.last { heartRate >= lowerBound(for: $0) } ?? .zone1
    }

    // Get zone as a String for display
    func zoneString(for heartRate: Int) -> String {
        let zone = zone(for: heartRate)
        return "Z\(zone.rawValue)"
    }

    // Get percentage of LTHR
    func percentageOfLTHR(heartRate: Int) -> Int {
        Int((Double(heartRate) / Double(lthr)) * 100)
    }
}

// Time in zone tracking for rides
nonisolated struct TimeInZone: Codable {
    var zone1Seconds: TimeInterval = 0
    var zone2Seconds: TimeInterval = 0
    var zone3Seconds: TimeInterval = 0
    var zone4Seconds: TimeInterval = 0
    var zone5Seconds: TimeInterval = 0

    mutating func add(seconds: TimeInterval, for zone: HeartRateZones.Zone) {
        switch zone {
        case .zone1: zone1Seconds += seconds
        case .zone2: zone2Seconds += seconds
        case .zone3: zone3Seconds += seconds
        case .zone4: zone4Seconds += seconds
        case .zone5: zone5Seconds += seconds
        }
    }

    func seconds(for zone: HeartRateZones.Zone) -> TimeInterval {
        switch zone {
        case .zone1: return zone1Seconds
        case .zone2: return zone2Seconds
        case .zone3: return zone3Seconds
        case .zone4: return zone4Seconds
        case .zone5: return zone5Seconds
        }
    }

    func minutes(for zone: HeartRateZones.Zone) -> Double {
        seconds(for: zone) / 60.0
    }

    var totalSeconds: TimeInterval {
        zone1Seconds + zone2Seconds + zone3Seconds + zone4Seconds + zone5Seconds
    }

    func percentage(for zone: HeartRateZones.Zone) -> Double {
        guard totalSeconds > 0 else { return 0 }
        return (seconds(for: zone) / totalSeconds) * 100
    }

    // Calculate hrTSS (Heart Rate Training Stress Score)
    func calculateHrTSS() -> Double {
        var tss: Double = 0

        for zone in HeartRateZones.Zone.allCases {
            let hours = seconds(for: zone) / 3600.0
            tss += hours * zone.tssMultiplier * 100
        }

        return tss
    }
}
