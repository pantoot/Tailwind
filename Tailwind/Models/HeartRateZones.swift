import Foundation
import SwiftUI

// Heart Rate Training Zones based on Lactate Threshold Heart Rate (LTHR)
struct HeartRateZones: Codable {
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
    }

    // Zone ranges as percentages of LTHR
    func range(for zone: Zone) -> ClosedRange<Int> {
        let lower: Int
        let upper: Int

        switch zone {
        case .zone1:
            lower = 0
            upper = Int(Double(lthr) * 0.80)
        case .zone2:
            lower = Int(Double(lthr) * 0.81)
            upper = Int(Double(lthr) * 0.89)
        case .zone3:
            lower = Int(Double(lthr) * 0.90)
            upper = Int(Double(lthr) * 0.93)
        case .zone4:
            lower = Int(Double(lthr) * 0.94)
            upper = Int(Double(lthr) * 0.99)
        case .zone5:
            lower = lthr
            upper = 220  // Effectively unlimited
        }

        return lower...upper
    }

    // Get zone for a given heart rate
    func zone(for heartRate: Int) -> Zone {
        for zone in Zone.allCases {
            if range(for: zone).contains(heartRate) {
                return zone
            }
        }
        return .zone1  // Default to recovery if below all zones
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
struct TimeInZone: Codable {
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
