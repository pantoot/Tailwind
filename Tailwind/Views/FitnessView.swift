import SwiftUI
import HealthKit
#if canImport(Charts)
import Charts
#endif

struct FitnessView: View {
    @EnvironmentObject var trainingLoadManager: TrainingLoadManager
    @EnvironmentObject var healthKitService: HealthKitService
    @EnvironmentObject var rideHistory: RideHistory
    @Environment(\.dismiss) var dismiss
    @State private var selectedTimeRange: TimeRange = .month
    @State private var showingImportSheet = false
    @State private var importedWorkouts: [HKWorkout] = []
    @State private var isImporting = false
    @State private var importError: String?

    enum TimeRange: String, CaseIterable {
        case week = "7 Days"
        case twoWeeks = "14 Days"
        case month = "30 Days"
        case twoMonths = "60 Days"

        var days: Int {
            switch self {
            case .week: return 7
            case .twoWeeks: return 14
            case .month: return 30
            case .twoMonths: return 60
            }
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Current Status Cards
                    currentStatusSection

                    // Time Range Picker
                    Picker("Time Range", selection: $selectedTimeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Charts Section
                    chartsSection

                    // Weekly Summary
                    weeklySummarySection

                    // Interpretation Guide
                    interpretationSection

                    // Recent Rides TSS History
                    recentRidesSection
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Training Load")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingImportSheet = true }) {
                        Label("Import", systemImage: "square.and.arrow.down")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingImportSheet) {
                importWorkoutsSheet
            }
        }
    }

    private var currentStatusSection: some View {
        let metrics = trainingLoadManager.calculateCurrentMetrics()

        return VStack(spacing: 12) {
            // Form Status Banner
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(metrics.formStatus.rawValue)
                        .font(.title2.bold())
                        .foregroundColor(metrics.formStatus.color)

                    Text(metrics.formStatus.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(metrics.formStatus.color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(metrics.formStatus.color, lineWidth: 2)
            )
            .padding(.horizontal)

            // Metrics Cards
            HStack(spacing: 12) {
                MetricCard(
                    title: "Fitness",
                    subtitle: "CTL",
                    value: String(format: "%.1f", metrics.ctl),
                    trend: metrics.fitnessLevel,
                    color: .blue
                )

                MetricCard(
                    title: "Fatigue",
                    subtitle: "ATL",
                    value: String(format: "%.1f", metrics.atl),
                    trend: metrics.atl > 60 ? "High" : metrics.atl > 30 ? "Moderate" : "Low",
                    color: .orange
                )

                MetricCard(
                    title: "Form",
                    subtitle: "TSB",
                    value: String(format: "%.1f", metrics.tsb),
                    trend: metrics.tsb > 0 ? "Fresh" : "Fatigued",
                    color: metrics.tsb > 0 ? .green : .red
                )
            }
            .padding(.horizontal)
        }
    }

    private var chartsSection: some View {
        let history = trainingLoadManager.getHistoricalMetrics(days: selectedTimeRange.days)

        return VStack(spacing: 16) {
            // Fitness & Fatigue Chart (CTL/ATL)
            VStack(alignment: .leading, spacing: 8) {
                Text("Fitness & Fatigue")
                    .font(.headline)
                    .padding(.horizontal)

                if #available(iOS 16.0, *) {
                    Chart {
                        ForEach(history, id: \.date) { point in
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("Fitness", point.ctl)
                            )
                            .foregroundStyle(Color.blue)
                            .interpolationMethod(.catmullRom)

                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("Fatigue", point.atl)
                            )
                            .foregroundStyle(Color.orange)
                            .interpolationMethod(.catmullRom)
                        }
                    }
                    .chartYAxisLabel("Training Load")
                    .chartLegend(position: .bottom)
                    .frame(height: 200)
                    .padding()
                } else {
                    Text("Charts require iOS 16+")
                        .foregroundColor(.secondary)
                        .frame(height: 200)
                        .frame(maxWidth: .infinity)
                }
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            // Form Chart (TSB)
            VStack(alignment: .leading, spacing: 8) {
                Text("Form (Freshness)")
                    .font(.headline)
                    .padding(.horizontal)

                if #available(iOS 16.0, *) {
                    Chart {
                        ForEach(history, id: \.date) { point in
                            // Zero reference line
                            RuleMark(y: .value("Zero", 0))
                                .foregroundStyle(Color.gray.opacity(0.3))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))

                            // TSB area chart
                            AreaMark(
                                x: .value("Date", point.date),
                                y: .value("Form", point.tsb)
                            )
                            .foregroundStyle(
                                point.tsb >= 0
                                    ? Color.green.opacity(0.3)
                                    : Color.red.opacity(0.3)
                            )

                            // TSB line
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("Form", point.tsb)
                            )
                            .foregroundStyle(
                                point.tsb >= 0
                                    ? Color.green
                                    : Color.red
                            )
                            .interpolationMethod(.catmullRom)
                        }
                    }
                    .chartYAxisLabel("Form")
                    .frame(height: 150)
                    .padding()
                } else {
                    Text("Charts require iOS 16+")
                        .foregroundColor(.secondary)
                        .frame(height: 150)
                        .frame(maxWidth: .infinity)
                }

                // Form interpretation
                HStack(spacing: 8) {
                    Label("Positive = Fresh", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                    Divider()
                        .frame(height: 12)
                    Label("Negative = Tired", systemImage: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
        }
    }

    private var weeklySummarySection: some View {
        let summary = trainingLoadManager.getWeeklySummary()

        return VStack(alignment: .leading, spacing: 12) {
            Text("This Week")
                .font(.headline)

            HStack(spacing: 16) {
                VStack(alignment: .leading) {
                    Text("Total TSS")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.0f", summary.weekTSS))
                        .font(.title2.bold())
                }

                Divider()

                VStack(alignment: .leading) {
                    Text("Daily Average")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f", summary.weekAverage))
                        .font(.title2.bold())
                }

                Spacer()
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private var interpretationSection: some View {
        let metrics = trainingLoadManager.calculateCurrentMetrics()

        return VStack(alignment: .leading, spacing: 16) {
            Text("What This Means")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                InfoRow(
                    icon: "brain.head.profile",
                    title: "Your Recommendation",
                    description: metrics.formStatus.recommendation,
                    color: metrics.formStatus.color
                )

                Divider()

                InfoRow(
                    icon: "heart.fill",
                    title: "Fitness (CTL)",
                    description: "Long-term training load (42-day average). Higher is better, but build gradually.",
                    color: .blue
                )

                Divider()

                InfoRow(
                    icon: "bolt.fill",
                    title: "Fatigue (ATL)",
                    description: "Recent training stress (7-day average). High fatigue after hard training is normal.",
                    color: .orange
                )

                Divider()

                InfoRow(
                    icon: "figure.run",
                    title: "Form (TSB)",
                    description: "Fitness minus Fatigue. Positive = fresh, negative = tired. Train hard at -10 to -30.",
                    color: .green
                )
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Recent Rides Section

    private var recentRidesSection: some View {
        // Get rides with TSS from the last 30 days
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let ridesWithTSS = Array(rideHistory.rides
            .filter { $0.date >= thirtyDaysAgo && $0.hrTSS != nil }
            .sorted { $0.date > $1.date } // Most recent first
            .prefix(20)) // Show last 20 rides

        return VStack(alignment: .leading, spacing: 12) {
            Text("Recent Rides (TSS)")
                .font(.headline)
                .padding(.horizontal)

            if ridesWithTSS.isEmpty {
                HStack {
                    Image(systemName: "bicycle")
                        .font(.system(size: 24))
                        .foregroundColor(.gray)
                    Text("No rides with TSS data yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            } else {
                VStack(spacing: 1) {
                    ForEach(Array(ridesWithTSS.enumerated()), id: \.element.id) { index, ride in
                        RideTSSRow(ride: ride, isLast: index == ridesWithTSS.count - 1)
                    }
                }
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Import Workouts Sheet

    private var importWorkoutsSheet: some View {
        NavigationView {
            VStack {
                if isImporting {
                    ProgressView("Loading workouts...")
                        .padding()
                } else if let error = importError {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        Text("Error")
                            .font(.title2.bold())
                        Text(error)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Try Again") {
                            loadWorkouts()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else if importedWorkouts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "figure.outdoor.cycle")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("No cycling workouts found")
                            .font(.title3)
                        Text("Record a ride in the Apple Workouts app first")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        Section {
                            VStack(spacing: 12) {
                                Text("Found \(importedWorkouts.count) workout\(importedWorkouts.count == 1 ? "" : "s") from the last 60 days")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                if importedWorkouts.count > 1 {
                                    Button(action: importAllWorkouts) {
                                        Label("Import All (\(importedWorkouts.count))", systemImage: "square.and.arrow.down.on.square")
                                            .font(.headline)
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                            }
                            .padding(.vertical, 8)
                        }

                        ForEach(importedWorkouts, id: \.uuid) { workout in
                            Button(action: {
                                importWorkout(workout)
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(workout.startDate.formatted(date: .abbreviated, time: .shortened))
                                            .font(.headline)
                                        HStack {
                                            if let distance = workout.totalDistance {
                                                Text("\(distance.doubleValue(for: .mile()), specifier: "%.2f") mi")
                                            }

                                            // Get calories - handle iOS 18 deprecation
                                            if #available(iOS 18.0, *) {
                                                if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
                                                   let stat = workout.statistics(for: energyType),
                                                   let calories = stat.sumQuantity()?.doubleValue(for: .kilocalorie()) {
                                                    Text("• \(calories, specifier: "%.0f") cal")
                                                }
                                            } else {
                                                if let calories = workout.totalEnergyBurned {
                                                    Text("• \(calories.doubleValue(for: .kilocalorie()), specifier: "%.0f") cal")
                                                }
                                            }

                                            Text("• \(formatDuration(workout.duration))")
                                        }
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Import Workouts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        showingImportSheet = false
                    }
                }
            }
            .onAppear {
                loadWorkouts()
            }
        }
    }

    private func loadWorkouts() {
        isImporting = true
        importError = nil

        Task {
            do {
                // Request authorization if not already granted
                if !healthKitService.isAuthorized {
                    print("⚠️ HealthKit not authorized, requesting permission...")
                    try await healthKitService.requestAuthorization()

                    // Check if authorization was granted
                    if !healthKitService.isAuthorized {
                        throw HealthKitError.notAuthorized
                    }
                    print("✅ HealthKit authorization granted")
                }

                // Fetch workouts from last 60 days for proper training load baseline
                let endDate = Date()
                let startDate = Calendar.current.date(byAdding: .day, value: -60, to: endDate)!

                let workouts = try await healthKitService.fetchCyclingWorkouts(from: startDate, to: endDate)

                // Filter out already imported workouts (deduplication)
                let existingDates = Set(rideHistory.rides.map {
                    Calendar.current.startOfDay(for: $0.date)
                })

                let newWorkouts = workouts.filter { workout in
                    let workoutDay = Calendar.current.startOfDay(for: workout.startDate)
                    // Only include if we don't already have a ride on this day
                    return !existingDates.contains(workoutDay)
                }

                await MainActor.run {
                    importedWorkouts = newWorkouts
                    isImporting = false

                    if newWorkouts.isEmpty && !workouts.isEmpty {
                        print("ℹ️ All \(workouts.count) workouts already imported")
                    }
                }
            } catch {
                await MainActor.run {
                    importError = error.localizedDescription
                    isImporting = false
                }
            }
        }
    }

    private func importAllWorkouts() {
        Task {
            var successCount = 0
            var failCount = 0

            for workout in importedWorkouts {
                do {
                    let ride = try await healthKitService.importWorkout(workout)

                    await MainActor.run {
                        // Save to ride history
                        rideHistory.saveRide(ride)

                        // Add TSS to training load
                        if let tss = ride.hrTSS {
                            trainingLoadManager.addTSS(date: ride.date, tss: tss)
                        }
                    }

                    successCount += 1
                    print("✅ Imported \(successCount)/\(importedWorkouts.count): \(ride.distance) mi")
                } catch {
                    failCount += 1
                    print("❌ Failed to import workout: \(error.localizedDescription)")
                }
            }

            await MainActor.run {
                showingImportSheet = false
                print("🎉 Bulk import complete: \(successCount) succeeded, \(failCount) failed")
            }
        }
    }

    private func importWorkout(_ workout: HKWorkout) {
        Task {
            do {
                let ride = try await healthKitService.importWorkout(workout)

                await MainActor.run {
                    // Save to ride history
                    rideHistory.saveRide(ride)

                    // Add TSS to training load
                    if let tss = ride.hrTSS {
                        trainingLoadManager.addTSS(date: ride.date, tss: tss)
                    }

                    // Close sheet
                    showingImportSheet = false

                    print("✅ Imported and saved ride: \(ride.distance) mi")
                }
            } catch {
                await MainActor.run {
                    importError = "Failed to import workout: \(error.localizedDescription)"
                }
            }
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

struct MetricCard: View {
    let title: String
    let subtitle: String
    let value: String
    let trend: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(color)

            Text(title)
                .font(.caption.bold())
                .foregroundColor(.primary)

            Text(trend)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct RideTSSRow: View {
    let ride: Ride
    let isLast: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Date and time
                VStack(alignment: .leading, spacing: 2) {
                    Text(formattedDate)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Text(formattedTime)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Ride details
                HStack(spacing: 16) {
                    // Distance
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.1f", ride.distance))
                            .font(.subheadline.bold())
                        Text("mi")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    // Duration
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formattedDuration)
                            .font(.subheadline.bold())
                        Text("time")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    // TSS (highlighted)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.0f", ride.hrTSS ?? 0))
                            .font(.headline.bold())
                            .foregroundColor(tssColor)
                        Text("TSS")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(tssColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            if !isLast {
                Divider()
                    .padding(.leading, 12)
            }
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: ride.date)
    }

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: ride.date)
    }

    private var formattedDuration: String {
        let hours = Int(ride.duration) / 3600
        let minutes = (Int(ride.duration) % 3600) / 60

        if hours > 0 {
            return String(format: "%d:%02d", hours, minutes)
        } else {
            return String(format: "%d", minutes)
        }
    }

    private var tssColor: Color {
        guard let tss = ride.hrTSS else { return .gray }

        // Color code by intensity
        if tss < 50 {
            return .green // Easy
        } else if tss < 100 {
            return .blue // Moderate
        } else if tss < 150 {
            return .orange // Hard
        } else {
            return .red // Very hard
        }
    }
}
