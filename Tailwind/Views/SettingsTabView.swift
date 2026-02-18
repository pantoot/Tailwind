import SwiftUI
import HealthKit

struct SettingsTabView: View {
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
    @State private var ftpWatts: String
    @State private var showingSaveConfirmation = false

    // Duplicate cleanup
    @State private var showingDuplicateResult = false
    @State private var duplicatesRemoved = 0

    // Clear all rides
    @State private var showingClearAllConfirmation = false

    // Creatine reanalysis
    @State private var isReanalyzing = false
    @State private var reanalyzeProgress = ""

    // LTHR estimation
    @State private var isEstimatingLTHR = false
    @State private var lthrEstimate: HealthKitService.LTHREstimate?
    @State private var lthrProgress = ""
    @State private var showingLTHRResult = false

    init() {
        let profile = UserProfile.load()
        _birthday = State(initialValue: profile.birthday)
        _weight = State(initialValue: profile.weight)
        _gender = State(initialValue: profile.gender)
        _lactateThresholdHR = State(initialValue: profile.lactateThresholdHR.map { String($0) } ?? "")
        _maxHeartRate = State(initialValue: profile.maxHeartRate.map { String($0) } ?? "")
        _ftpWatts = State(initialValue: profile.ftp.map { String($0) } ?? "")
    }

    var body: some View {
        NavigationStack {
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

                Section(header: Text("Training Zones"), footer: Text("LTHR is required for TSS and zone calculations. FTP is used for power zone calculations and match detection (Zone 6 = 120%+ FTP).")) {
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
                        Text("FTP")
                        Spacer()
                        TextField("FTP", text: $ftpWatts)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("W")
                            .foregroundStyle(.secondary)
                    }

                    Button(action: {
                        Task {
                            try? await healthKitService.requestAuthorization()
                            if let ftp = await healthKitService.fetchFTP() {
                                ftpWatts = String(Int(ftp))
                            }
                        }
                    }) {
                        HStack {
                            Label("Fetch FTP from Apple Health", systemImage: "heart.fill")
                                .foregroundStyle(.primary)
                            Spacer()
                            if let ftp = Int(ftpWatts), ftp > 0 {
                                Text("\(ftp)W")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    HStack {
                        Text("Estimated Max HR")
                        Spacer()
                        Text("\(220 - calculatedAge) bpm")
                            .foregroundStyle(.secondary)
                    }

                    Button(action: {
                        Task { await runLTHREstimation() }
                    }) {
                        HStack {
                            Label("Estimate LTHR from Data", systemImage: "waveform.path.ecg")
                                .foregroundStyle(.primary)
                            Spacer()
                            if isEstimatingLTHR {
                                ProgressView()
                            } else {
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .disabled(isEstimatingLTHR)

                    if !lthrProgress.isEmpty {
                        Text(lthrProgress)
                            .font(.caption)
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

                Section(header: Text("Power"), footer: Text("Set your creatine start date to see a marker on charts. Match threshold defines the minimum watts for a 'match burned'.")) {
                    DatePicker("Creatine Start Date",
                               selection: Binding(
                                get: { creatineSettingsManager.settings.creatineStartDate ?? Date() },
                                set: { creatineSettingsManager.settings.creatineStartDate = $0; creatineSettingsManager.save() }
                               ),
                               displayedComponents: .date)

                    HStack {
                        Text("Match Threshold")
                        Spacer()
                        if let ftp = Int(ftpWatts), ftp > 0 {
                            Text("Z6: \(Int(Double(ftp) * 1.2))W")
                                .foregroundStyle(.secondary)
                        } else {
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
                    }

                    Button(action: { Task { await reanalyzeExistingRides() } }) {
                        HStack {
                            Label("Reanalyze Power Data", systemImage: "bolt.trianglebadge.exclamationmark.fill")
                                .foregroundStyle(.primary)
                            Spacer()
                            if isReanalyzing {
                                ProgressView()
                            } else {
                                let count = rideHistory.rides.filter { $0.creatineMetrics == nil }.count
                                Text("\(count) rides")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .disabled(isReanalyzing)

                    if !reanalyzeProgress.isEmpty {
                        Text(reanalyzeProgress)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Weight") {
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

                Section("Data") {
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
            .sheet(isPresented: $showingLTHRResult) {
                LTHRResultView(
                    estimate: lthrEstimate,
                    currentLTHR: Int(lactateThresholdHR),
                    onApply: { newLTHR in
                        lactateThresholdHR = String(newLTHR)
                        saveProfile()
                    }
                )
            }
        }
    }

    // MARK: - Helpers

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
            maxHeartRate: Int(maxHeartRate),
            ftp: Int(ftpWatts)
        )
        profile.save()
        showingSaveConfirmation = true
    }

    private func cleanUpDuplicates() {
        duplicatesRemoved = rideHistory.removeDuplicates()
        showingDuplicateResult = true
    }

    private func reanalyzeExistingRides() async {
        await MainActor.run {
            isReanalyzing = true
            reanalyzeProgress = "Requesting HealthKit access..."
        }

        do {
            try await healthKitService.requestAuthorization()
        } catch {
            await MainActor.run {
                isReanalyzing = false
                reanalyzeProgress = "HealthKit access denied"
            }
            return
        }

        let ridesToAnalyze = rideHistory.rides.filter { $0.creatineMetrics == nil }

        // Phase 1: Quick scan — find which rides have power data (limit:1 query, cheap)
        await MainActor.run {
            reanalyzeProgress = "Scanning \(ridesToAnalyze.count) rides for power data..."
        }

        var ridesWithPower: [Ride] = []
        for ride in ridesToAnalyze {
            if await healthKitService.hasPowerData(for: ride) {
                ridesWithPower.append(ride)
            }
        }

        guard !ridesWithPower.isEmpty else {
            await MainActor.run {
                isReanalyzing = false
                reanalyzeProgress = "No power data found in HealthKit for \(ridesToAnalyze.count) rides."
            }
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            await MainActor.run { reanalyzeProgress = "" }
            return
        }

        await MainActor.run {
            reanalyzeProgress = "Found \(ridesWithPower.count) rides with power. Analyzing..."
        }

        // Phase 2: Full analysis — only rides confirmed to have power data
        var updated = 0
        for (i, ride) in ridesWithPower.enumerated() {
            await MainActor.run {
                reanalyzeProgress = "Analyzing \(i + 1) of \(ridesWithPower.count)..."
            }

            if let metrics = await healthKitService.reanalyzePower(for: ride) {
                let updatedRide = Ride(
                    id: ride.id,
                    date: ride.date,
                    duration: ride.duration,
                    distance: ride.distance,
                    averageSpeed: ride.averageSpeed,
                    maxSpeed: ride.maxSpeed,
                    averageHeartRate: ride.averageHeartRate,
                    maxHeartRate: ride.maxHeartRate,
                    calories: ride.calories,
                    elevationGain: ride.elevationGain,
                    routeCoordinates: ride.routeCoordinates,
                    notes: ride.notes,
                    bikeName: ride.bikeName,
                    bikeType: ride.bikeType,
                    timeInZone: ride.timeInZone,
                    hrTSS: ride.hrTSS,
                    creatineMetrics: metrics
                )
                await MainActor.run {
                    rideHistory.updateRide(ride.id, with: updatedRide)
                }
                updated += 1
                print("⚡ Reanalyzed \(ride.formattedDate): 30s max=\(String(format: "%.0f", metrics.max30sPower))W, \(metrics.matchCount) matches")
            }

            // Brief pause between rides to let memory settle
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }

        await MainActor.run {
            isReanalyzing = false
            reanalyzeProgress = "Done! Analyzed \(updated) rides with power data."
        }

        try? await Task.sleep(nanoseconds: 5_000_000_000)
        await MainActor.run { reanalyzeProgress = "" }
    }

    private func runLTHREstimation() async {
        await MainActor.run {
            isEstimatingLTHR = true
            lthrProgress = "Starting..."
        }

        do {
            try await healthKitService.requestAuthorization()
        } catch {
            await MainActor.run {
                isEstimatingLTHR = false
                lthrProgress = "HealthKit access denied"
            }
            return
        }

        let estimate = await healthKitService.estimateLTHR(days: 90) { status in
            Task { @MainActor in
                lthrProgress = status
            }
        }

        await MainActor.run {
            isEstimatingLTHR = false
            lthrProgress = ""
            lthrEstimate = estimate
            showingLTHRResult = true
        }
    }
}

// MARK: - LTHR Result View

struct LTHRResultView: View {
    let estimate: HealthKitService.LTHREstimate?
    let currentLTHR: Int?
    let onApply: (Int) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let estimate {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Main result
                            VStack(spacing: 8) {
                                Text("Estimated LTHR")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                Text("\(estimate.estimatedLTHR)")
                                    .font(.system(size: 64, weight: .bold, design: .rounded))
                                    .foregroundStyle(.red)

                                Text("bpm")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)

                                if let current = currentLTHR, current > 0 {
                                    let diff = estimate.estimatedLTHR - current
                                    Text("Current: \(current) bpm (\(diff >= 0 ? "+" : "")\(diff))")
                                        .font(.subheadline)
                                        .foregroundStyle(abs(diff) > 5 ? .orange : .green)
                                }
                            }
                            .padding(.top, 20)

                            // Method explanation
                            VStack(alignment: .leading, spacing: 8) {
                                Text("How this was calculated")
                                    .font(.headline)

                                Text("Found the highest 20-minute rolling average heart rate across your recent cycling workouts, then applied a 2% discount (since field rides aren't as controlled as an FTP test).")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)

                            // Best effort details
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Best Effort")
                                    .font(.headline)

                                HStack {
                                    Text("Date")
                                    Spacer()
                                    Text(estimate.workoutDate, style: .date)
                                        .foregroundStyle(.secondary)
                                }
                                .font(.subheadline)

                                HStack {
                                    Text("Best 20-min Avg HR")
                                    Spacer()
                                    Text(String(format: "%.0f bpm", estimate.best20MinAvgHR))
                                        .foregroundStyle(.secondary)
                                }
                                .font(.subheadline)

                                HStack {
                                    Text("Ride Duration")
                                    Spacer()
                                    Text(formatDuration(estimate.workoutDuration))
                                        .foregroundStyle(.secondary)
                                }
                                .font(.subheadline)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)

                            // Top candidates
                            if estimate.candidates.count > 1 {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Top Efforts")
                                        .font(.headline)

                                    ForEach(Array(estimate.candidates.prefix(5).enumerated()), id: \.offset) { index, candidate in
                                        HStack {
                                            Text("#\(index + 1)")
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .foregroundStyle(.secondary)
                                                .frame(width: 24)

                                            VStack(alignment: .leading) {
                                                Text(candidate.date, style: .date)
                                                    .font(.caption)
                                                Text(formatDuration(candidate.duration))
                                                    .font(.caption2)
                                                    .foregroundStyle(.tertiary)
                                            }

                                            Spacer()

                                            VStack(alignment: .trailing) {
                                                Text(String(format: "%.0f", candidate.best20MinHR))
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)
                                                Text("20-min avg")
                                                    .font(.caption2)
                                                    .foregroundStyle(.tertiary)
                                            }

                                            VStack(alignment: .trailing) {
                                                Text(String(format: "%.0f", candidate.maxHR))
                                                    .font(.subheadline)
                                                Text("max")
                                                    .font(.caption2)
                                                    .foregroundStyle(.tertiary)
                                            }
                                            .frame(width: 44)
                                        }
                                        .padding(.vertical, 4)

                                        if index < min(4, estimate.candidates.count - 1) {
                                            Divider()
                                        }
                                    }
                                }
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                            }

                            // Apply button
                            if let current = currentLTHR, current != estimate.estimatedLTHR {
                                Button(action: {
                                    onApply(estimate.estimatedLTHR)
                                    dismiss()
                                }) {
                                    HStack {
                                        Spacer()
                                        Text("Use \(estimate.estimatedLTHR) bpm as my LTHR")
                                            .fontWeight(.semibold)
                                        Spacer()
                                    }
                                    .padding()
                                    .background(Color.red)
                                    .foregroundStyle(.white)
                                    .cornerRadius(12)
                                }
                            }

                            Spacer(minLength: 40)
                        }
                        .padding()
                    }
                    .background(Color(.systemGroupedBackground))
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "heart.slash")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)

                        Text("Not Enough Data")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Need at least one cycling workout longer than 30 minutes with heart rate data in the last 90 days.")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }
            }
            .navigationTitle("LTHR Estimate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
