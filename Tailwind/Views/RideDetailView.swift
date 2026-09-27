import SwiftUI

struct RideDetailView: View {
    @State var ride: Ride
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var healthKitService: HealthKitService
    @EnvironmentObject var fitImportService: FITImportService
    @EnvironmentObject var rideHistory: RideHistory
    @EnvironmentObject var trainingLoadManager: TrainingLoadManager

    @State private var isWritingActiveEnergy = false
    @State private var showingActiveEnergySuccess = false
    @State private var showingActiveEnergyError = false
    @State private var activeEnergyErrorMessage = ""

    // Watch HR merge state
    @State private var isMergingWatchHR = false
    @State private var showingMergeSuccess = false
    @State private var showingMergeError = false
    @State private var mergeErrorMessage = ""

    // Edit state
    @State private var showingEdit = false

    // Export state
    @State private var isExporting = false
    @State private var exportShareItem: ExportShareItem?
    @State private var showingExportError = false
    @State private var exportErrorMessage = ""

    private struct ExportShareItem: Identifiable {
        let id = UUID()
        let url: URL
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Date header
                    VStack(spacing: 4) {
                        Text(ride.formattedDate)
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    .padding(.top)

                    // Chart view (show if we have route coordinates or time in zone data)
                    if ride.hasRouteData || ride.timeInZone != nil {
                        NavigationLink(destination: RideDetailChartView(ride: ride)) {
                            HStack {
                                Image(systemName: "chart.xyaxis.line")
                                    .foregroundColor(.blue)
                                Text("View Detailed Charts")
                                    .fontWeight(.semibold)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                        }
                        .padding(.horizontal)
                    }

                    // Main stats grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                        StatCard(
                            title: "Distance",
                            value: ride.formattedDistance,
                            icon: "map",
                            color: .blue
                        )

                        StatCard(
                            title: "Duration",
                            value: ride.formattedDuration,
                            icon: "clock",
                            color: .orange
                        )

                        StatCard(
                            title: "Avg Speed",
                            value: ride.formattedAvgSpeed,
                            icon: "speedometer",
                            color: .green
                        )

                        StatCard(
                            title: "Max Speed",
                            value: ride.formattedMaxSpeed,
                            icon: "gauge.high",
                            color: .red
                        )

                        StatCard(
                            title: "Avg HR",
                            value: String(format: "%.0f bpm", ride.averageHeartRate),
                            icon: "heart.fill",
                            color: .pink
                        )

                        StatCard(
                            title: "Max HR",
                            value: "\(ride.maxHeartRate) bpm",
                            icon: "heart.circle.fill",
                            color: .red
                        )

                        // Shown as a pair so the two-column rows stay aligned even
                        // when only one of the two was recorded.
                        if ride.hasPowerOrCadence {
                            StatCard(
                                title: "Avg Power",
                                value: ride.formattedAvgPower,
                                icon: "bolt.fill",
                                color: .yellow
                            )

                            StatCard(
                                title: "Avg Cadence",
                                value: ride.formattedAvgCadence,
                                icon: "arrow.clockwise",
                                color: .teal
                            )
                        }

                        StatCard(
                            title: "Calories",
                            value: ride.formattedCalories,
                            icon: "flame.fill",
                            color: .orange
                        )

                        StatCard(
                            title: "Pace",
                            value: ride.averageSpeed > 0 ? String(format: "%.1f min/mi", 60 / ride.averageSpeed) : "—",
                            icon: "figure.run",
                            color: .purple
                        )
                    }
                    .padding(.horizontal)

                    // Training metrics section
                    if let tss = ride.hrTSS, let timeInZone = ride.timeInZone {
                        trainingMetricsSection(tss: tss, timeInZone: timeInZone)
                    }

                    // Creatine metrics section
                    if let cm = ride.creatineMetrics {
                        creatineMetricsSection(cm)
                    }

                    Spacer()
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Ride Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    // Fix Move Ring button
                    Button {
                        Task {
                            await writeActiveEnergy()
                        }
                    } label: {
                        if isWritingActiveEnergy {
                            ProgressView()
                        } else {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                        }
                    }
                    .disabled(isWritingActiveEnergy || ride.calories <= 0)

                    // Merge Watch HR button (only show when no HR data)
                    if ride.averageHeartRate == 0 {
                        Button {
                            Task {
                                await mergeWatchHeartRate()
                            }
                        } label: {
                            if isMergingWatchHR {
                                ProgressView()
                            } else {
                                Image(systemName: "heart.fill")
                                    .foregroundColor(.pink)
                            }
                        }
                        .disabled(isMergingWatchHR)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            Task {
                                await exportRide()
                            }
                        } label: {
                            if isExporting {
                                ProgressView()
                            } else {
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                        .disabled(isExporting)

                        Button {
                            showingEdit = true
                        } label: {
                            Image(systemName: "pencil")
                        }
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
            .alert("Move Ring Updated", isPresented: $showingActiveEnergySuccess) {
                Button("OK") { }
            } message: {
                Text("\(Int(ride.calories)) calories written to Active Energy. Your Move ring should update shortly.")
            }
            .alert("Error", isPresented: $showingActiveEnergyError) {
                Button("OK") { }
            } message: {
                Text(activeEnergyErrorMessage)
            }
            .alert("Heart Rate Merged", isPresented: $showingMergeSuccess) {
                Button("OK") { }
            } message: {
                Text("Apple Watch heart rate data has been merged into this ride. Average HR: \(Int(ride.averageHeartRate)) bpm")
            }
            .alert("Merge Failed", isPresented: $showingMergeError) {
                Button("OK") { }
            } message: {
                Text(mergeErrorMessage)
            }
            .alert("Export Failed", isPresented: $showingExportError) {
                Button("OK") { }
            } message: {
                Text(exportErrorMessage)
            }
            .sheet(item: $exportShareItem) { item in
                ShareSheet(activityItems: [item.url])
            }
            .sheet(isPresented: $showingEdit) {
                EditRideView(ride: ride) { updatedRide in
                    rideHistory.updateRide(ride.id, with: updatedRide)
                    // Rebuild rather than addTSS: the day bucket already holds this
                    // ride's original score, so adding would double-count it.
                    trainingLoadManager.syncFromRides(rideHistory.rides)
                    ride = updatedRide
                }
            }
        }
    }

    /// Post-block HR recovery quality: a fall of 15+ bpm within 90s is healthy,
    /// under 8 suggests the recovery valley was ridden too hard to recover in.
    private func blockRecoveryColor(_ delta: Int) -> Color {
        if delta > 15 { return .green }
        if delta > 8 { return .orange }
        return .red
    }

    /// Pw:HR decoupling — did heart rate drift against power between the
    /// first and second half? Under 5% is the aerobic-endurance benchmark.
    private func decouplingRow(_ decoupling: AerobicDecoupling) -> some View {
        HStack(spacing: 6) {
            Text(String(format: "Pw:HR Decoupling: %+.1f%%", decoupling.percent))
            Text(decouplingLabel(decoupling.rating))
                .fontWeight(.medium)
                .foregroundStyle(decouplingColor(decoupling.rating))
            Text(String(format: "(EF %.2f → %.2f)", decoupling.firstHalfEfficiency, decoupling.secondHalfEfficiency))
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal)
    }

    private func decouplingLabel(_ rating: AerobicDecoupling.Rating) -> String {
        switch rating {
        case .coupled: return "coupled"
        case .moderate: return "moderate drift"
        case .high: return "high drift"
        }
    }

    private func decouplingColor(_ rating: AerobicDecoupling.Rating) -> Color {
        switch rating {
        case .coupled: return .green
        case .moderate: return .orange
        case .high: return .red
        }
    }

    @ViewBuilder
    private func creatineMetricsSection(_ cm: CreatineMetrics) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Power Analysis")
                .font(.title3.bold())
                .padding(.horizontal)

            // 30s Max Power + Match Count
            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    Text(String(format: "%.0f", cm.max30sPower))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.blue)
                    Text("30s Max (W)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)

                VStack(spacing: 4) {
                    Text("\(cm.matchCount)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                    Text("Matches")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)

                VStack(spacing: 4) {
                    Text(String(format: "%.0f", cm.averagePower))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.green)
                    Text("Avg Power (W)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            }
            .padding(.horizontal)

            if let np = cm.normalizedPower {
                Text(String(format: "Normalized Power: %.0f W (VI %.2f)", np, np / max(cm.averagePower, 1)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }

            if let decoupling = cm.aerobicDecoupling {
                decouplingRow(decoupling)
            }

            // Effort blocks — the structured intervals of the ride
            if let blocks = cm.effortBlocks, !blocks.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Effort Blocks")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal)

                    ForEach(blocks) { block in
                        HStack {
                            Text(formatOffset(block.startOffset))
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .frame(width: 60, alignment: .leading)

                            Text(String(format: "%.0f min", block.duration / 60))
                                .font(.caption)
                                .frame(width: 46, alignment: .leading)

                            Text(String(format: "%.0f W", block.averagePower))
                                .font(.caption)
                                .fontWeight(.medium)

                            Spacer()

                            if let start = block.startHR, let end = block.endHR {
                                Text("\(start) → \(end) bpm")
                                    .font(.caption)
                            }

                            if let recovery = block.recoveryDelta {
                                Text("-\(recovery)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(blockRecoveryColor(recovery))
                            }
                        }
                        .padding(.horizontal)
                    }

                    Text("HR arrow spans each block; the drop is 90s after it ends")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal)
                }
            }

            // Match details
            if !cm.matches.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Match Details")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal)

                    ForEach(cm.matches) { match in
                        HStack {
                            Text(formatOffset(match.startOffset))
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .frame(width: 60, alignment: .leading)

                            Text(String(format: "%.0fs", match.duration))
                                .font(.caption)
                                .frame(width: 40)

                            Spacer()

                            Text(String(format: "%.0f W peak", match.peakPower))
                                .font(.caption)
                                .fontWeight(.medium)

                            Text(String(format: "%.0f W avg", match.averagePower))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                    }
                }
            }

            // HR Recovery events
            if !cm.hrRecoveryEvents.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("HR Recovery Events")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal)

                    ForEach(cm.hrRecoveryEvents) { event in
                        HStack {
                            Text(formatOffset(event.startOffset))
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .frame(width: 60, alignment: .leading)

                            Text("\(event.peakHR) → \(event.hrAt60s) bpm")
                                .font(.caption)

                            Spacer()

                            Text("-\(event.recoveryDelta)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(event.recoveryDelta > 30 ? .green : event.recoveryDelta > 20 ? .orange : .red)

                            Text(event.recoveryType == .coasting ? "Coasting" : "Stopped")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(event.recoveryType == .coasting ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                                .cornerRadius(4)
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        .padding(.vertical)
    }

    /// Package the ride + raw HealthKit streams into a JSON file and open the share sheet.
    private func exportRide() async {
        isExporting = true
        defer { isExporting = false }

        let samples = await healthKitService.fetchRawSamples(for: ride)
        do {
            let url = try RideExportService.writeExportFile(ride: ride, samples: samples)
            print("📤 Exported \(url.lastPathComponent): \(samples.power.count) power, \(samples.heartRate.count) HR, \(samples.cadence.count) cadence samples")
            exportShareItem = ExportShareItem(url: url)
        } catch {
            print("❌ Ride export failed: \(error.localizedDescription)")
            exportErrorMessage = error.localizedDescription
            showingExportError = true
        }
    }

    private func formatOffset(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func mergeWatchHeartRate() async {
        isMergingWatchHR = true
        do {
            let updatedRide = try await fitImportService.mergeWatchHeartRate(into: ride)

            // Update ride history
            await MainActor.run {
                rideHistory.updateRide(ride.id, with: updatedRide)

                // Rebuild rather than addTSS: the day bucket may already hold this
                // ride's pre-merge score, so adding would double-count it.
                trainingLoadManager.syncFromRides(rideHistory.rides)

                // Update local state so UI refreshes
                ride = updatedRide

                isMergingWatchHR = false
                showingMergeSuccess = true
            }
        } catch {
            await MainActor.run {
                isMergingWatchHR = false
                mergeErrorMessage = error.localizedDescription
                showingMergeError = true
            }
        }
    }

    private func writeActiveEnergy() async {
        isWritingActiveEnergy = true
        do {
            try await healthKitService.writeActiveEnergy(for: ride)
            await MainActor.run {
                isWritingActiveEnergy = false
                showingActiveEnergySuccess = true
            }
        } catch {
            await MainActor.run {
                isWritingActiveEnergy = false
                activeEnergyErrorMessage = error.localizedDescription
                showingActiveEnergyError = true
            }
        }
    }

    @ViewBuilder
    private func trainingMetricsSection(tss: Double, timeInZone: TimeInZone) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Training Load")
                .font(.title3.bold())
                .padding(.horizontal)

            // TSS Card
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Training Stress Score")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.0f TSS", tss))
                        .font(.title2.bold())
                        .foregroundColor(.orange)
                }
                Spacer()
                Image(systemName: "bolt.fill")
                    .font(.largeTitle)
                    .foregroundColor(.orange)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            .padding(.horizontal)

            // Time in Zone Summary
            Text("Time in Zone")
                .font(.title3.bold())
                .padding(.horizontal)

            VStack(spacing: 12) {
                ForEach(HeartRateZones.Zone.allCases, id: \.self) { zone in
                    ZoneBar(
                        zone: zone,
                        minutes: timeInZone.minutes(for: zone),
                        percentage: timeInZone.percentage(for: zone)
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
}

struct ZoneBar: View {
    let zone: HeartRateZones.Zone
    let minutes: Double
    let percentage: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 6) {
                    Text("Z\(zone.rawValue)")
                        .font(.caption.bold())
                        .foregroundColor(zone.color)
                        .frame(width: 30, alignment: .leading)

                    Text(zone.name)
                        .font(.caption)
                        .foregroundColor(.primary)
                }

                Spacer()

                HStack(spacing: 8) {
                    Text(String(format: "%.0f min", minutes))
                        .font(.caption.bold())
                        .foregroundColor(.primary)

                    Text(String(format: "%.0f%%", percentage))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))

                    Rectangle()
                        .fill(zone.color)
                        .frame(width: geometry.size.width * CGFloat(percentage / 100))
                }
            }
            .frame(height: 8)
            .clipShape(Capsule())
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)

            Text(title)
                .font(.caption)
                .foregroundColor(.gray)

            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}
