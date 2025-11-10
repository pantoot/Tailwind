import SwiftUI
import Charts

struct HistoryTabView: View {
    @EnvironmentObject var rideHistory: RideHistory
    @EnvironmentObject var trainingLoadManager: TrainingLoadManager
    @EnvironmentObject var healthKitService: HealthKitService
    @State private var selectedRide: Ride?
    @State private var expandedMonths: Set<String> = []

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Summary Stats Card
                    summaryStatsSection

                    // Training Load Section
                    trainingLoadSection

                    // Analytics Links
                    analyticsLinksSection

                    // Recent Rides (Grouped by Month)
                    recentRidesSection
                }
                .padding()
            }
            .navigationTitle("History & Analytics")
            .sheet(item: $selectedRide) { ride in
                RideDetailView(ride: ride)
            }
        }
    }

    // MARK: - Summary Stats

    private var summaryStatsSection: some View {
        VStack(spacing: 16) {
            Text("Summary")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                SummaryStatCard(
                    title: "Total Rides",
                    value: "\(rideHistory.totalRides)",
                    icon: "bicycle",
                    color: .blue
                )
                SummaryStatCard(
                    title: "Total Distance",
                    value: String(format: "%.1f mi", rideHistory.totalDistance),
                    icon: "map",
                    color: .green
                )
                SummaryStatCard(
                    title: "Total Time",
                    value: formatDuration(rideHistory.totalDuration),
                    icon: "clock",
                    color: .purple
                )
                SummaryStatCard(
                    title: "Total Calories",
                    value: String(format: "%.0f", rideHistory.totalCalories),
                    icon: "flame",
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }

    // MARK: - Training Load

    private var trainingLoadSection: some View {
        VStack(spacing: 16) {
            Text("Training Load")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Current metrics
            let currentMetrics = trainingLoadManager.calculateCurrentMetrics()

            // Form status interpretation
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.title)
                        .foregroundColor(currentMetrics.formStatus.color)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(currentMetrics.formStatus.rawValue)
                            .font(.headline)
                            .foregroundColor(currentMetrics.formStatus.color)
                        Text(currentMetrics.formStatus.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }

                Text("💡 \(currentMetrics.formStatus.recommendation)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(currentMetrics.formStatus.color.opacity(0.1))
            .cornerRadius(12)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Fitness (CTL)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f", currentMetrics.ctl))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Text(currentMetrics.fitnessLevel)
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Fatigue (ATL)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f", currentMetrics.atl))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    Text("7-day avg")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Form (TSB)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f", currentMetrics.tsb))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(tsbColor(for: currentMetrics.tsb))
                    Text("readiness")
                        .font(.caption2)
                        .foregroundColor(tsbColor(for: currentMetrics.tsb))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)

            // Training Load Chart
            if !trainingLoadManager.dailyLoads.isEmpty {
                trainingLoadChart
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }

    private var trainingLoadChart: some View {
        let historicalData = trainingLoadManager.getHistoricalMetrics(days: 30)

        return VStack(spacing: 12) {
            // Chart
            Chart {
                ForEach(historicalData.indices, id: \.self) { index in
                    let data = historicalData[index]

                    LineMark(
                        x: .value("Date", data.date),
                        y: .value("CTL", data.ctl)
                    )
                    .foregroundStyle(.blue)
                    .interpolationMethod(.catmullRom)
                    .symbol(.circle)

                    LineMark(
                        x: .value("Date", data.date),
                        y: .value("ATL", data.atl)
                    )
                    .foregroundStyle(.orange)
                    .interpolationMethod(.catmullRom)
                    .symbol(.square)
                }
            }
            .chartYAxisLabel("Training Stress")
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { value in
                    AxisValueLabel(format: .dateTime.month().day())
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 180)

            // Legend
            HStack(spacing: 24) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(.blue)
                        .frame(width: 10, height: 10)
                    Text("Fitness (CTL)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.orange)
                        .frame(width: 10, height: 10)
                    Text("Fatigue (ATL)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("Last 30 days")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func tsbColor(for tsb: Double) -> Color {
        if tsb < -10 { return .red }
        if tsb < 0 { return .orange }
        if tsb < 10 { return .green }
        return .blue
    }

    // MARK: - Analytics Links

    private var analyticsLinksSection: some View {
        VStack(spacing: 12) {
            Text("Analytics")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            NavigationLink(destination: PerformanceTrendsView()) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(.blue)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Performance Trends")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("View your progress over time")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
            }

            NavigationLink(destination: PeakPerformanceView()) {
                HStack {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.orange)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Peak Performance")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("Best efforts and efficiency")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
            }

            NavigationLink(destination: RouteHistoryMapView()) {
                HStack {
                    Image(systemName: "map.fill")
                        .foregroundColor(.green)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Route History")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("View all rides on a map")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Recent Rides

    private var recentRidesSection: some View {
        VStack(spacing: 16) {
            Text("Recent Rides")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            if rideHistory.rides.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "bicycle")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("No rides yet")
                        .font(.title2)
                        .foregroundColor(.gray)
                    Text("Complete a ride to see it here")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(groupedRides.keys.sorted(by: >), id: \.self) { monthKey in
                    VStack(spacing: 0) {
                        // Month header
                        monthHeaderButton(for: monthKey)

                        // Rides (if expanded)
                        if expandedMonths.contains(monthKey) || isCurrentMonth(monthKey) {
                            ForEach(sortedRidesForMonth(monthKey)) { ride in
                                Button(action: {
                                    selectedRide = ride
                                }) {
                                    RideRowView(ride: ride)
                                        .padding(.horizontal)
                                        .padding(.vertical, 8)
                                }
                                .buttonStyle(PlainButtonStyle())

                                if ride.id != sortedRidesForMonth(monthKey).last?.id {
                                    Divider()
                                        .padding(.leading, 16)
                                }
                            }
                        }
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                }
            }
        }
    }

    // MARK: - Helpers

    private var groupedRides: [String: [Ride]] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return Dictionary(grouping: rideHistory.rides) { ride in
            formatter.string(from: ride.date)
        }
    }

    private func isCurrentMonth(_ monthKey: String) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return monthKey == formatter.string(from: Date())
    }

    private func sortedRidesForMonth(_ monthKey: String) -> [Ride] {
        return (groupedRides[monthKey] ?? []).sorted { $0.date > $1.date }
    }

    private func monthHeaderButton(for monthKey: String) -> some View {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"

        if let date = formatter.date(from: monthKey) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "MMMM yyyy"
            let monthName = displayFormatter.string(from: date)
            let rideCount = groupedRides[monthKey]?.count ?? 0
            let isExpanded = expandedMonths.contains(monthKey) || isCurrentMonth(monthKey)

            return AnyView(
                Button(action: {
                    withAnimation {
                        if expandedMonths.contains(monthKey) {
                            expandedMonths.remove(monthKey)
                        } else {
                            expandedMonths.insert(monthKey)
                        }
                    }
                }) {
                    HStack {
                        Text(monthName)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                        Text("\(rideCount) ride\(rideCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            )
        }

        return AnyView(Text("Unknown"))
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

// MARK: - Supporting Views

struct SummaryStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}
