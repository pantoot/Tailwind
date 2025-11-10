import SwiftUI
import MapKit

struct RouteHistoryMapView: View {
    @EnvironmentObject var rideHistory: RideHistory
    @State private var selectedTimeframe: TimeFrame = .all
    @State private var mapCameraPosition: MapCameraPosition = .automatic

    enum TimeFrame: String, CaseIterable {
        case week = "7 Days"
        case month = "30 Days"
        case threeMonths = "3 Months"
        case year = "Year"
        case all = "All"

        var fullName: String {
            switch self {
            case .week: return "Last 7 Days"
            case .month: return "Last 30 Days"
            case .threeMonths: return "Last 3 Months"
            case .year: return "Last Year"
            case .all: return "All Time"
            }
        }

        func filterDate(from date: Date) -> Date {
            let calendar = Calendar.current
            switch self {
            case .week:
                return calendar.date(byAdding: .day, value: -7, to: date) ?? date
            case .month:
                return calendar.date(byAdding: .day, value: -30, to: date) ?? date
            case .threeMonths:
                return calendar.date(byAdding: .month, value: -3, to: date) ?? date
            case .year:
                return calendar.date(byAdding: .year, value: -1, to: date) ?? date
            case .all:
                return Date(timeIntervalSince1970: 0)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Timeframe picker
            Picker("Timeframe", selection: $selectedTimeframe) {
                ForEach(TimeFrame.allCases, id: \.self) { timeframe in
                    Text(timeframe.rawValue).tag(timeframe)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            // Stats summary
            summaryStats

            // Map
            if filteredRides.isEmpty {
                emptyStateView
            } else {
                routeMapView
            }
        }
        .navigationTitle("Route History")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var filteredRides: [Ride] {
        let cutoffDate = selectedTimeframe.filterDate(from: Date())
        let ridesWithRoutes = rideHistory.rides.filter { ride in
            ride.date >= cutoffDate && ride.routeCoordinates != nil && !ride.routeCoordinates!.isEmpty
        }

        // Limit to most recent 50 rides to prevent memory issues
        // Sort by date descending and take the most recent ones
        return Array(ridesWithRoutes.sorted { $0.date > $1.date }.prefix(50))
    }

    private var summaryStats: some View {
        VStack(spacing: 8) {
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("\(filteredRides.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Text("Rides")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()
                    .frame(height: 30)

                VStack(spacing: 4) {
                    Text(String(format: "%.1f mi", filteredRides.reduce(0) { $0 + $1.distance }))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    Text("Distance")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()
                    .frame(height: 30)

                VStack(spacing: 4) {
                    Text("\(uniqueRoutes)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    Text("Routes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if filteredRides.count >= 50 {
                Text("Showing most recent 50 rides")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .padding(.horizontal)
        .padding(.bottom, 12)
    }

    private var uniqueRoutes: Int {
        // Estimate unique routes by grouping rides with similar start/end points
        // This is a rough approximation
        let threshold: Double = 0.01 // ~1km in coordinate degrees
        var uniqueStarts: [Ride.Coordinate] = []

        for ride in filteredRides {
            guard let coordinates = ride.routeCoordinates,
                  let start = coordinates.first else { continue }

            let isUnique = !uniqueStarts.contains { existingStart in
                let latDiff = abs(start.latitude - existingStart.latitude)
                let lonDiff = abs(start.longitude - existingStart.longitude)
                return latDiff < threshold && lonDiff < threshold
            }

            if isUnique {
                uniqueStarts.append(start)
            }
        }

        return uniqueStarts.count
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "map")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text("No rides with GPS data")
                .font(.title3)
                .foregroundColor(.gray)

            if selectedTimeframe != .all {
                Text("Try selecting a different timeframe")
                    .font(.caption)
                    .foregroundColor(.gray)
            } else {
                Text("Complete rides with GPS tracking to see them here")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }

            // Debug info
            let totalRides = rideHistory.rides.count
            let ridesWithGPS = rideHistory.rides.filter {
                $0.routeCoordinates != nil && !$0.routeCoordinates!.isEmpty
            }.count

            if totalRides > 0 {
                VStack(spacing: 4) {
                    Text("Total rides: \(totalRides)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("Rides with GPS: \(ridesWithGPS)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var routeMapView: some View {
        Map(position: $mapCameraPosition) {
            // Draw all routes with different colors based on recency
            ForEach(Array(filteredRides.enumerated()), id: \.element.id) { index, ride in
                if let coordinates = ride.routeCoordinates, !coordinates.isEmpty {
                    // Downsample coordinates to reduce memory usage
                    let downsampledCoords = downsampleCoordinates(coordinates, maxPoints: 100)
                    MapPolyline(coordinates: downsampledCoords.map { $0.clCoordinate })
                        .stroke(colorForRide(at: index), lineWidth: 2.5)
                }
            }

            // Add markers for start points only (reduce annotation count)
            ForEach(filteredRides) { ride in
                if let coordinates = ride.routeCoordinates,
                   let startCoord = coordinates.first {
                    Annotation("", coordinate: startCoord.clCoordinate) {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                            .overlay(
                                Circle()
                                    .stroke(.white, lineWidth: 2)
                            )
                    }
                }
            }
        }
        .mapStyle(.standard)
    }

    // Downsample coordinates to reduce memory usage
    private func downsampleCoordinates(_ coordinates: [Ride.Coordinate], maxPoints: Int) -> [Ride.Coordinate] {
        guard coordinates.count > maxPoints else { return coordinates }

        let step = coordinates.count / maxPoints
        var result: [Ride.Coordinate] = []

        for i in stride(from: 0, to: coordinates.count, by: step) {
            result.append(coordinates[i])
        }

        // Always include the last point
        if let last = coordinates.last {
            result.append(last)
        }

        return result
    }

    private func colorForRide(at index: Int) -> Color {
        // Create gradient from older (lighter) to newer (darker) rides
        let ratio = Double(index) / Double(max(filteredRides.count - 1, 1))

        // Color gradient from light blue (old) to bright cyan (new)
        return Color(
            red: 0.0 + (0.0 * ratio),
            green: 0.5 + (0.5 * ratio),
            blue: 1.0
        ).opacity(0.4 + (0.4 * ratio))
    }
}

struct RouteHistoryMapView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            RouteHistoryMapView()
                .environmentObject(RideHistory())
        }
    }
}
