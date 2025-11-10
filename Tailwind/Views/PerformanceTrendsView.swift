import SwiftUI
import Charts

// Performance trends over time
struct PerformanceTrendsView: View {
    @EnvironmentObject var rideHistory: RideHistory
    @State private var selectedTimeRange: TimeRange = .month
    @State private var selectedMetric: TrendMetric = .distance

    enum TimeRange: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case quarter = "3 Months"
        case year = "Year"

        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .quarter: return 90
            case .year: return 365
            }
        }
    }

    enum TrendMetric: String, CaseIterable {
        case distance = "Distance"
        case avgSpeed = "Avg Speed"
        case calories = "Calories"
        case time = "Ride Time"
        case heartRate = "Avg Heart Rate"

        var color: Color {
            switch self {
            case .distance: return .blue
            case .avgSpeed: return .green
            case .calories: return .orange
            case .time: return .purple
            case .heartRate: return .red
            }
        }

        var unit: String {
            switch self {
            case .distance: return "mi"
            case .avgSpeed: return "mph"
            case .calories: return "cal"
            case .time: return "min"
            case .heartRate: return "bpm"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Time range selector
                Picker("Time Range", selection: $selectedTimeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Summary cards
                summaryCardsView

                // Metric selector
                Picker("Metric", selection: $selectedMetric) {
                    ForEach(TrendMetric.allCases, id: \.self) { metric in
                        Text(metric.rawValue).tag(metric)
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal)

                // Trend chart
                trendChartView

                // Weekly comparison
                weeklyComparisonView
            }
            .padding(.vertical)
        }
        .navigationTitle("Performance Trends")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var summaryCardsView: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            SummaryCard(
                title: "Total Distance",
                value: String(format: "%.1f", totalDistance),
                unit: "mi",
                icon: "location.fill",
                color: .blue
            )

            SummaryCard(
                title: "Total Rides",
                value: "\(filteredRides.count)",
                unit: "rides",
                icon: "figure.outdoor.cycle",
                color: .green
            )

            SummaryCard(
                title: "Total Time",
                value: formatDuration(totalTime),
                unit: "",
                icon: "clock.fill",
                color: .purple
            )

            SummaryCard(
                title: "Avg Speed",
                value: String(format: "%.1f", avgSpeed),
                unit: "mph",
                icon: "speedometer",
                color: .orange
            )
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var trendChartView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(selectedMetric.rawValue)
                .font(.headline)
                .padding(.horizontal)

            if filteredRides.isEmpty {
                emptyStateView
            } else {
                Chart {
                    ForEach(filteredRides) { ride in
                        BarMark(
                            x: .value("Date", ride.date, unit: .day),
                            y: .value(selectedMetric.rawValue, getMetricValue(for: ride))
                        )
                        .foregroundStyle(selectedMetric.color.gradient)
                    }

                    // Add trend line
                    if filteredRides.count > 1 {
                        LineMark(
                            x: .value("Date", filteredRides.first!.date),
                            y: .value("Trend", calculateTrendStart())
                        )
                        .foregroundStyle(.gray)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))

                        LineMark(
                            x: .value("Date", filteredRides.last!.date),
                            y: .value("Trend", calculateTrendEnd())
                        )
                        .foregroundStyle(.gray)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    }
                }
                .frame(height: 250)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5))
                }
                .padding()
            }
        }
    }

    @ViewBuilder
    private var weeklyComparisonView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Week-over-Week Comparison")
                .font(.headline)
                .padding(.horizontal)

            Chart {
                ForEach(weeklyData, id: \.week) { data in
                    BarMark(
                        x: .value("Week", "Week \(data.week)"),
                        y: .value("Distance", data.distance)
                    )
                    .foregroundStyle(.blue.gradient)
                    .annotation(position: .top) {
                        Text(String(format: "%.1f", data.distance))
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }
            .frame(height: 200)
            .padding()
        }
    }

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            Text("No rides in this time range")
                .font(.headline)
                .foregroundColor(.gray)
        }
        .frame(height: 250)
    }

    // MARK: - Computed Properties

    private var filteredRides: [Ride] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -selectedTimeRange.days, to: Date()) ?? Date()
        return rideHistory.rides.filter { $0.date >= cutoffDate }.sorted { $0.date < $1.date }
    }

    private var totalDistance: Double {
        filteredRides.reduce(0) { $0 + $1.distance }
    }

    private var totalTime: TimeInterval {
        filteredRides.reduce(0) { $0 + $1.duration }
    }

    private var avgSpeed: Double {
        guard !filteredRides.isEmpty else { return 0 }
        return filteredRides.reduce(0) { $0 + $1.averageSpeed } / Double(filteredRides.count)
    }

    private var weeklyData: [(week: Int, distance: Double)] {
        let calendar = Calendar.current
        var weeklyTotals: [Int: Double] = [:]

        for ride in filteredRides {
            let weekOfYear = calendar.component(.weekOfYear, from: ride.date)
            weeklyTotals[weekOfYear, default: 0] += ride.distance
        }

        return weeklyTotals.sorted { $0.key < $1.key }.enumerated().map { index, element in
            (week: index + 1, distance: element.value)
        }.suffix(4) // Last 4 weeks
    }

    // MARK: - Helper Functions

    private func getMetricValue(for ride: Ride) -> Double {
        switch selectedMetric {
        case .distance:
            return ride.distance
        case .avgSpeed:
            return ride.averageSpeed
        case .calories:
            return ride.calories
        case .time:
            return ride.duration / 60.0 // Convert to minutes
        case .heartRate:
            return ride.averageHeartRate
        }
    }

    private func calculateTrendStart() -> Double {
        guard !filteredRides.isEmpty else { return 0 }
        let firstHalf = Array(filteredRides.prefix(filteredRides.count / 2))
        return firstHalf.reduce(0) { $0 + getMetricValue(for: $1) } / Double(firstHalf.count)
    }

    private func calculateTrendEnd() -> Double {
        guard !filteredRides.isEmpty else { return 0 }
        let secondHalf = Array(filteredRides.suffix(filteredRides.count / 2))
        return secondHalf.reduce(0) { $0 + getMetricValue(for: $1) } / Double(secondHalf.count)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// Summary card component
struct SummaryCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}
