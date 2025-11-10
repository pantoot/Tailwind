import Foundation
import SwiftUI
import Combine

// Performance Management Chart - CTL, ATL, TSB tracking
// Based on TrainingPeaks methodology for cycling training load

struct DailyTrainingLoad: Codable, Identifiable {
    let id: UUID
    let date: Date
    let tss: Double  // Training Stress Score for the day

    init(id: UUID = UUID(), date: Date, tss: Double) {
        self.id = id
        self.date = date
        self.tss = tss
    }

    // Normalize date to start of day for comparison
    var dateKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

// Performance Management Chart calculations
struct PerformanceMetrics {
    let ctl: Double  // Chronic Training Load (Fitness) - 42 day exponential average
    let atl: Double  // Acute Training Load (Fatigue) - 7 day exponential average
    let tsb: Double  // Training Stress Balance (Form) = CTL - ATL

    // Interpretation helpers
    var formStatus: FormStatus {
        if tsb >= 25 {
            return .fresh
        } else if tsb >= 5 {
            return .rested
        } else if tsb >= -10 {
            return .optimal
        } else if tsb >= -30 {
            return .productive
        } else {
            return .overreaching
        }
    }

    enum FormStatus: String {
        case fresh = "Very Fresh"
        case rested = "Rested"
        case optimal = "Optimal"
        case productive = "Productive Fatigue"
        case overreaching = "Deep Fatigue"

        var color: Color {
            switch self {
            case .fresh: return .cyan
            case .rested: return .green
            case .optimal: return .yellow
            case .productive: return .orange
            case .overreaching: return .red
            }
        }

        var description: String {
            switch self {
            case .fresh:
                return "You're very fresh! Consider a hard workout or race."
            case .rested:
                return "Well rested and ready for quality training."
            case .optimal:
                return "Great balance - maintain this training load."
            case .productive:
                return "Building fitness with productive fatigue. Monitor recovery."
            case .overreaching:
                return "⚠️ Deep fatigue - consider taking a rest day or easy ride."
            }
        }

        var recommendation: String {
            switch self {
            case .fresh:
                return "Perfect time for hard intervals or racing"
            case .rested:
                return "Good for threshold or VO2 max work"
            case .optimal:
                return "Continue balanced training"
            case .productive:
                return "Mix in easier rides for recovery"
            case .overreaching:
                return "Rest day or very easy spin recommended"
            }
        }
    }

    // Fitness level interpretation
    var fitnessLevel: String {
        if ctl < 30 {
            return "Beginner"
        } else if ctl < 50 {
            return "Recreational"
        } else if ctl < 75 {
            return "Enthusiast"
        } else if ctl < 100 {
            return "Competitive"
        } else {
            return "Elite"
        }
    }
}

// Storage and calculation of training load over time
class TrainingLoadManager: ObservableObject {
    @Published var dailyLoads: [DailyTrainingLoad] = []

    private let loadsKey = "DailyTrainingLoads"
    private let maxDays = 180  // Keep 6 months of history

    init() {
        loadData()
    }

    // Add TSS for a ride
    func addTSS(date: Date, tss: Double) {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        let dateKey = DailyTrainingLoad(date: normalizedDate, tss: 0).dateKey

        // Check if we already have an entry for this day
        if let index = dailyLoads.firstIndex(where: { $0.dateKey == dateKey }) {
            // Add to existing day's TSS
            let existing = dailyLoads[index]
            dailyLoads[index] = DailyTrainingLoad(id: existing.id, date: normalizedDate, tss: existing.tss + tss)
        } else {
            // Create new entry
            dailyLoads.append(DailyTrainingLoad(date: normalizedDate, tss: tss))
        }

        // Sort by date (most recent first) and limit to max days
        dailyLoads.sort { $0.date > $1.date }
        if dailyLoads.count > maxDays {
            dailyLoads = Array(dailyLoads.prefix(maxDays))
        }

        saveData()
    }

    // Calculate current performance metrics
    func calculateCurrentMetrics() -> PerformanceMetrics {
        let today = Calendar.current.startOfDay(for: Date())
        return calculateMetrics(asOf: today)
    }

    // Calculate metrics as of a specific date
    func calculateMetrics(asOf date: Date) -> PerformanceMetrics {
        let normalizedDate = Calendar.current.startOfDay(for: date)

        // Get all loads up to and including this date
        let relevantLoads = dailyLoads.filter { $0.date <= normalizedDate }

        // Calculate CTL (42-day exponential weighted average)
        let ctl = calculateExponentialAverage(loads: relevantLoads, days: 42, asOf: normalizedDate)

        // Calculate ATL (7-day exponential weighted average)
        let atl = calculateExponentialAverage(loads: relevantLoads, days: 7, asOf: normalizedDate)

        // Calculate TSB (Training Stress Balance / Form)
        let tsb = ctl - atl

        return PerformanceMetrics(ctl: ctl, atl: atl, tsb: tsb)
    }

    // Exponential weighted moving average calculation
    private func calculateExponentialAverage(loads: [DailyTrainingLoad], days: Int, asOf date: Date) -> Double {
        guard !loads.isEmpty else { return 0 }

        let calendar = Calendar.current
        let exponentialConstant = 2.0 / Double(days + 1)
        var average: Double = 0

        // Start from oldest date in our window and work forward
        let startDate = calendar.date(byAdding: .day, value: -days * 3, to: date) ?? date

        // Build daily TSS map
        var tssMap: [String: Double] = [:]
        for load in loads {
            tssMap[load.dateKey] = load.tss
        }

        // Calculate exponential moving average
        var currentDate = startDate
        while currentDate <= date {
            let dateKey = DailyTrainingLoad(date: currentDate, tss: 0).dateKey
            let todayTSS = tssMap[dateKey] ?? 0

            // EMA formula: EMA = (Today's TSS * k) + (Yesterday's EMA * (1 - k))
            // where k = 2 / (days + 1)
            average = (todayTSS * exponentialConstant) + (average * (1 - exponentialConstant))

            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? date
        }

        return average
    }

    // Get historical metrics for charting
    func getHistoricalMetrics(days: Int) -> [(date: Date, ctl: Double, atl: Double, tsb: Double)] {
        let calendar = Calendar.current
        let endDate = calendar.startOfDay(for: Date())
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) ?? endDate

        var results: [(date: Date, ctl: Double, atl: Double, tsb: Double)] = []
        var currentDate = startDate

        while currentDate <= endDate {
            let metrics = calculateMetrics(asOf: currentDate)
            results.append((date: currentDate, ctl: metrics.ctl, atl: metrics.atl, tsb: metrics.tsb))
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? endDate
        }

        return results
    }

    // Get weekly summary
    func getWeeklySummary() -> (weekTSS: Double, weekAverage: Double) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: today) ?? today

        let weekLoads = dailyLoads.filter { $0.date > weekAgo && $0.date <= today }
        let totalTSS = weekLoads.reduce(0) { $0 + $1.tss }
        let averageTSS = weekLoads.isEmpty ? 0 : totalTSS / 7.0

        return (weekTSS: totalTSS, weekAverage: averageTSS)
    }

    // Predict TSB after a planned workout
    func predictTSB(afterWorkoutTSS tss: Double) -> Double {
        // Simulate adding the workout to today
        let today = Calendar.current.startOfDay(for: Date())
        let todayKey = DailyTrainingLoad(date: today, tss: 0).dateKey

        // Get current day's TSS
        let currentDayTSS = dailyLoads.first(where: { $0.dateKey == todayKey })?.tss ?? 0
        let totalDayTSS = currentDayTSS + tss

        // Calculate what metrics would be tomorrow
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today

        // Temporarily add the workout
        let tempLoad = DailyTrainingLoad(date: today, tss: totalDayTSS)
        var tempLoads = dailyLoads.filter { $0.dateKey != todayKey }
        tempLoads.append(tempLoad)

        // Calculate metrics for tomorrow with this workout included
        let ctl = calculateExponentialAverage(loads: tempLoads, days: 42, asOf: tomorrow)
        let atl = calculateExponentialAverage(loads: tempLoads, days: 7, asOf: tomorrow)

        return ctl - atl
    }

    private func loadData() {
        guard let data = UserDefaults.standard.data(forKey: loadsKey),
              let decoded = try? JSONDecoder().decode([DailyTrainingLoad].self, from: data) else {
            return
        }
        dailyLoads = decoded
    }

    private func saveData() {
        if let encoded = try? JSONEncoder().encode(dailyLoads) {
            UserDefaults.standard.set(encoded, forKey: loadsKey)
        }
    }
}
