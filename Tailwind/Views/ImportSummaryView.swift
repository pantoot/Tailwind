import SwiftUI
import MapKit

/// Post-import summary view showing detailed workout analytics (mPaceline-style)
struct ImportSummaryView: View {
    let ride: Ride
    let workoutData: FITWorkoutData?

    @EnvironmentObject var trainingLoadManager: TrainingLoadManager
    @Environment(\.dismiss) private var dismiss

    private let userProfile = UserProfile.load()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header with date and workout type
                    headerSection

                    // Core stats grid
                    coreStatsSection

                    // Heart rate section
                    if ride.averageHeartRate > 0 {
                        heartRateSection
                    }

                    // Time in zones
                    if let timeInZone = ride.timeInZone, timeInZone.totalSeconds > 0 {
                        zonesSection(timeInZone)
                    }

                    // Power highlights (creatine)
                    if let cm = ride.creatineMetrics {
                        powerHighlightsSection(cm)
                    }

                    // Training load / TSS
                    if ride.hrTSS != nil || ride.averageHeartRate > 0 {
                        trainingLoadSection
                    }

                    // Map preview. The ride arrives straight from the importer, so its
                    // track is still in memory and needs no load from the track store.
                    if let coordinates = ride.routeCoordinates, !coordinates.isEmpty {
                        mapSection(coordinates)
                    }

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Ride Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "bicycle")
                    .font(.title)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Cycling Workout")
                        .font(.headline)
                    Text(ride.formattedDate)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Imported badge
                Label("Imported", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.15))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    // MARK: - Core Stats

    private var coreStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Summary")
                .font(.headline)
                .padding(.horizontal, 4)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatCard(
                    title: "Duration",
                    value: ride.formattedDuration,
                    icon: "clock.fill",
                    color: .blue
                )

                StatCard(
                    title: "Distance",
                    value: ride.formattedDistance,
                    icon: "road.lanes",
                    color: .green
                )

                if let elevation = ride.elevationGain, elevation > 0 {
                    StatCard(
                        title: "Elevation",
                        value: String(format: "%.0f ft", elevation),
                        icon: "mountain.2.fill",
                        color: .orange
                    )
                }

                StatCard(
                    title: "Calories",
                    value: ride.formattedCalories,
                    icon: "flame.fill",
                    color: .red
                )

                StatCard(
                    title: "Avg Speed",
                    value: ride.formattedAvgSpeed,
                    icon: "speedometer",
                    color: .purple
                )

                StatCard(
                    title: "Max Speed",
                    value: ride.formattedMaxSpeed,
                    icon: "gauge.with.needle.fill",
                    color: .purple
                )
            }
        }
    }

    // MARK: - Heart Rate

    private var heartRateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Heart Rate")
                .font(.headline)
                .padding(.horizontal, 4)

            HStack(spacing: 16) {
                // Average HR with zone indicator
                VStack(spacing: 8) {
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text("\(Int(ride.averageHeartRate))")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                        Text("bpm")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Text("Average")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let zones = userProfile.hrZones {
                        let zone = zones.zone(for: Int(ride.averageHeartRate))
                        Text(zone.name)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(zone.color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(zone.color.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)

                // Max HR
                VStack(spacing: 8) {
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text("\(ride.maxHeartRate)")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundStyle(.red)
                        Text("bpm")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Text("Maximum")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let zones = userProfile.hrZones {
                        let zone = zones.zone(for: ride.maxHeartRate)
                        Text(zone.name)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(zone.color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(zone.color.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Zones

    private func zonesSection(_ timeInZone: TimeInZone) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Time in Zones")
                .font(.headline)
                .padding(.horizontal, 4)

            VStack(spacing: 8) {
                ForEach(HeartRateZones.Zone.allCases, id: \.rawValue) { zone in
                    ZoneBar(
                        zone: zone,
                        minutes: timeInZone.minutes(for: zone),
                        percentage: timeInZone.percentage(for: zone)
                    )
                }
            }
        }
    }

    // MARK: - Training Load

    private var trainingLoadSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Training Load")
                .font(.headline)
                .padding(.horizontal, 4)

            VStack(spacing: 16) {
                // TSS Score
                if let tss = ride.hrTSS {
                    let copy = summaryCopy(tss)
                    let accent = tone(copy.tone)
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Training Stress Score")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            HStack(alignment: .lastTextBaseline, spacing: 4) {
                                Text(String(format: "%.0f", tss))
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                    .foregroundStyle(accent)
                                Text("TSS")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Text(copy.interpretation)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if let note = classification.confidenceNote {
                                Text(note)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }

                        Spacer()

                        // Intensity gauge
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 8)

                            Circle()
                                .trim(from: 0, to: copy.ringProgress)
                                .stroke(accent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                .rotationEffect(.degrees(-90))

                            Text(copy.label)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)
                        }
                        .frame(width: 60, height: 60)
                    }
                }

                Divider()

                // Form impact
                let currentMetrics = trainingLoadManager.calculateCurrentMetrics()
                let predictedTSB = trainingLoadManager.predictTSB(afterWorkoutTSS: ride.hrTSS ?? 0)

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Form Impact")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 16) {
                            VStack(alignment: .leading) {
                                Text("Before")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(String(format: "%.0f", currentMetrics.tsb))
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            }

                            Image(systemName: "arrow.right")
                                .foregroundStyle(.secondary)

                            VStack(alignment: .leading) {
                                Text("After")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(String(format: "%.0f", predictedTSB))
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(predictedTSB < currentMetrics.tsb ? .orange : .green)
                            }
                        }
                    }

                    Spacer()

                    // Current form status
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Status")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(currentMetrics.formStatus.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(currentMetrics.formStatus.color)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }

    // MARK: - Power Highlights

    private func powerHighlightsSection(_ cm: CreatineMetrics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Power")
                .font(.headline)
                .padding(.horizontal, 4)

            HStack(spacing: 12) {
                StatCard(
                    title: "30s Max",
                    value: String(format: "%.0f W", cm.max30sPower),
                    icon: "bolt.fill",
                    color: .blue
                )

                StatCard(
                    title: "Matches",
                    value: "\(cm.matchCount)",
                    icon: "flame.fill",
                    color: .orange
                )

                StatCard(
                    title: "Avg Power",
                    value: String(format: "%.0f W", cm.averagePower),
                    icon: "gauge.medium",
                    color: .green
                )
            }
        }
    }

    // MARK: - Map

    private func mapSection(_ coordinates: [Ride.Coordinate]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Route")
                .font(.headline)
                .padding(.horizontal, 4)

            Map {
                MapPolyline(coordinates: coordinates.map { $0.clCoordinate })
                    .stroke(.blue, lineWidth: 3)
            }
            .frame(height: 200)
            .cornerRadius(12)
            .disabled(true)
        }
    }

    // MARK: - Helpers

    /// Intensity-led summary copy: a long endurance ride is a big day, not a
    /// hard one, so the label follows IF and structure rather than raw TSS.
    /// Rides with nothing to classify from fall back to the old TSS wording.
    private var classification: RideClassificationService.Classification {
        RideClassificationService.classify(ride: ride, profile: userProfile)
    }

    private func summaryCopy(_ tss: Double) -> RideClassificationService.SummaryCopy {
        RideClassificationService.summaryCopy(for: classification, tss: tss)
    }

    private func tone(_ tone: RideClassificationService.SummaryTone) -> Color {
        switch tone {
        case .easy: return .green
        case .moderate: return .yellow
        case .hard: return .orange
        case .veryHard: return .red
        }
    }
}

#Preview {
    ImportSummaryView(
        ride: Ride(
            duration: 3600,
            distance: 18.5,
            averageSpeed: 18.5,
            maxSpeed: 32.1,
            averageHeartRate: 145,
            maxHeartRate: 172,
            calories: 650,
            elevationGain: 1250,
            timeInZone: TimeInZone(
                zone1Seconds: 300,
                zone2Seconds: 1200,
                zone3Seconds: 1500,
                zone4Seconds: 500,
                zone5Seconds: 100
            ),
            hrTSS: 78
        ),
        workoutData: nil
    )
    .environmentObject(TrainingLoadManager())
}
