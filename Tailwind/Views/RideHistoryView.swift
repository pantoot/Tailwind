import SwiftUI

struct RideHistoryView: View {
    @EnvironmentObject var rideHistory: RideHistory
    @EnvironmentObject var healthKitService: HealthKitService
    @Environment(\.dismiss) var dismiss
    @State private var selectedRide: Ride?
    @State private var showingFixAlert = false
    @State private var showingResultAlert = false
    @State private var fixResultMessage = ""
    @State private var showingDatePicker = false
    @State private var selectedFixDate = Date()
    @State private var isFixingCalories = false
    @State private var expandedMonths: Set<String> = []

    var body: some View {
        NavigationView {
            ZStack {
                if isFixingCalories {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Fixing calories and updating Apple Health...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.3))
                } else if rideHistory.rides.isEmpty {
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
                } else {
                    List {
                        // Chart navigation
                        Section(header: Text("Analytics")) {
                            NavigationLink(destination: PerformanceTrendsView()) {
                                HStack {
                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                        .foregroundColor(.blue)
                                        .frame(width: 30)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Performance Trends")
                                            .font(.headline)
                                        Text("View your progress over time")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }

                            NavigationLink(destination: PeakPerformanceView()) {
                                HStack {
                                    Image(systemName: "bolt.fill")
                                        .foregroundColor(.orange)
                                        .frame(width: 30)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Peak Performance")
                                            .font(.headline)
                                        Text("Best efforts and efficiency")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                        }

                        // Summary stats
                        Section(header: Text("Summary")) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Total Rides")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Text("\(rideHistory.totalRides)")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                }
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text("Total Distance")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Text(String(format: "%.1f mi", rideHistory.totalDistance))
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                }
                            }

                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Total Time")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Text(formatDuration(rideHistory.totalDuration))
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                }
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text("Total Calories")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Text(String(format: "%.0f cal", rideHistory.totalCalories))
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                }
                            }
                        }

                        // Rides list grouped by month
                        ForEach(groupedRides.keys.sorted(by: >), id: \.self) { monthKey in
                            Section(header: monthHeader(for: monthKey)) {
                                if expandedMonths.contains(monthKey) || isCurrentMonth(monthKey) {
                                    ForEach(sortedRidesForMonth(monthKey)) { ride in
                                        Button(action: {
                                            selectedRide = ride
                                        }) {
                                            RideRowView(ride: ride)
                                        }
                                    }
                                    .onDelete { offsets in
                                        deleteRidesInMonth(monthKey: monthKey, offsets: offsets)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Ride History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                if !rideHistory.rides.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack(spacing: 12) {
                            // Fix calories button (hidden utility)
                            Button(action: {
                                showingDatePicker = true
                            }) {
                                Image(systemName: "wrench.and.screwdriver")
                                    .foregroundColor(.orange)
                            }

                            EditButton()
                        }
                    }
                }
            }
            .sheet(item: $selectedRide) { ride in
                RideDetailView(ride: ride)
            }
            .sheet(isPresented: $showingDatePicker) {
                DatePickerSheet(
                    selectedDate: $selectedFixDate,
                    onContinue: {
                        showingDatePicker = false
                        showingFixAlert = true
                    },
                    onCancel: {
                        showingDatePicker = false
                    }
                )
            }
            .alert("Fix Calories?", isPresented: $showingFixAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Fix Now") {
                    fixCaloriesForSelectedDate()
                }
            } message: {
                Text(alertMessage)
            }
            .alert("Calorie Fix Results", isPresented: $showingResultAlert) {
                Button("OK") { }
            } message: {
                Text(fixResultMessage)
            }
        }
    }

    private var alertMessage: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "This will recalculate calories for rides on \(formatter.string(from: selectedFixDate)) using the correct formula and update them in Apple Health."
    }

    private func fixCaloriesForSelectedDate() {
        isFixingCalories = true
        Task {
            let userProfile = UserProfile.load()
            fixResultMessage = await rideHistory.fixCalories(
                for: selectedFixDate,
                userProfile: userProfile,
                healthKitService: healthKitService
            )
            await MainActor.run {
                isFixingCalories = false
                showingResultAlert = true
            }
        }
    }

    // Group rides by month (YYYY-MM format)
    private var groupedRides: [String: [Ride]] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"

        return Dictionary(grouping: rideHistory.rides) { ride in
            formatter.string(from: ride.date)
        }
    }

    // Check if month key is current month
    private func isCurrentMonth(_ monthKey: String) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return monthKey == formatter.string(from: Date())
    }

    // Get rides for a month sorted in reverse chronological order (most recent first)
    private func sortedRidesForMonth(_ monthKey: String) -> [Ride] {
        return (groupedRides[monthKey] ?? []).sorted { $0.date > $1.date }
    }

    // Create header for month section
    private func monthHeader(for monthKey: String) -> some View {
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
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            )
        }

        return AnyView(Text("Unknown"))
    }

    // Delete rides within a specific month
    private func deleteRidesInMonth(monthKey: String, offsets: IndexSet) {
        guard let monthRides = groupedRides[monthKey] else { return }

        // Get the ride IDs to delete
        let ridesToDelete = offsets.map { monthRides[$0] }

        // Delete from main rides array
        for ride in ridesToDelete {
            rideHistory.deleteRide(ride)
        }
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

struct RideRowView: View {
    let ride: Ride

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(ride.formattedDate)
                    .font(.headline)
                    .foregroundColor(.primary)

                HStack(spacing: 12) {
                    Label(ride.formattedDistance, systemImage: "map")
                        .font(.caption)
                    Label(ride.formattedDuration, systemImage: "clock")
                        .font(.caption)
                    Label(ride.formattedCalories, systemImage: "flame")
                        .font(.caption)
                }
                .foregroundColor(.gray)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(ride.formattedAvgSpeed)
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("avg")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Date Picker Sheet
struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    let onContinue: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Select Date to Fix")
                    .font(.headline)

                DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()

                Button(action: onContinue) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding()
            .navigationTitle("Fix Calories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
    }
}
