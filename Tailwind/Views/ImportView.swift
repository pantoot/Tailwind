import SwiftUI
import UniformTypeIdentifiers
import HealthKit
import Charts

/// Main training dashboard view - mPaceline-style interface
struct ImportView: View {
    @EnvironmentObject var fitImportService: FITImportService
    @EnvironmentObject var rideHistory: RideHistory
    @EnvironmentObject var healthKitService: HealthKitService
    @EnvironmentObject var trainingLoadManager: TrainingLoadManager

    @State private var showingFilePicker = false
    @State private var showingSummary = false
    @State private var importedRide: Ride?
    @State private var showingError = false
    @State private var errorMessage = ""

    private var currentMetrics: PerformanceMetrics {
        trainingLoadManager.calculateCurrentMetrics()
    }

    private var weeklySummary: (weekTSS: Double, weekAverage: Double) {
        trainingLoadManager.getWeeklySummary()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Form Status Card - prominent display
                    formStatusCard

                    // Training Metrics Row
                    trainingMetricsRow

                    // Form Chart (last 30 days)
                    if !trainingLoadManager.dailyLoads.isEmpty {
                        formChartSection
                    }

                    // Weekly Summary
                    weeklySummaryCard

                    // Import FIT Button
                    importButton

                    // Recent Rides
                    if !rideHistory.rides.isEmpty {
                        recentRidesSection
                    }

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Tailwind")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gear")
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [UTType(filenameExtension: "fit") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .sheet(isPresented: $showingSummary) {
            if let ride = importedRide {
                ImportSummaryView(ride: ride, workoutData: nil)
                    .environmentObject(trainingLoadManager)
            }
        }
        .alert("Import Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onOpenURL { url in
            if url.pathExtension.lowercased() == "fit" {
                Task {
                    await importFile(from: url)
                }
            }
        }
    }

    // MARK: - Form Status Card

    private var formStatusCard: some View {
        VStack(spacing: 12) {
            // Status indicator
            HStack {
                Circle()
                    .fill(currentMetrics.formStatus.color)
                    .frame(width: 16, height: 16)

                Text(currentMetrics.formStatus.rawValue)
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                // TSB value
                Text(String(format: "%+.0f", currentMetrics.tsb))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(currentMetrics.tsb >= 0 ? .green : .orange)
            }

            // Description
            Text(currentMetrics.formStatus.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            // Recommendation
            HStack {
                Image(systemName: recommendationIcon)
                    .foregroundStyle(currentMetrics.formStatus.color)
                Text(currentMetrics.formStatus.recommendation)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    private var recommendationIcon: String {
        switch currentMetrics.formStatus {
        case .fresh, .rested:
            return "bolt.fill"
        case .optimal:
            return "checkmark.circle.fill"
        case .productive:
            return "exclamationmark.triangle.fill"
        case .overreaching:
            return "bed.double.fill"
        }
    }

    // MARK: - Training Metrics Row

    private var trainingMetricsRow: some View {
        HStack(spacing: 12) {
            DashboardMetricCard(
                title: "Fitness",
                subtitle: "CTL",
                value: String(format: "%.0f", currentMetrics.ctl),
                color: .blue
            )

            DashboardMetricCard(
                title: "Fatigue",
                subtitle: "ATL",
                value: String(format: "%.0f", currentMetrics.atl),
                color: .orange
            )

            DashboardMetricCard(
                title: "Form",
                subtitle: "TSB",
                value: String(format: "%+.0f", currentMetrics.tsb),
                color: currentMetrics.tsb >= 0 ? .green : .red
            )
        }
    }

    // MARK: - Form Chart Section

    private var formChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Training Load")
                .font(.headline)

            FormChart(data: trainingLoadManager.getHistoricalMetrics(days: 30))
                .frame(height: 180)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    // MARK: - Weekly Summary

    private var weeklySummaryCard: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("This Week")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(String(format: "%.0f", weeklySummary.weekTSS))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    Text("TSS")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("Daily Avg")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(String(format: "%.0f", weeklySummary.weekAverage))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    Text("TSS")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    // MARK: - Import Button

    private var importButton: some View {
        Button(action: { showingFilePicker = true }) {
            HStack {
                if fitImportService.isImporting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "square.and.arrow.down.fill")
                }
                Text(fitImportService.isImporting ? "Importing..." : "Import FIT File")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundStyle(.white)
            .cornerRadius(12)
        }
        .disabled(fitImportService.isImporting)
    }

    // MARK: - Recent Rides Section

    private var recentRidesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Rides")
                    .font(.headline)
                Spacer()
                NavigationLink("See All") {
                    RideHistoryView()
                }
                .font(.subheadline)
            }

            VStack(spacing: 8) {
                ForEach(rideHistory.rides.prefix(5)) { ride in
                    NavigationLink(destination: RideDetailView(ride: ride)) {
                        RideRow(ride: ride)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Helpers

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task {
                await importFile(from: url)
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func importFile(from url: URL) async {
        do {
            let ride = try await fitImportService.importFITFile(from: url)

            if let tss = ride.hrTSS {
                trainingLoadManager.addTSS(date: ride.date, tss: tss)
            }

            await MainActor.run {
                importedRide = ride
                showingSummary = true
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
}

// MARK: - Supporting Views

struct DashboardMetricCard: View {
    let title: String
    let subtitle: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(color)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct RideRow: View {
    let ride: Ride

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(ride.formattedDate)
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 12) {
                    Label(ride.formattedDistance, systemImage: "road.lanes")
                    Label(ride.formattedDuration, systemImage: "clock")
                    if let tss = ride.hrTSS {
                        Label(String(format: "%.0f", tss), systemImage: "flame.fill")
                            .foregroundStyle(.orange)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if ride.averageHeartRate > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                    Text("\(Int(ride.averageHeartRate))")
                }
                .font(.subheadline)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Form Chart

struct FormChart: View {
    let data: [(date: Date, ctl: Double, atl: Double, tsb: Double)]

    var body: some View {
        Chart {
            // TSB area (form)
            ForEach(data, id: \.date) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("TSB", point.tsb)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [point.tsb >= 0 ? .green.opacity(0.3) : .red.opacity(0.3), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }

            // CTL line (fitness)
            ForEach(data, id: \.date) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("CTL", point.ctl)
                )
                .foregroundStyle(.blue)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }

            // ATL line (fatigue)
            ForEach(data, id: \.date) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("ATL", point.atl)
                )
                .foregroundStyle(.orange)
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
            }

            // Zero line for TSB
            RuleMark(y: .value("Zero", 0))
                .foregroundStyle(.gray.opacity(0.3))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 7)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
            }
        }
        .chartLegend(position: .bottom, spacing: 20) {
            HStack(spacing: 16) {
                Label("Fitness", systemImage: "line.diagonal")
                    .foregroundStyle(.blue)
                Label("Fatigue", systemImage: "line.diagonal")
                    .foregroundStyle(.orange)
                Label("Form", systemImage: "square.fill")
                    .foregroundStyle(.green)
            }
            .font(.caption)
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var healthKitService: HealthKitService
    @EnvironmentObject var rideHistory: RideHistory
    @EnvironmentObject var trainingLoadManager: TrainingLoadManager
    @EnvironmentObject var weightLogManager: WeightLogManager
    @EnvironmentObject var creatineSettingsManager: CreatineSettingsManager

    @State private var birthday: Date
    @State private var weight: Double
    @State private var gender: UserProfile.Gender
    @State private var lactateThresholdHR: String
    @State private var maxHeartRate: String
    @State private var showingSaveConfirmation = false

    // Apple Health import
    @State private var showingHealthImport = false
    @State private var isImportingFromHealth = false
    @State private var healthImportProgress = ""

    // Duplicate cleanup
    @State private var showingDuplicateResult = false
    @State private var duplicatesRemoved = 0

    // Clear all rides
    @State private var showingClearAllConfirmation = false

    init() {
        let profile = UserProfile.load()
        _birthday = State(initialValue: profile.birthday)
        _weight = State(initialValue: profile.weight)
        _gender = State(initialValue: profile.gender)
        _lactateThresholdHR = State(initialValue: profile.lactateThresholdHR.map { String($0) } ?? "")
        _maxHeartRate = State(initialValue: profile.maxHeartRate.map { String($0) } ?? "")
    }

    var body: some View {
        Form {
            Section("Profile") {
                DatePicker("Birthday", selection: $birthday, displayedComponents: .date)
                    .datePickerStyle(.compact)

                HStack {
                    Text("Age")
                    Spacer()
                    Text("\(calculatedAge) years")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Weight")
                    Spacer()
                    TextField("Weight", value: $weight, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                    Text("lbs")
                        .foregroundStyle(.secondary)
                }

                Picker("Gender", selection: $gender) {
                    ForEach(UserProfile.Gender.allCases, id: \.self) { gender in
                        Text(gender.rawValue).tag(gender)
                    }
                }
            }

            Section(header: Text("Training Zones"), footer: Text("LTHR is required for TSS and zone calculations. Do a 30-min time trial and use your average HR for the last 20 minutes.")) {
                HStack {
                    Text("LTHR (Threshold)")
                    Spacer()
                    TextField("LTHR", text: $lactateThresholdHR)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                    Text("bpm")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Max Heart Rate")
                    Spacer()
                    TextField("Max HR", text: $maxHeartRate)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                    Text("bpm")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Estimated Max HR")
                    Spacer()
                    Text("\(220 - calculatedAge) bpm")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button(action: saveProfile) {
                    HStack {
                        Spacer()
                        Text("Save Profile")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
            }

            Section("Data Import") {
                Button(action: { showingHealthImport = true }) {
                    HStack {
                        Label("Import from Apple Health", systemImage: "heart.fill")
                            .foregroundStyle(.primary)
                        Spacer()
                        if isImportingFromHealth {
                            ProgressView()
                        } else {
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .disabled(isImportingFromHealth)

                if !healthImportProgress.isEmpty {
                    Text(healthImportProgress)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button(action: cleanUpDuplicates) {
                    HStack {
                        Label("Clean Up Duplicates", systemImage: "doc.on.doc")
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("\(rideHistory.rides.count) rides")
                            .foregroundStyle(.secondary)
                    }
                }

                Button(role: .destructive) {
                    showingClearAllConfirmation = true
                } label: {
                    HStack {
                        Label("Clear All Rides", systemImage: "trash")
                        Spacer()
                        Text("Re-import with new settings")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section(header: Text("Creatine Focus"), footer: Text("Set your creatine start date to see a marker on charts. Match threshold defines the minimum watts for a 'match burned'.")) {
                DatePicker("Creatine Start Date",
                           selection: Binding(
                            get: { creatineSettingsManager.settings.creatineStartDate ?? Date() },
                            set: { creatineSettingsManager.settings.creatineStartDate = $0; creatineSettingsManager.save() }
                           ),
                           displayedComponents: .date)

                HStack {
                    Text("Match Threshold")
                    Spacer()
                    TextField("Watts", value: $creatineSettingsManager.settings.matchThresholdWatts, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                        .onChange(of: creatineSettingsManager.settings.matchThresholdWatts) { _, _ in
                            creatineSettingsManager.save()
                        }
                    Text("W")
                        .foregroundStyle(.secondary)
                }

                NavigationLink {
                    WeightLogView(weightLogManager: weightLogManager)
                } label: {
                    HStack {
                        Text("Weight Log")
                        Spacer()
                        if let w = weightLogManager.latestWeight() {
                            Text(String(format: "%.1f lbs", w))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Apple Health") {
                HStack {
                    Label("Apple Health", systemImage: "heart.fill")
                    Spacer()
                    if healthKitService.isAuthorized {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button("Connect") {
                            Task {
                                try? await healthKitService.requestAuthorization()
                            }
                        }
                    }
                }
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("2.0")
                        .foregroundStyle(.secondary)
                }

                Link(destination: URL(string: "https://github.com/pantoot/Tailwind")!) {
                    HStack {
                        Text("GitHub")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Text("Tailwind imports FIT files from Magene and other cycling computers directly into Apple Health, preserving all heart rate data.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .alert("Profile Saved", isPresented: $showingSaveConfirmation) {
            Button("OK") { }
        } message: {
            Text("Your profile has been saved. TSS and zone calculations will now work on future imports.")
        }
        .confirmationDialog("Import from Apple Health", isPresented: $showingHealthImport) {
            Button("Last 30 Days") {
                Task { await importFromHealth(days: 30) }
            }
            Button("Last 60 Days") {
                Task { await importFromHealth(days: 60) }
            }
            Button("Last 90 Days") {
                Task { await importFromHealth(days: 90) }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Import cycling workouts from Apple Health to calculate TSS and training load history.")
        }
        .alert("Duplicates Cleaned", isPresented: $showingDuplicateResult) {
            Button("OK") { }
        } message: {
            Text(duplicatesRemoved > 0
                ? "Removed \(duplicatesRemoved) duplicate rides. \(rideHistory.rides.count) rides remaining."
                : "No duplicate rides found.")
        }
        .alert("Clear All Rides?", isPresented: $showingClearAllConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                rideHistory.clearAllRides()
                trainingLoadManager.clearAll()
            }
        } message: {
            Text("This will delete all \(rideHistory.rides.count) rides. You can re-import from Apple Health with your updated profile settings (LTHR, etc.) to recalculate TSS.")
        }
    }

    private func cleanUpDuplicates() {
        duplicatesRemoved = rideHistory.removeDuplicates()
        showingDuplicateResult = true
    }

    private var calculatedAge: Int {
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: birthday, to: Date())
        return ageComponents.year ?? 0
    }

    private func saveProfile() {
        let profile = UserProfile(
            birthday: birthday,
            weight: weight,
            gender: gender,
            heightInches: nil,
            lactateThresholdHR: Int(lactateThresholdHR),
            maxHeartRate: Int(maxHeartRate)
        )
        profile.save()
        showingSaveConfirmation = true
    }

    private func importFromHealth(days: Int) async {
        await MainActor.run {
            isImportingFromHealth = true
            healthImportProgress = "Requesting HealthKit access..."
        }

        do {
            try await healthKitService.requestAuthorization()

            await MainActor.run {
                healthImportProgress = "Fetching workouts..."
            }

            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate) ?? endDate

            print("📱 Fetching cycling workouts from \(startDate) to \(endDate)")
            let workouts = try await healthKitService.fetchCyclingWorkouts(from: startDate, to: endDate)
            print("📱 Found \(workouts.count) cycling workouts")

            await MainActor.run {
                healthImportProgress = "Found \(workouts.count) workouts..."
            }

            if workouts.isEmpty {
                await MainActor.run {
                    isImportingFromHealth = false
                    healthImportProgress = "No cycling workouts found in the last \(days) days."
                }
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                await MainActor.run { healthImportProgress = "" }
                return
            }

            var imported = 0
            var skipped = 0
            var errors = 0

            for workout in workouts {
                let isDuplicate = rideHistory.rides.contains { ride in
                    ridesOverlap(existingRide: ride, newWorkout: workout)
                }

                if isDuplicate {
                    skipped += 1
                    continue
                }

                do {
                    let ride = try await healthKitService.importWorkout(workout)

                    await MainActor.run {
                        rideHistory.saveRide(ride)

                        if let tss = ride.hrTSS {
                            trainingLoadManager.addTSS(date: ride.date, tss: tss)
                        }

                        imported += 1
                        healthImportProgress = "Imported \(imported) of \(workouts.count - skipped)..."
                    }
                } catch {
                    print("⚠️ Failed to import workout from \(workout.startDate): \(error.localizedDescription)")
                    errors += 1
                }
            }

            await MainActor.run {
                isImportingFromHealth = false
                var message = "Done! Imported \(imported) rides"
                if skipped > 0 {
                    message += ", skipped \(skipped) duplicates"
                }
                if errors > 0 {
                    message += ", \(errors) failed"
                }
                healthImportProgress = message + "."

                rideHistory.sortByDate()
            }

            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                healthImportProgress = ""
            }

        } catch {
            print("❌ Health import error: \(error)")
            await MainActor.run {
                isImportingFromHealth = false
                healthImportProgress = "Error: \(error.localizedDescription)"
            }
        }
    }

    private func ridesOverlap(existingRide: Ride, newWorkout: HKWorkout) -> Bool {
        let existingStart = existingRide.date
        let existingEnd = existingStart.addingTimeInterval(existingRide.duration)

        let newStart = newWorkout.startDate
        let newEnd = newWorkout.endDate

        let overlapStart = max(existingStart, newStart)
        let overlapEnd = min(existingEnd, newEnd)

        if overlapStart < overlapEnd {
            let overlapDuration = overlapEnd.timeIntervalSince(overlapStart)
            let shorterDuration = min(existingRide.duration, newWorkout.duration)

            if overlapDuration / shorterDuration > 0.5 {
                return true
            }
        }

        let startDiff = abs(existingStart.timeIntervalSince(newStart))
        if startDiff < 600 {
            let durationRatio = min(existingRide.duration, newWorkout.duration) /
                               max(existingRide.duration, newWorkout.duration)
            if durationRatio > 0.7 {
                return true
            }
        }

        return false
    }
}

#Preview {
    ImportView()
        .environmentObject(FITImportService(
            healthKitService: HealthKitService(),
            rideHistory: RideHistory()
        ))
        .environmentObject(RideHistory())
        .environmentObject(HealthKitService())
        .environmentObject(TrainingLoadManager())
        .environmentObject(WeightLogManager())
        .environmentObject(CreatineSettingsManager())
}
