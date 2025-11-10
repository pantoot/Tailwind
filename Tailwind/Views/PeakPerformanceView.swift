import SwiftUI
import Charts

// Peak performance analysis - best efforts at different durations
struct PeakPerformanceView: View {
    @EnvironmentObject var rideHistory: RideHistory
    @State private var selectedDuration: Duration = .fiveMin

    enum Duration: String, CaseIterable {
        case thirtySeconds = "30 sec"
        case oneMin = "1 min"
        case fiveMin = "5 min"
        case tenMin = "10 min"
        case twentyMin = "20 min"
        case thirtyMin = "30 min"

        var seconds: TimeInterval {
            switch self {
            case .thirtySeconds: return 30
            case .oneMin: return 60
            case .fiveMin: return 300
            case .tenMin: return 600
            case .twentyMin: return 1200
            case .thirtyMin: return 1800
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Duration selector
                VStack(alignment: .leading, spacing: 12) {
                    Text("Select Duration")
                        .font(.headline)
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Duration.allCases, id: \.self) { duration in
                                DurationPill(
                                    duration: duration,
                                    isSelected: selectedDuration == duration
                                ) {
                                    selectedDuration = duration
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // Best effort card
                bestEffortCard

                // Peak power curve
                peakPowerCurve

                // Recent bests
                recentBestsView

                // Power ratio analysis
                powerRatioView
            }
            .padding(.vertical)
        }
        .navigationTitle("Peak Performance")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var bestEffortCard: some View {
        VStack(spacing: 16) {
            Text("Best \(selectedDuration.rawValue) Effort")
                .font(.headline)

            if let best = bestEffort {
                VStack(spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f", best.avgSpeed))
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.blue)

                        Text("mph")
                            .font(.title3)
                            .foregroundColor(.gray)
                    }

                    Text(best.date, style: .date)
                        .font(.caption)
                        .foregroundColor(.gray)

                    Divider()
                        .padding(.vertical, 8)

                    HStack(spacing: 24) {
                        VStack(spacing: 4) {
                            Text("\(Int(best.avgHeartRate))")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.red)
                            Text("Avg HR")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }

                        VStack(spacing: 4) {
                            Text(String(format: "%.1f", best.distance))
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                            Text("Distance")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }

                        VStack(spacing: 4) {
                            Text(String(format: "%.0f", best.calories))
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                            Text("Calories")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)
                .padding(.horizontal)
            } else {
                Text("No rides long enough for this duration")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding()
            }
        }
    }

    @ViewBuilder
    private var peakPowerCurve: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Peak Speed Curve")
                .font(.headline)
                .padding(.horizontal)

            Chart {
                ForEach(Duration.allCases, id: \.self) { duration in
                    if let effort = getBestEffort(for: duration) {
                        BarMark(
                            x: .value("Duration", duration.rawValue),
                            y: .value("Speed", effort.avgSpeed)
                        )
                        .foregroundStyle(.blue.gradient)
                        .annotation(position: .top) {
                            Text(String(format: "%.1f", effort.avgSpeed))
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .frame(height: 250)
            .padding()
        }
    }

    @ViewBuilder
    private var recentBestsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Best Efforts")
                .font(.headline)
                .padding(.horizontal)

            if recentBests.isEmpty {
                Text("No recent improvements")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding()
            } else {
                VStack(spacing: 8) {
                    ForEach(recentBests.prefix(5)) { effort in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(effort.durationName)
                                    .font(.headline)
                                Text(effort.date, style: .date)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                HStack(spacing: 4) {
                                    Text(String(format: "%.1f", effort.avgSpeed))
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.blue)
                                    Text("mph")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }

                                if effort.improvement > 0 {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.up.right")
                                            .font(.caption2)
                                        Text(String(format: "+%.1f%%", effort.improvement))
                                            .font(.caption)
                                    }
                                    .foregroundColor(.green)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    @ViewBuilder
    private var powerRatioView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Efficiency (Speed/HR Ratio)")
                .font(.headline)
                .padding(.horizontal)

            Text("Higher ratio = more efficient riding")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.horizontal)

            Chart {
                ForEach(powerRatioData) { data in
                    LineMark(
                        x: .value("Date", data.date),
                        y: .value("Ratio", data.ratio)
                    )
                    .foregroundStyle(.purple.gradient)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date", data.date),
                        y: .value("Ratio", data.ratio)
                    )
                    .foregroundStyle(.purple)
                }
            }
            .frame(height: 200)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .padding()

            if let avgRatio = averageRatio {
                HStack {
                    Text("Average Efficiency:")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    Text(String(format: "%.3f", avgRatio))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.purple)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
    }

    // MARK: - Data Models

    struct BestEffort {
        let date: Date
        let avgSpeed: Double
        let distance: Double
        let avgHeartRate: Double
        let calories: Double
    }

    struct RecentBest: Identifiable {
        let id = UUID()
        let date: Date
        let durationName: String
        let avgSpeed: Double
        let improvement: Double // Percentage improvement
    }

    struct PowerRatioData: Identifiable {
        let id = UUID()
        let date: Date
        let ratio: Double
    }

    // MARK: - Computed Properties

    private var bestEffort: BestEffort? {
        getBestEffort(for: selectedDuration)
    }

    private var recentBests: [RecentBest] {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        var bests: [RecentBest] = []

        for duration in Duration.allCases {
            if let recent = getBestEffort(for: duration, since: thirtyDaysAgo),
               let previous = getBestEffort(for: duration, before: thirtyDaysAgo) {
                let improvement = ((recent.avgSpeed - previous.avgSpeed) / previous.avgSpeed) * 100
                if improvement > 0 {
                    bests.append(RecentBest(
                        date: recent.date,
                        durationName: duration.rawValue,
                        avgSpeed: recent.avgSpeed,
                        improvement: improvement
                    ))
                }
            }
        }

        return bests.sorted { $0.improvement > $1.improvement }
    }

    private var powerRatioData: [PowerRatioData] {
        let last30Days = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return rideHistory.rides
            .filter { $0.date >= last30Days && $0.averageHeartRate > 0 }
            .sorted { $0.date < $1.date }
            .map { ride in
                PowerRatioData(
                    date: ride.date,
                    ratio: ride.averageSpeed / ride.averageHeartRate
                )
            }
    }

    private var averageRatio: Double? {
        guard !powerRatioData.isEmpty else { return nil }
        return powerRatioData.reduce(0) { $0 + $1.ratio } / Double(powerRatioData.count)
    }

    // MARK: - Helper Functions

    private func getBestEffort(for duration: Duration, since: Date? = nil, before: Date? = nil) -> BestEffort? {
        var filteredRides = rideHistory.rides.filter { $0.duration >= duration.seconds }

        if let since = since {
            filteredRides = filteredRides.filter { $0.date >= since }
        }

        if let before = before {
            filteredRides = filteredRides.filter { $0.date < before }
        }

        guard let best = filteredRides.max(by: { $0.averageSpeed < $1.averageSpeed }) else {
            return nil
        }

        return BestEffort(
            date: best.date,
            avgSpeed: best.averageSpeed,
            distance: best.distance,
            avgHeartRate: best.averageHeartRate,
            calories: best.calories
        )
    }
}

// Duration pill button
struct DurationPill: View {
    let duration: PeakPerformanceView.Duration
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(duration.rawValue)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray6))
                .cornerRadius(20)
        }
    }
}
