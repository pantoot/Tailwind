import SwiftUI

struct RideDetailView: View {
    let ride: Ride
    @Environment(\.dismiss) var dismiss

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

                    Spacer()
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Ride Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
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
