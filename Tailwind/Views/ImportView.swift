import SwiftUI
import Charts

/// Main training dashboard view - mPaceline-style interface
struct ImportView: View {
    @EnvironmentObject var rideHistory: RideHistory
    @EnvironmentObject var trainingLoadManager: TrainingLoadManager

    private var currentMetrics: PerformanceMetrics {
        trainingLoadManager.calculateCurrentMetrics()
    }

    private var weeklySummary: (weekTSS: Double, weekAverage: Double) {
        trainingLoadManager.getWeeklySummary()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Form Status Card - prominent display
                    formStatusCard

                    // Training Metrics Row
                    trainingMetricsRow

                    // Form Chart (last 30 days)
                    if !trainingLoadManager.dailyLoads.isEmpty {
                        formChartSection
                    }

                    // Weekly Summary
                    weeklySummaryCard

                    // Recent Rides
                    if !rideHistory.rides.isEmpty {
                        recentRidesSection
                    }

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Tailwind")
        }
    }

    // MARK: - Form Status Card

    private var formStatusCard: some View {
        VStack(spacing: 12) {
            // Status indicator
            HStack {
                Circle()
                    .fill(currentMetrics.formStatus.color)
                    .frame(width: 16, height: 16)

                Text(currentMetrics.formStatus.rawValue)
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                // TSB value
                Text(String(format: "%+.0f", currentMetrics.tsb))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(currentMetrics.tsb >= 0 ? .green : .orange)
            }

            // Description
            Text(currentMetrics.formStatus.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            // Recommendation
            HStack {
                Image(systemName: recommendationIcon)
                    .foregroundStyle(currentMetrics.formStatus.color)
                Text(currentMetrics.formStatus.recommendation)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Ramp Rate warning
            let rampRate = trainingLoadManager.getRampRate()
            if abs(rampRate) >= 1 {
                Divider()
                HStack {
                    Circle()
                        .fill(rampRate > 5 ? Color.red : Color.green)
                        .frame(width: 10, height: 10)
                    Text("Ramp Rate")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text(String(format: "%+.1f CTL/wk", rampRate))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(rampRate > 5 ? .red : .primary)
                }
                if rampRate > 5 {
                    Text("CTL rising too fast — back off to avoid illness or injury")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    private var recommendationIcon: String {
        switch currentMetrics.formStatus {
        case .fresh, .rested:
            return "bolt.fill"
        case .optimal:
            return "checkmark.circle.fill"
        case .productive:
            return "exclamationmark.triangle.fill"
        case .overreaching:
            return "bed.double.fill"
        }
    }

    // MARK: - Training Metrics Row

    private var trainingMetricsRow: some View {
        HStack(spacing: 12) {
            DashboardMetricCard(
                title: "Fitness",
                subtitle: "CTL",
                value: String(format: "%.0f", currentMetrics.ctl),
                color: .blue
            )

            DashboardMetricCard(
                title: "Fatigue",
                subtitle: "ATL",
                value: String(format: "%.0f", currentMetrics.atl),
                color: .orange
            )

            DashboardMetricCard(
                title: "Form",
                subtitle: "TSB",
                value: String(format: "%+.0f", currentMetrics.tsb),
                color: currentMetrics.tsb >= 0 ? .green : .red
            )
        }
    }

    // MARK: - Form Chart Section

    private var formChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Training Load")
                .font(.headline)

            FormChart(data: trainingLoadManager.getHistoricalMetrics(days: 30))
                .frame(height: 180)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    // MARK: - Weekly Summary

    private var weeklySummaryCard: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("This Week")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(String(format: "%.0f", weeklySummary.weekTSS))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    Text("TSS")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("Daily Avg")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(String(format: "%.0f", weeklySummary.weekAverage))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    Text("TSS")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    // MARK: - Recent Rides Section

    private var recentRidesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Rides")
                    .font(.headline)
                Spacer()
                NavigationLink("See All") {
                    RideHistoryView()
                }
                .font(.subheadline)
            }

            VStack(spacing: 8) {
                ForEach(rideHistory.rides.prefix(5)) { ride in
                    NavigationLink(destination: RideDetailView(ride: ride)) {
                        RideRow(ride: ride)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct DashboardMetricCard: View {
    let title: String
    let subtitle: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(color)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct RideRow: View {
    let ride: Ride

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(ride.formattedDate)
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 12) {
                    Label(ride.formattedDistance, systemImage: "road.lanes")
                    Label(ride.formattedDuration, systemImage: "clock")
                    if let tss = ride.hrTSS {
                        Label(String(format: "%.0f", tss), systemImage: "flame.fill")
                            .foregroundStyle(.orange)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if ride.averageHeartRate > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                    Text("\(Int(ride.averageHeartRate))")
                }
                .font(.subheadline)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Form Chart

struct FormChart: View {
    let data: [(date: Date, ctl: Double, atl: Double, tsb: Double)]

    var body: some View {
        Chart {
            // TSB area (form)
            ForEach(data, id: \.date) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("TSB", point.tsb)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [point.tsb >= 0 ? .green.opacity(0.3) : .red.opacity(0.3), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }

            // CTL line (fitness)
            ForEach(data, id: \.date) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("CTL", point.ctl)
                )
                .foregroundStyle(.blue)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }

            // ATL line (fatigue)
            ForEach(data, id: \.date) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("ATL", point.atl)
                )
                .foregroundStyle(.orange)
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
            }

            // Zero line for TSB
            RuleMark(y: .value("Zero", 0))
                .foregroundStyle(.gray.opacity(0.3))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 7)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
            }
        }
        .chartLegend(position: .bottom, spacing: 20) {
            HStack(spacing: 16) {
                Label("Fitness", systemImage: "line.diagonal")
                    .foregroundStyle(.blue)
                Label("Fatigue", systemImage: "line.diagonal")
                    .foregroundStyle(.orange)
                Label("Form", systemImage: "square.fill")
                    .foregroundStyle(.green)
            }
            .font(.caption)
        }
    }
}

#Preview {
    ImportView()
        .environmentObject(RideHistory())
        .environmentObject(TrainingLoadManager())
}
