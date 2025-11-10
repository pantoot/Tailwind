import SwiftUI
import Charts
import MapKit

// Simplified chart view for individual ride details
struct RideDetailChartView: View {
    let ride: Ride

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Route map if available
                if let coordinates = ride.routeCoordinates, !coordinates.isEmpty {
                    routeMapView(coordinates: coordinates)
                }

                // Heart Rate Zone Distribution
                if let timeInZone = ride.timeInZone {
                    heartRateZoneChart(timeInZone: timeInZone)
                }

                // Stats summary
                statsView
            }
            .padding()
        }
        .navigationTitle("Ride Analysis")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func routeMapView(coordinates: [Ride.Coordinate]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Route Map")
                .font(.headline)

            Map {
                // Draw route polyline
                MapPolyline(coordinates: coordinates.map { $0.clCoordinate })
                    .stroke(.blue, lineWidth: 3)
            }
            .frame(height: 250)
            .cornerRadius(12)
        }
    }

    @ViewBuilder
    private func heartRateZoneChart(timeInZone: TimeInZone) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Heart Rate Zones")
                .font(.headline)

            Chart {
                ForEach(HeartRateZones.Zone.allCases, id: \.self) { zone in
                    let minutes = timeInZone.minutes(for: zone)
                    if minutes > 0 {
                        BarMark(
                            x: .value("Minutes", minutes),
                            y: .value("Zone", "Z\(zone.rawValue)")
                        )
                        .foregroundStyle(zone.color.gradient)
                        .annotation(position: .trailing) {
                            Text(String(format: "%.0f min", minutes))
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(position: .bottom)
            }
            .frame(height: 200)
        }
    }

    @ViewBuilder
    private var statsView: some View {
        VStack(spacing: 12) {
            Text("Performance Metrics")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                RideMetricCard(
                    title: "Distance",
                    value: String(format: "%.2f", ride.distance),
                    unit: "mi",
                    icon: "map",
                    color: .blue
                )

                RideMetricCard(
                    title: "Duration",
                    value: ride.formattedDuration,
                    unit: "",
                    icon: "clock",
                    color: .orange
                )

                RideMetricCard(
                    title: "Avg Speed",
                    value: String(format: "%.1f", ride.averageSpeed),
                    unit: "mph",
                    icon: "speedometer",
                    color: .green
                )

                RideMetricCard(
                    title: "Max Speed",
                    value: String(format: "%.1f", ride.maxSpeed),
                    unit: "mph",
                    icon: "gauge.high",
                    color: .red
                )

                RideMetricCard(
                    title: "Avg HR",
                    value: String(format: "%.0f", ride.averageHeartRate),
                    unit: "bpm",
                    icon: "heart.fill",
                    color: .red
                )

                RideMetricCard(
                    title: "Max HR",
                    value: "\(ride.maxHeartRate)",
                    unit: "bpm",
                    icon: "heart.circle",
                    color: .red
                )

                RideMetricCard(
                    title: "Calories",
                    value: String(format: "%.0f", ride.calories),
                    unit: "cal",
                    icon: "flame.fill",
                    color: .orange
                )

                if let elevation = ride.elevationGain {
                    RideMetricCard(
                        title: "Elevation",
                        value: String(format: "%.0f", elevation),
                        unit: "ft",
                        icon: "arrow.up.right",
                        color: .purple
                    )
                }
            }
        }
    }
}

// Metric card component for ride analysis
struct RideMetricCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)

            Text(title)
                .font(.caption)
                .foregroundColor(.gray)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}
