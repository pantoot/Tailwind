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
    // Retention must cover the CTL warm-up walk (5 × 42 = 210 days), or the
    // oldest real TSS silently reads as zero and understates fitness.
    private let maxDays = 220

    init() {
        loadData()
    }

    // Rebuild TSS data from ride history (clears existing and rebuilds)
    func syncFromRides(_ rides: [Ride]) {
        print("🔄 Syncing TSS from \(rides.count) rides...")

        // Clear existing data
        dailyLoads.removeAll()

        // Add TSS from each ride that has it
        for ride in rides {
            if let tss = ride.hrTSS {
                addTSS(date: ride.date, tss: tss, persist: false)
            }
        }

        // Save once at the end
        saveData()

        let metrics = calculateCurrentMetrics()
        print("🔄 Sync complete: \(dailyLoads.count) days, CTL=\(String(format: "%.0f", metrics.ctl)), ATL=\(String(format: "%.0f", metrics.atl)), TSB=\(String(format: "%.0f", metrics.tsb))")
    }

    // Add TSS for a ride
    func addTSS(date: Date, tss: Double, persist: Bool = true) {
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

        if persist {
            saveData()
        }
    }

    // Calculate current performance metrics
    func calculateCurrentMetrics() -> PerformanceMetrics {
        let today = Calendar.current.startOfDay(for: Date())
        return calculateMetrics(asOf: today)
    }

    // Debug: Print all TSS data and calculation
    func debugPrintMetrics() {
        print("📊 === TRAINING LOAD DEBUG ===")
        print("📊 Total days with TSS data: \(dailyLoads.count)")

        let sortedLoads = dailyLoads.sorted { $0.date > $1.date }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        print("📊 Recent TSS by day:")
        for load in sortedLoads.prefix(14) {
            print("   \(formatter.string(from: load.date)): \(String(format: "%.0f", load.tss)) TSS")
        }

        let metrics = calculateCurrentMetrics()
        let weekly = getWeeklySummary()

        print("📊 Weekly TSS: \(String(format: "%.0f", weekly.weekTSS))")
        print("📊 CTL (Fitness/42-day): \(String(format: "%.1f", metrics.ctl))")
        print("📊 ATL (Fatigue/7-day): \(String(format: "%.1f", metrics.atl))")
        print("📊 TSB (Form): \(String(format: "%.1f", metrics.tsb))")
        print("📊 Status: \(metrics.formStatus.rawValue)")
        print("📊 ===========================")
    }

    // Calculate metrics as of a specific date
    func calculateMetrics(asOf date: Date) -> PerformanceMetrics {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)

        // Get all loads up to and including this date
        let relevantLoads = dailyLoads.filter { $0.date <= normalizedDate }

        // Calculate CTL (42-day exponential weighted average)
        let ctl = calculateExponentialAverage(loads: relevantLoads, days: 42, asOf: normalizedDate)

        // Calculate ATL (7-day exponential weighted average)
        let atl = calculateExponentialAverage(loads: relevantLoads, days: 7, asOf: normalizedDate)

        // TSB (Form) is what you woke up with: yesterday's CTL minus yesterday's
        // ATL (TrainingPeaks convention). Using today's values would move today's
        // ride into today's form and shift the whole form chart a day early.
        let yesterday = calendar.date(byAdding: .day, value: -1, to: normalizedDate) ?? normalizedDate
        let tsb = calculateExponentialAverage(loads: relevantLoads, days: 42, asOf: yesterday)
                - calculateExponentialAverage(loads: relevantLoads, days: 7, asOf: yesterday)

        return PerformanceMetrics(ctl: ctl, atl: atl, tsb: tsb)
    }

    // Exponential weighted moving average calculation
    private func calculateExponentialAverage(loads: [DailyTrainingLoad], days: Int, asOf date: Date) -> Double {
        guard !loads.isEmpty else { return 0 }

        let calendar = Calendar.current
        // TrainingPeaks/Coggan impulse-response constant: k = 1/N, i.e.
        // CTL_today = CTL_yesterday + (TSS_today − CTL_yesterday) / 42.
        // (Not the finance EMA 2/(N+1) — that made a "42-day" CTL behave
        // like a 21-day one and doubled every ramp-rate reading.)
        let exponentialConstant = 1.0 / Double(days)
        var average: Double = 0

        // Start from oldest date in our window and work forward. With k = 1/N a
        // zero-seeded walk needs ~5 time constants for the residual bias to drop
        // below 1% ((41/42)^210 ≈ 0.6%).
        let startDate = calendar.date(byAdding: .day, value: -days * 5, to: date) ?? date

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

    /// Ramp rate: CTL now vs CTL 7 days ago. Values > 5 risk injury/illness.
    func getRampRate() -> Double {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: today) ?? today

        let ctlNow = calculateMetrics(asOf: today).ctl
        let ctlLastWeek = calculateMetrics(asOf: weekAgo).ctl

        return ctlNow - ctlLastWeek
    }

    // Predict TSB after a planned workout
    func predictTSB(afterWorkoutTSS tss: Double) -> Double {
        // Simulate adding the workout to today
        let today = Calendar.current.startOfDay(for: Date())
        let todayKey = DailyTrainingLoad(date: today, tss: 0).dateKey

        // Get current day's TSS
        let currentDayTSS = dailyLoads.first(where: { $0.dateKey == todayKey })?.tss ?? 0
        let totalDayTSS = currentDayTSS + tss

        // Temporarily add the workout
        let tempLoad = DailyTrainingLoad(date: today, tss: totalDayTSS)
        var tempLoads = dailyLoads.filter { $0.dateKey != todayKey }
        tempLoads.append(tempLoad)

        // Tomorrow's form = today's CTL − today's ATL with the workout included
        // (form is measured off the previous day's values).
        let ctl = calculateExponentialAverage(loads: tempLoads, days: 42, asOf: today)
        let atl = calculateExponentialAverage(loads: tempLoads, days: 7, asOf: today)

        return ctl - atl
    }

    private func loadData() {
        guard let data = UserDefaults.standard.data(forKey: loadsKey) else { return }
        do {
            dailyLoads = try JSONDecoder().decode([DailyTrainingLoad].self, from: data)
        } catch {
            // Recoverable via syncFromRides at launch, but leave a trail so a
            // session of zeroed CTL/ATL is diagnosable.
            print("❌ ERROR: Failed to decode training loads (will rebuild from rides): \(error)")
        }
    }

    // Clear all training load data (for re-import)
    func clearAll() {
        dailyLoads.removeAll()
        saveData()
        print("🗑️ Cleared all training load data")
    }

    private func saveData() {
        do {
            let encoded = try JSONEncoder().encode(dailyLoads)
            UserDefaults.standard.set(encoded, forKey: loadsKey)
        } catch {
            print("❌ ERROR: Failed to save training loads: \(error)")
        }
    }
}
