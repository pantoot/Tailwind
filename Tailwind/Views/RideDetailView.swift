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
                    if (ride.routeCoordinates != nil && !ride.routeCoordinates!.isEmpty) || ride.timeInZone != nil {
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
                    Button("Done") {
                        dismiss()
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

                // Add TSS to training load if calculated
                if let tss = updatedRide.hrTSS {
                    trainingLoadManager.addTSS(date: updatedRide.date, tss: tss)
                }

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
