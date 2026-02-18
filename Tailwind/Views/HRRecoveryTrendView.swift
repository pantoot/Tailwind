import SwiftUI
import Charts

/// HR Recovery Trend — works from ALL rides with HR data, not just power rides.
/// Shows how fast your heart rate drops after hard efforts over time.
/// A rising trend means improving cardiovascular fitness and aerobic base.
struct HRRecoveryTrendView: View {
    @EnvironmentObject var rideHistory: RideHistory

    // Time range filter
    @State private var selectedRange: TimeRange = .threeMonths

    enum TimeRange: String, CaseIterable {
        case month = "30 Days"
        case threeMonths = "90 Days"
        case sixMonths = "6 Months"
        case allTime = "All Time"

        var days: Int? {
            switch self {
            case .month: return 30
            case .threeMonths: return 90
            case .sixMonths: return 180
            case .allTime: return nil
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // Time range picker
                Picker("Range", selection: $selectedRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Summary card
                summaryCard

                // Trend chart
                trendChart

                // What this means
                interpretationCard

                // All-time recorded max HR
                maxHRCard

                // Recent events detail
                recentEventsCard

            }
            .padding(.vertical)
        }
        .navigationTitle("HR Recovery Trend")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Data

    /// All rides with power data that have HR recovery events (from CreatineAnalysis)
    private var powerRidesWithRecovery: [(ride: Ride, events: [HRRecoveryEvent])] {
        filteredRides.compactMap { ride in
            guard let events = ride.creatineMetrics?.hrRecoveryEvents, !events.isEmpty else { return nil }
            return (ride: ride, events: events)
        }
    }

    /// Per-ride average recovery delta across all sources
    private var recoveryTrend: [(date: Date, avgDelta: Double, source: String)] {
        powerRidesWithRecovery.compactMap { item in
            guard !item.events.isEmpty else { return nil }
            let avg = Double(item.events.reduce(0) { $0 + $1.recoveryDelta }) / Double(item.events.count)
            return (date: item.ride.date, avgDelta: avg, source: "Power Ride")
        }
        .sorted { $0.date < $1.date }
    }

    private var filteredRides: [Ride] {
        guard let days = selectedRange.days else { return rideHistory.rides }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return rideHistory.rides.filter { $0.date >= cutoff }
    }

    private var allRecoveryEvents: [(ride: Ride, event: HRRecoveryEvent)] {
        powerRidesWithRecovery.flatMap { item in
            item.events.map { (ride: item.ride, event: $0) }
        }
        .sorted { $0.ride.date > $1.ride.date }
    }

    private var latestAvgDelta: Double? {
        recoveryTrend.last?.avgDelta
    }

    private var earliestAvgDelta: Double? {
        recoveryTrend.first?.avgDelta
    }

    private var trendImprovement: Double? {
        guard let latest = latestAvgDelta, let earliest = earliestAvgDelta, earliest > 0 else { return nil }
        return latest - earliest
    }

    /// All-time highest max HR across every ride ever recorded
    private var allTimeMaxHR: Int? {
        rideHistory.rides.map { $0.maxHeartRate }.filter { $0 > 100 }.max()
    }

    private var allTimeMaxHRRide: Ride? {
        guard let maxHR = allTimeMaxHR else { return nil }
        return rideHistory.rides.first { $0.maxHeartRate == maxHR }
    }

    // MARK: - Views

    private var summaryCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 0) {
                // Latest recovery
                VStack(spacing: 4) {
                    if let latest = latestAvgDelta {
                        Text(String(format: "%.0f", latest))
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundColor(recoveryColor(latest))
                        Text("bpm drop")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Latest avg")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Text("—")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.secondary)
                        Text("No data")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 60)

                // Trend
                VStack(spacing: 4) {
                    if let improvement = trendImprovement, recoveryTrend.count >= 2 {
                        HStack(spacing: 4) {
                            Image(systemName: improvement >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .foregroundColor(improvement >= 0 ? .green : .red)
                            Text(String(format: "%+.0f", improvement))
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .foregroundColor(improvement >= 0 ? .green : .red)
                        }
                        Text("bpm trend")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(selectedRange.rawValue)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Text("—")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.secondary)
                        Text("Need 2+ rides")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 60)

                // Event count
                VStack(spacing: 4) {
                    Text("\(allRecoveryEvents.count)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(.blue)
                    Text("events")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Total recorded")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private var trendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Recovery Trend", systemImage: "heart.fill")
                .font(.headline)
                .foregroundColor(.red)

            if recoveryTrend.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bolt.slash")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text("No recovery events yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Recovery events are detected when you ride with a power meter and have a hard effort (85%+ max HR) followed by coasting or stopping for 60+ seconds.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 160)
            } else {
                Chart {
                    // Reference bands
                    RectangleMark(
                        yStart: .value("Excellent low", 30),
                        yEnd: .value("Excellent high", 60)
                    )
                    .foregroundStyle(Color.green.opacity(0.08))

                    RectangleMark(
                        yStart: .value("Good low", 20),
                        yEnd: .value("Good high", 30)
                    )
                    .foregroundStyle(Color.orange.opacity(0.08))

                    // Recovery trend line
                    ForEach(recoveryTrend, id: \.date) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("HR Drop (bpm)", point.avgDelta)
                        )
                        .foregroundStyle(.red)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("HR Drop (bpm)", point.avgDelta)
                        )
                        .foregroundStyle(recoveryColor(point.avgDelta))
                        .symbolSize(50)
                    }
                }
                .frame(height: 200)
                .chartYAxisLabel("bpm drop in 60s")
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    }
                }

                // Legend
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Circle().fill(Color.green).frame(width: 8, height: 8)
                        Text("Excellent (30+)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    HStack(spacing: 4) {
                        Circle().fill(Color.orange).frame(width: 8, height: 8)
                        Text("Good (20-30)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    HStack(spacing: 4) {
                        Circle().fill(Color.red).frame(width: 8, height: 8)
                        Text("Developing (<20)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private var interpretationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("What This Measures", systemImage: "info.circle")
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                interpretRow(
                    icon: "heart.fill",
                    color: .red,
                    title: "HR Recovery Delta",
                    body: "How many beats your heart drops in 60 seconds after stopping a hard effort. A bigger drop means your cardiovascular system recovers faster — a direct indicator of aerobic fitness."
                )

                Divider()

                interpretRow(
                    icon: "arrow.up.right",
                    color: .green,
                    title: "Rising trend = improving",
                    body: "As your aerobic base develops from Z2 riding and strength work, your heart becomes more efficient. You'll see the recovery delta increase over weeks and months."
                )

                Divider()

                interpretRow(
                    icon: "bolt.fill",
                    color: .orange,
                    title: "Creatine connection",
                    body: "Creatine supports faster phosphocreatine resynthesis during recovery. Over time with consistent supplementation, you may see improved recovery deltas alongside your fitness gains."
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private var maxHRCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("All-Time Max HR", systemImage: "waveform.path.ecg")
                .font(.headline)
                .foregroundColor(.orange)

            if let maxHR = allTimeMaxHR, let ride = allTimeMaxHRRide {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(maxHR) bpm")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.orange)
                        Text("Recorded on \(ride.formattedDate)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if let distance = Optional(ride.distance) {
                            Text("\(String(format: "%.1f", distance)) mi · \(ride.formattedDuration)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "flame.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.orange.opacity(0.3))
                }

                let profile = UserProfile.load()
                let currentMax = profile.maxHeartRate ?? (220 - profile.age)
                if maxHR > currentMax {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text("Your recorded max (\(maxHR)) is higher than your profile setting (\(currentMax)). Update your profile to improve zone accuracy.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }
            } else {
                Text("No rides with max HR data yet.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private var recentEventsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Recent Recovery Events", systemImage: "list.bullet")
                .font(.headline)

            if allRecoveryEvents.isEmpty {
                Text("No events recorded yet. Events appear when you have a power meter and a hard effort followed by 60+ seconds of coasting or stopping.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(allRecoveryEvents.prefix(10).enumerated()), id: \.element.event.id) { index, item in
                        VStack(spacing: 0) {
                            HStack(spacing: 12) {
                                // Date
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(shortDate(item.ride.date))
                                        .font(.subheadline)
                                    Text(item.event.recoveryType == .coasting ? "Coasting" : "Stopped")
                                        .font(.caption2)
                                        .foregroundColor(item.event.recoveryType == .coasting ? .blue : .gray)
                                }

                                Spacer()

                                // HR before → after
                                HStack(spacing: 4) {
                                    Text("\(item.event.peakHR)")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Image(systemName: "arrow.right")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text("\(item.event.hrAt60s)")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text("bpm")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                // Delta badge
                                Text("-\(item.event.recoveryDelta)")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(recoveryColor(Double(item.event.recoveryDelta)))
                                    .frame(width: 48)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)

                            if index < min(allRecoveryEvents.count, 10) - 1 {
                                Divider().padding(.leading, 12)
                            }
                        }
                    }
                }
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    // MARK: - Helpers

    private func interpretRow(icon: String, color: Color, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(body)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func recoveryColor(_ delta: Double) -> Color {
        if delta >= 30 { return .green }
        if delta >= 20 { return .orange }
        return .red
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}
