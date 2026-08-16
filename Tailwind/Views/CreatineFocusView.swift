import SwiftUI
import Charts

/// Embeddable power analytics content — 4 widget cards without NavigationStack.
/// Used inside RidesTabView's Power segment.
struct PowerAnalyticsContent: View {
    @EnvironmentObject var rideHistory: RideHistory
    @EnvironmentObject var weightLogManager: WeightLogManager
    @EnvironmentObject var creatineSettingsManager: CreatineSettingsManager

    /// Rides with power data, sorted oldest-first for charts.
    /// Excludes rides shorter than 20 minutes (cool downs, warm ups) to avoid skewing metrics.
    var powerRides: [Ride] {
        rideHistory.rides
            .filter { $0.creatineMetrics != nil && $0.duration >= 20 * 60 }
            .sorted { $0.date < $1.date }
    }

    /// Rides from the last 30 days with power data
    private var recentPowerRides: [Ride] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return powerRides.filter { $0.date >= cutoff }
    }

    /// Loaded once per render rather than once per ride. Classifying is O(1)
    /// arithmetic and free to repeat; a UserDefaults read plus JSON decode per
    /// ride would not be.
    private let userProfile = UserProfile.load()

    /// A steady endurance ride's 30-second peak is its cruising power sampled
    /// at its best half-minute, not a sprint. Those points still plot — this
    /// rider mostly rides endurance, so filtering them would routinely empty
    /// the chart — but they render hollow so the trend isn't read as burst
    /// fitness.
    private func isBurst(_ ride: Ride) -> Bool {
        RideClassificationService.classify(ride: ride, profile: userProfile)
            .isBurstRepresentative
    }

    private func burstCaption(for rides: [Ride]) -> String {
        rides.contains(where: isBurst)
            ? "Hollow points had no real burst — that's cruising power, not a sprint."
            : "No real bursts in the last 30 days — these are cruising peaks from steady rides."
    }

    var body: some View {
        Group {
            if powerRides.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        matchesBurnedCard
                        max30sPowerCard
                        wkgDeltaCard
                        cardiacEfficiencyCard
                        hrRecoveryCard
                        Spacer(minLength: 40)
                    }
                    .padding()
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bolt.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Power Data Yet")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Import a FIT file from a ride with a power meter to see creatine-relevant analytics.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Widget 1: Matches Burned

    private var matchesBurnedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Matches Burned", systemImage: "flame.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                Spacer()
                Text("\(Int(creatineSettingsManager.settings.effectiveMatchThreshold))W+")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if recentPowerRides.isEmpty {
                Text("No rides with power data in the last 30 days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Chart {
                    ForEach(recentPowerRides) { ride in
                        BarMark(
                            x: .value("Date", ride.date, unit: .day),
                            y: .value("Matches", ride.creatineMetrics?.matchCount ?? 0)
                        )
                        .foregroundStyle(.orange.gradient)
                    }

                    if let startDate = creatineSettingsManager.settings.creatineStartDate {
                        RuleMark(x: .value("Creatine Start", startDate))
                            .foregroundStyle(.green)
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                            .annotation(position: .top, alignment: .leading) {
                                Text("Creatine")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            }
                    }
                }
                .frame(height: 160)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    // MARK: - Widget 2: Max 30s Power

    private var max30sPowerCard: some View {
        // Resolved once: `recentPowerRides` re-filters and re-sorts the whole
        // ride history on every access.
        let rides = recentPowerRides
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Max 30s Power", systemImage: "bolt.fill")
                    .font(.headline)
                    .foregroundStyle(.blue)
                Spacer()
                if let lastRide = rides.last,
                   let latest = lastRide.creatineMetrics?.max30sPower {
                    Text(isBurst(lastRide) ? "\(Int(latest))W" : "\(Int(latest))W cruising")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.blue)
                }
            }

            Text("Watch the floor rise")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !rides.isEmpty {
                Chart {
                    ForEach(rides) { ride in
                        LineMark(
                            x: .value("Date", ride.date),
                            y: .value("Watts", ride.creatineMetrics?.max30sPower ?? 0)
                        )
                        .foregroundStyle(.blue)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        PointMark(
                            x: .value("Date", ride.date),
                            y: .value("Watts", ride.creatineMetrics?.max30sPower ?? 0)
                        )
                        .foregroundStyle(.blue)
                        .opacity(isBurst(ride) ? 1.0 : 0.3)
                        .symbolSize(isBurst(ride) ? 30 : 18)
                    }

                    if let startDate = creatineSettingsManager.settings.creatineStartDate {
                        RuleMark(x: .value("Creatine Start", startDate))
                            .foregroundStyle(.green)
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                    }
                }
                .frame(height: 160)
                .chartYScale(domain: paddedDomain(values: rides.map { $0.creatineMetrics?.max30sPower ?? 0 }))
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    }
                }

                Text(burstCaption(for: rides))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    // MARK: - Widget 3: W/kg Delta

    private var wkgDeltaCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("W/kg (30s Max)", systemImage: "scalemass.fill")
                    .font(.headline)
                    .foregroundStyle(.purple)
                Spacer()
            }

            // Quick weight entry
            WeightQuickEntry(weightLogManager: weightLogManager)

            let wkgData = recentPowerRides.compactMap { ride -> (ride: Ride, wkg: Double)? in
                guard let metrics = ride.creatineMetrics else { return nil }
                let weightLbs = weightLogManager.weightOnOrBefore(ride.date)
                    ?? weightLogManager.latestWeight()
                    ?? UserProfile.load().weight
                let weightKg = weightLbs * 0.453592
                guard weightKg > 0 else { return nil }
                return (ride: ride, wkg: metrics.max30sPower / weightKg)
            }

            if !wkgData.isEmpty {
                Chart {
                    ForEach(wkgData, id: \.ride.id) { item in
                        LineMark(
                            x: .value("Date", item.ride.date),
                            y: .value("W/kg", item.wkg)
                        )
                        .foregroundStyle(.purple)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        PointMark(
                            x: .value("Date", item.ride.date),
                            y: .value("W/kg", item.wkg)
                        )
                        .foregroundStyle(.purple)
                        .opacity(isBurst(item.ride) ? 1.0 : 0.3)
                        .symbolSize(isBurst(item.ride) ? 30 : 18)
                    }

                    if let startDate = creatineSettingsManager.settings.creatineStartDate {
                        RuleMark(x: .value("Creatine Start", startDate))
                            .foregroundStyle(.green)
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                    }
                }
                .frame(height: 160)
                .chartYScale(domain: paddedDomain(values: wkgData.map { $0.wkg }))
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(String(format: "%.1f", v))
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    }
                }

                if let latestBurst = wkgData.last(where: { isBurst($0.ride) }) {
                    Text(String(format: "Latest real burst: %.2f W/kg", latestBurst.wkg))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let latest = wkgData.last {
                    Text(String(format: "Latest: %.2f W/kg (cruising, not a burst)", latest.wkg))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Log your weight above to see W/kg trends")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    // MARK: - Widget 4: Cardiac Efficiency

    private var cardiacEfficiencyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Cardiac Efficiency", systemImage: "waveform.path.ecg")
                    .font(.headline)
                    .foregroundStyle(.teal)
                Spacer()
            }

            Text("Watts per heartbeat — higher means fitter")
                .font(.caption)
                .foregroundStyle(.secondary)

            let effData = powerRides.compactMap { ride -> (ride: Ride, efficiency: Double)? in
                guard let metrics = ride.creatineMetrics,
                      metrics.averagePower > 0,
                      ride.averageHeartRate > 0 else { return nil }
                return (ride: ride, efficiency: metrics.averagePower / ride.averageHeartRate)
            }

            if !effData.isEmpty {
                Chart {
                    ForEach(effData, id: \.ride.id) { item in
                        LineMark(
                            x: .value("Date", item.ride.date),
                            y: .value("W/bpm", item.efficiency)
                        )
                        .foregroundStyle(.teal)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        PointMark(
                            x: .value("Date", item.ride.date),
                            y: .value("W/bpm", item.efficiency)
                        )
                        .foregroundStyle(.teal)
                        .symbolSize(30)
                    }

                    if let startDate = creatineSettingsManager.settings.creatineStartDate {
                        RuleMark(x: .value("Creatine Start", startDate))
                            .foregroundStyle(.green)
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                    }
                }
                .frame(height: 160)
                .chartYScale(domain: paddedDomain(values: effData.map { $0.efficiency }))
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(String(format: "%.2f", v))
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    }
                }

                if let latest = effData.last {
                    Text(String(format: "Latest: %.2f W/bpm", latest.efficiency))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Needs rides with both power and heart rate data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    // MARK: - Widget 5: HR Recovery

    private var hrRecoveryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("HR Recovery", systemImage: "heart.fill")
                .font(.headline)
                .foregroundStyle(.red)

            let allEvents = powerRides.flatMap { ride -> [(ride: Ride, event: HRRecoveryEvent)] in
                (ride.creatineMetrics?.hrRecoveryEvents ?? []).map { (ride: ride, event: $0) }
            }

            if allEvents.isEmpty {
                Text("No recovery events detected yet. These appear when you have a hard effort followed by coasting or stopping for 60+ seconds.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                // Trend line of average recovery delta per ride
                let rideAverages = powerRides.compactMap { ride -> (ride: Ride, avgDelta: Double)? in
                    guard let events = ride.creatineMetrics?.hrRecoveryEvents, !events.isEmpty else { return nil }
                    let avg = Double(events.reduce(0) { $0 + $1.recoveryDelta }) / Double(events.count)
                    return (ride: ride, avgDelta: avg)
                }

                if !rideAverages.isEmpty {
                    Chart {
                        ForEach(rideAverages, id: \.ride.id) { item in
                            LineMark(
                                x: .value("Date", item.ride.date),
                                y: .value("HR Drop", item.avgDelta)
                            )
                            .foregroundStyle(.red)

                            PointMark(
                                x: .value("Date", item.ride.date),
                                y: .value("HR Drop", item.avgDelta)
                            )
                            .foregroundStyle(recoveryColor(item.avgDelta))
                            .symbolSize(40)
                        }

                        if let startDate = creatineSettingsManager.settings.creatineStartDate {
                            RuleMark(x: .value("Creatine Start", startDate))
                                .foregroundStyle(.green)
                                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                        }
                    }
                    .frame(height: 120)
                    .chartYScale(domain: paddedDomain(values: rideAverages.map { $0.avgDelta }))
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                        }
                    }
                }

                // Recent events list
                VStack(spacing: 8) {
                    ForEach(allEvents.suffix(5), id: \.event.id) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.ride.formattedDate)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                HStack(spacing: 4) {
                                    Text("\(item.event.peakHR)")
                                        .fontWeight(.medium)
                                    Image(systemName: "arrow.right")
                                        .font(.caption2)
                                    Text("\(item.event.hrAt60s)")
                                        .fontWeight(.medium)
                                    Text("bpm")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            // Recovery delta badge
                            Text("-\(item.event.recoveryDelta)")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(recoveryColor(Double(item.event.recoveryDelta)))

                            // Coasting/Stopped badge
                            Text(item.event.recoveryType == .coasting ? "Coasting" : "Stopped")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(item.event.recoveryType == .coasting ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                                .cornerRadius(4)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    // MARK: - Helpers

    /// Compute a Y-axis domain with ~10% padding above and below the data range
    private func paddedDomain(values: [Double]) -> ClosedRange<Double> {
        guard let min = values.min(), let max = values.max(), max > min else {
            let v = values.first ?? 0
            return (v - 1)...(v + 1)
        }
        let padding = (max - min) * 0.15
        return (min - padding)...(max + padding)
    }

    private func recoveryColor(_ delta: Double) -> Color {
        if delta > 30 { return .green }
        if delta > 20 { return .orange }
        return .red
    }
}

// MARK: - Quick Weight Entry

struct WeightQuickEntry: View {
    @ObservedObject var weightLogManager: WeightLogManager
    @EnvironmentObject var healthKitService: HealthKitService
    @State private var weightText = ""
    @State private var isSyncing = false
    @State private var syncMessage: String?
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    Task { await syncFromHealthKit() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                        Text("Sync")
                            .font(.caption)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isSyncing)

                if isSyncing {
                    ProgressView()
                        .controlSize(.small)
                }

                Spacer()

                if let latest = weightLogManager.latestWeight() {
                    Text(String(format: "%.1f lbs", latest))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }

            if let msg = syncMessage {
                Text(msg)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Image(systemName: "scalemass")
                    .foregroundStyle(.secondary)

                TextField("Weight", text: $weightText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .focused($isFocused)

                Text("lbs")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Log") {
                    if let weight = Double(weightText), weight > 0 {
                        weightLogManager.addEntry(WeightEntry(weightLbs: weight))
                        weightText = ""
                        isFocused = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(Double(weightText) == nil)

                Spacer()
            }
        }
    }

    private func syncFromHealthKit() async {
        isSyncing = true
        syncMessage = nil

        // Re-request auth to prompt for any new types (lean body mass, body fat).
        // An auth failure must not fall through to the fetches — they'd return []
        // and the user would see "No weight data" for what is a permission problem.
        do {
            try await healthKitService.requestAuthorization()
        } catch {
            print("❌ HealthKit authorization failed during weight sync: \(error.localizedDescription)")
            await MainActor.run {
                syncMessage = "Couldn't access Apple Health — check permissions in Settings"
                isSyncing = false
            }
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run { syncMessage = nil }
            return
        }

        async let weightTask = healthKitService.fetchWeightSamples(days: 365)
        async let leanTask = healthKitService.fetchLeanBodyMassSamples(days: 365)
        async let fatTask = healthKitService.fetchBodyFatSamples(days: 365)

        let weightSamples = await weightTask
        let leanSamples = await leanTask
        let fatSamples = await fatTask

        let added = weightLogManager.syncFromHealthKit(
            weightSamples: weightSamples,
            leanMassSamples: leanSamples,
            bodyFatSamples: fatSamples
        )

        await MainActor.run {
            if weightSamples.isEmpty {
                syncMessage = "No weight data in Apple Health"
            } else if added == 0 {
                syncMessage = "Up to date"
            } else {
                syncMessage = "+\(added) entries from Health"
            }
            isSyncing = false
        }

        // Auto-clear message after 3 seconds
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        await MainActor.run { syncMessage = nil }
    }
}
