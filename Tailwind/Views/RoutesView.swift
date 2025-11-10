import SwiftUI

struct RoutesView: View {
    @EnvironmentObject var routeMatchingService: RouteMatchingService
    @Environment(\.dismiss) var dismiss
    @State private var editingRoute: RouteSegment?

    var body: some View {
        NavigationView {
            List {
                if routeMatchingService.savedRoutes.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "map")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("No Routes Yet")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("Your routes will appear here after a few rides")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    ForEach(routeMatchingService.savedRoutes) { route in
                        Button(action: {
                            editingRoute = route
                        }) {
                            RouteRowView(route: route)
                        }
                    }
                    .onDelete(perform: deleteRoutes)
                }
            }
            .navigationTitle("My Routes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
            .sheet(item: $editingRoute) { route in
                RouteDetailView(route: route)
                    .environmentObject(routeMatchingService)
            }
        }
    }

    private func deleteRoutes(at offsets: IndexSet) {
        for index in offsets {
            let route = routeMatchingService.savedRoutes[index]
            routeMatchingService.deleteRoute(route.id)
        }
    }
}

struct RouteRowView: View {
    let route: RouteSegment

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(route.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text("\(route.rideCount) rides")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Distance")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(String(format: "%.1f mi", route.distance))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }

                Divider()
                    .frame(height: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Best Time")
                        .font(.caption)
                        .foregroundColor(.gray)
                    if let bestTime = route.bestTime {
                        Text(formatDuration(bestTime))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    } else {
                        Text("--")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }

                Divider()
                    .frame(height: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Avg Speed")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(String(format: "%.1f mph", route.averageSpeed))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }

            if let lastRide = route.lastRideDate {
                Text("Last ride: \(formatDate(lastRide))")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        } else {
            return String(format: "%dm %02ds", minutes, seconds)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct RouteDetailView: View {
    @EnvironmentObject var routeMatchingService: RouteMatchingService
    @Environment(\.dismiss) var dismiss
    let route: RouteSegment
    @State private var editedName: String

    init(route: RouteSegment) {
        self.route = route
        _editedName = State(initialValue: route.name)
    }

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Route Info")) {
                    HStack {
                        Text("Name")
                        Spacer()
                        TextField("Route Name", text: $editedName)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("Distance")
                        Spacer()
                        Text(String(format: "%.2f mi", route.distance))
                            .foregroundColor(.gray)
                    }

                    HStack {
                        Text("Total Rides")
                        Spacer()
                        Text("\(route.rideCount)")
                            .foregroundColor(.gray)
                    }
                }

                Section(header: Text("Performance Stats")) {
                    if let bestTime = route.bestTime {
                        HStack {
                            Text("Best Time")
                            Spacer()
                            Text(formatDuration(bestTime))
                                .foregroundColor(.green)
                                .fontWeight(.semibold)
                        }
                    }

                    HStack {
                        Text("Average Time")
                        Spacer()
                        Text(formatDuration(route.averageTime))
                            .foregroundColor(.gray)
                    }

                    if let bestSpeed = route.bestSpeed {
                        HStack {
                            Text("Best Speed")
                            Spacer()
                            Text(String(format: "%.1f mph", bestSpeed))
                                .foregroundColor(.green)
                                .fontWeight(.semibold)
                        }
                    }

                    HStack {
                        Text("Average Speed")
                        Spacer()
                        Text(String(format: "%.1f mph", route.averageSpeed))
                            .foregroundColor(.gray)
                    }
                }

                Section(header: Text("Recent Rides")) {
                    ForEach(Array(route.allRides.prefix(10))) { rideStats in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(formatDate(rideStats.date))
                                    .font(.subheadline)
                                Spacer()
                                Text(formatDuration(rideStats.duration))
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                            }
                            HStack(spacing: 12) {
                                Text(String(format: "%.1f mph", rideStats.averageSpeed))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                if rideStats.averageHeartRate > 0 {
                                    Text("\(rideStats.averageHeartRate) bpm")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                Text(String(format: "%.0f cal", rideStats.calories))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("Route Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        if editedName != route.name {
                            routeMatchingService.renameRoute(route.id, newName: editedName)
                        }
                        dismiss()
                    }
                }
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
