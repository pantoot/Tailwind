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

    // TSS recalculation
    @State private var isRecalculatingTSS = false
    @State private var tssRecalcProgress = ""

    // HealthKit diagnostics
    @State private var isDiagnosing = false
    @State private var diagnosticResults: [HealthKitService.WorkoutDiagnostic] = []
    @State private var showingDiagnostics = false
    @State private var diagnosticDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()

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

                    Button(action: { Task { await recalculateMissingTSS() } }) {
                        HStack {
                            Label("Recalculate TSS", systemImage: "heart.text.clipboard")
                                .foregroundStyle(.primary)
                            Spacer()
                            if isRecalculatingTSS {
                                ProgressView()
                            } else {
                                let count = rideHistory.rides.filter { $0.hrTSS == nil }.count
                                Text("\(count) rides")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .disabled(isRecalculatingTSS)

                    if !tssRecalcProgress.isEmpty {
                        Text(tssRecalcProgress)
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

                Section("Training Analysis") {
                    Button(action: printTrainingAnalysis) {
                        Label("Print 30-Day Analysis", systemImage: "chart.line.uptrend.xyaxis")
                            .foregroundStyle(.primary)
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

                Section("HealthKit Diagnostics") {
                    DatePicker("Check Date", selection: $diagnosticDate, displayedComponents: .date)

                    Button(action: { Task { await runDiagnostics() } }) {
                        HStack {
                            Label("Show All Workouts", systemImage: "stethoscope")
                                .foregroundStyle(.primary)
                            Spacer()
                            if isDiagnosing {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isDiagnosing)

                    if !diagnosticResults.isEmpty {
                        ForEach(diagnosticResults) { d in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(d.activityType)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    if d.hasTailwindMeta {
                                        Text("Tailwind")
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.blue.opacity(0.2))
                                            .cornerRadius(4)
                                    }
                                    Spacer()
                                    Text(d.source)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                HStack {
                                    let fmt = DateFormatter()
                                    let _ = fmt.dateFormat = "h:mm a"
                                    Text("\(fmt.string(from: d.startTime)) - \(fmt.string(from: d.endTime))")
                                        .font(.caption)
                                    Spacer()
                                    Text("\(Int(d.duration / 60)) min")
                                        .font(.caption)
                                }
                                .foregroundStyle(.secondary)
                                HStack {
                                    if d.calories > 0 {
                                        Text("\(Int(d.calories)) kcal")
                                    }
                                    if d.distance > 0 {
                                        Text(String(format: "%.1f mi", d.distance))
                                    }
                                    Spacer()
                                    Text(d.bundleId)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    } else if !isDiagnosing && showingDiagnostics {
                        Text("No workouts found for this date.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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

    private func printTrainingAnalysis() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: today)!
        let sixtyDaysAgo = calendar.date(byAdding: .day, value: -60, to: today)!

        // Get rides in last 30 and previous 30 days
        let recentRides = rideHistory.rides.filter { $0.date >= thirtyDaysAgo }
        let previousRides = rideHistory.rides.filter { $0.date >= sixtyDaysAgo && $0.date < thirtyDaysAgo }

        // Current metrics
        let current = trainingLoadManager.calculateCurrentMetrics()
        let thirtyDaysAgoMetrics = trainingLoadManager.calculateMetrics(asOf: thirtyDaysAgo)
        let rampRate = trainingLoadManager.getRampRate()
        let weekly = trainingLoadManager.getWeeklySummary()

        // Ride frequency
        let recentDaysWithRides = Set(recentRides.map { calendar.startOfDay(for: $0.date) }).count
        let previousDaysWithRides = Set(previousRides.map { calendar.startOfDay(for: $0.date) }).count

        // TSS stats
        let recentTSS = recentRides.compactMap { $0.hrTSS }
        let previousTSS = previousRides.compactMap { $0.hrTSS }
        let recentTotalTSS = recentTSS.reduce(0, +)
        let previousTotalTSS = previousTSS.reduce(0, +)
        let recentAvgTSS = recentTSS.isEmpty ? 0 : recentTotalTSS / Double(recentTSS.count)
        let previousAvgTSS = previousTSS.isEmpty ? 0 : previousTotalTSS / Double(previousTSS.count)

        // Duration stats
        let recentTotalDuration = recentRides.reduce(0) { $0 + $1.duration } / 3600 // hours
        let previousTotalDuration = previousRides.reduce(0) { $0 + $1.duration } / 3600
        let recentTotalDistance = recentRides.reduce(0) { $0 + $1.distance }
        let previousTotalDistance = previousRides.reduce(0) { $0 + $1.distance }
        let recentTotalCalories = recentRides.reduce(0) { $0 + $1.calories }

        // HR stats
        let recentAvgHR = recentRides.filter { $0.averageHeartRate > 0 }
        let avgHR = recentAvgHR.isEmpty ? 0 : recentAvgHR.reduce(0) { $0 + $1.averageHeartRate } / Double(recentAvgHR.count)
        let maxHRRide = recentRides.max(by: { $0.maxHeartRate < $1.maxHeartRate })

        // Power stats (rides with creatine metrics)
        let powerRides = recentRides.filter { $0.creatineMetrics != nil }
        let previousPowerRides = previousRides.filter { $0.creatineMetrics != nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        print("")
        print("═══════════════════════════════════════════════════")
        print("  📊 TAILWIND 30-DAY TRAINING ANALYSIS")
        print("  Period: \(formatter.string(from: thirtyDaysAgo)) – \(formatter.string(from: today))")
        print("═══════════════════════════════════════════════════")
        print("")
        print("── CURRENT STATUS ─────────────────────────────────")
        print("  Form:    \(current.formStatus.rawValue) (TSB: \(String(format: "%+.0f", current.tsb)))")
        print("  Fitness: CTL \(String(format: "%.0f", current.ctl)) (\(current.fitnessLevel))")
        print("  Fatigue: ATL \(String(format: "%.0f", current.atl))")
        print("  Ramp:    \(String(format: "%+.1f", rampRate)) CTL/wk \(abs(rampRate) > 5 ? "⚠️ HIGH" : "✅")")
        print("")
        print("── FITNESS TREND (CTL) ────────────────────────────")
        print("  30 days ago: \(String(format: "%.0f", thirtyDaysAgoMetrics.ctl))")
        print("  Today:       \(String(format: "%.0f", current.ctl))")
        let ctlDelta = current.ctl - thirtyDaysAgoMetrics.ctl
        print("  Change:      \(String(format: "%+.0f", ctlDelta)) \(ctlDelta > 0 ? "📈" : ctlDelta < 0 ? "📉" : "➡️")")
        print("")
        print("── VOLUME (last 30 vs previous 30) ────────────────")
        print("  Rides:    \(recentRides.count) vs \(previousRides.count) \(recentRides.count > previousRides.count ? "📈" : recentRides.count < previousRides.count ? "📉" : "➡️")")
        print("  Days on:  \(recentDaysWithRides) vs \(previousDaysWithRides)")
        print("  Hours:    \(String(format: "%.1f", recentTotalDuration)) vs \(String(format: "%.1f", previousTotalDuration)) \(recentTotalDuration > previousTotalDuration ? "📈" : "📉")")
        print("  Miles:    \(String(format: "%.0f", recentTotalDistance)) vs \(String(format: "%.0f", previousTotalDistance))")
        print("  Calories: \(String(format: "%.0f", recentTotalCalories))")
        print("")
        print("── INTENSITY ──────────────────────────────────────")
        print("  Total TSS:  \(String(format: "%.0f", recentTotalTSS)) vs \(String(format: "%.0f", previousTotalTSS)) \(recentTotalTSS > previousTotalTSS ? "📈" : "📉")")
        print("  Avg TSS:    \(String(format: "%.0f", recentAvgTSS)) vs \(String(format: "%.0f", previousAvgTSS)) per ride")
        print("  This week:  \(String(format: "%.0f", weekly.weekTSS)) TSS (\(String(format: "%.0f", weekly.weekAverage))/day)")
        if avgHR > 0 {
            print("  Avg HR:     \(String(format: "%.0f", avgHR)) bpm")
        }
        if let maxHR = maxHRRide, maxHR.maxHeartRate > 0 {
            print("  Max HR:     \(maxHR.maxHeartRate) bpm (\(formatter.string(from: maxHR.date)))")
        }
        print("")
        print("── POWER (creatine-relevant) ──────────────────────")
        print("  Rides w/ power: \(powerRides.count) (last 30) vs \(previousPowerRides.count) (prev 30)")
        if !powerRides.isEmpty {
            let maxPowers = powerRides.compactMap { $0.creatineMetrics?.max30sPower }
            let avgMaxPower = maxPowers.reduce(0, +) / Double(maxPowers.count)
            let peakMaxPower = maxPowers.max() ?? 0
            let totalMatches = powerRides.compactMap { $0.creatineMetrics?.matchCount }.reduce(0, +)
            print("  Avg 30s max: \(String(format: "%.0f", avgMaxPower))W")
            print("  Peak 30s:    \(String(format: "%.0f", peakMaxPower))W")
            print("  Total matches: \(totalMatches)")

            if !previousPowerRides.isEmpty {
                let prevMaxPowers = previousPowerRides.compactMap { $0.creatineMetrics?.max30sPower }
                let prevAvgMaxPower = prevMaxPowers.reduce(0, +) / Double(prevMaxPowers.count)
                let prevTotalMatches = previousPowerRides.compactMap { $0.creatineMetrics?.matchCount }.reduce(0, +)
                let powerDelta = avgMaxPower - prevAvgMaxPower
                print("  vs prev 30:  \(String(format: "%+.0f", powerDelta))W avg 30s, \(totalMatches) vs \(prevTotalMatches) matches")
            }
        }
        print("")
        print("── ROUTE ANALYSIS (matching distances ±0.5 mi) ────")
        // Group all rides by rounded distance to find repeated routes
        let allRides = rideHistory.rides.filter { $0.duration >= 15 * 60 } // skip cooldowns
        let routeGroups: [String: [Ride]] = Dictionary(grouping: allRides) { ride in
            // Round to nearest 0.5 mile to catch same-route variations
            let rounded = (ride.distance * 2).rounded() / 2
            return String(format: "%.1f", rounded)
        }

        // Filter to routes ridden 3+ times, sort by frequency
        let repeatedRoutes = routeGroups
            .filter { $0.value.count >= 3 }
            .sorted { $0.value.count > $1.value.count }

        if repeatedRoutes.isEmpty {
            print("  No routes with 3+ rides found")
        }

        for (distKey, rides) in repeatedRoutes {
            let sorted = rides.sorted { $0.date < $1.date }
            print("")
            print("  📍 ~\(distKey) mi route (\(sorted.count) rides)")
            print("  ────────────────────────────────────────────────")
            print("  Date         Speed    HR      TSS    Duration  Power")

            for ride in sorted {
                let hrStr = ride.averageHeartRate > 0 ? String(format: "%3.0f bpm", ride.averageHeartRate) : "  — bpm"
                let powerStr = ride.creatineMetrics.map { String(format: "%3.0fW avg", $0.averagePower) } ?? "   —"
                print("  \(formatter.string(from: ride.date))    \(String(format: "%4.1f", ride.averageSpeed)) mph  \(hrStr)  \(String(format: "%3.0f", ride.hrTSS ?? 0))    \(ride.formattedDuration)    \(powerStr)")
            }

            // Trend analysis for this route
            let firstThird = Array(sorted.prefix(sorted.count / 3 + 1))
            let lastThird = Array(sorted.suffix(sorted.count / 3 + 1))

            let earlySpeed = firstThird.reduce(0) { $0 + $1.averageSpeed } / Double(firstThird.count)
            let lateSpeed = lastThird.reduce(0) { $0 + $1.averageSpeed } / Double(lastThird.count)
            let speedDelta = lateSpeed - earlySpeed

            let earlyHR = firstThird.filter { $0.averageHeartRate > 0 }
            let lateHR = lastThird.filter { $0.averageHeartRate > 0 }
            let earlyAvgHR = earlyHR.isEmpty ? 0 : earlyHR.reduce(0) { $0 + $1.averageHeartRate } / Double(earlyHR.count)
            let lateAvgHR = lateHR.isEmpty ? 0 : lateHR.reduce(0) { $0 + $1.averageHeartRate } / Double(lateHR.count)
            let hrDelta = lateAvgHR - earlyAvgHR

            let earlyPower = firstThird.compactMap { $0.creatineMetrics?.averagePower }.filter { $0 > 0 }
            let latePower = lastThird.compactMap { $0.creatineMetrics?.averagePower }.filter { $0 > 0 }
            let earlyAvgPower = earlyPower.isEmpty ? 0 : earlyPower.reduce(0, +) / Double(earlyPower.count)
            let lateAvgPower = latePower.isEmpty ? 0 : latePower.reduce(0, +) / Double(latePower.count)

            print("")
            print("  Trend (early → recent):")
            print("    Speed: \(String(format: "%.1f", earlySpeed)) → \(String(format: "%.1f", lateSpeed)) mph (\(String(format: "%+.1f", speedDelta))) \(speedDelta > 0 ? "🚀 FASTER" : speedDelta < -0.3 ? "🐌 SLOWER" : "➡️ SAME")")
            if earlyAvgHR > 0 && lateAvgHR > 0 {
                print("    HR:    \(String(format: "%.0f", earlyAvgHR)) → \(String(format: "%.0f", lateAvgHR)) bpm (\(String(format: "%+.0f", hrDelta))) \(hrDelta < -2 ? "💚 MORE EFFICIENT" : hrDelta > 2 ? "❤️ WORKING HARDER" : "➡️ SAME")")
            }
            if earlyAvgPower > 0 && lateAvgPower > 0 {
                let powerDelta = lateAvgPower - earlyAvgPower
                print("    Power: \(String(format: "%.0f", earlyAvgPower)) → \(String(format: "%.0f", lateAvgPower))W (\(String(format: "%+.0f", powerDelta))) \(powerDelta > 3 ? "⚡ STRONGER" : powerDelta < -3 ? "📉 LOWER" : "➡️ SAME")")
            }

            // Efficiency: speed per HR beat (higher = fitter)
            if earlyAvgHR > 0 && lateAvgHR > 0 {
                let earlyEff = earlySpeed / earlyAvgHR
                let lateEff = lateSpeed / lateAvgHR
                let effDelta = ((lateEff - earlyEff) / earlyEff) * 100
                print("    Efficiency (mph/bpm): \(String(format: "%.3f", earlyEff)) → \(String(format: "%.3f", lateEff)) (\(String(format: "%+.1f%%", effDelta))) \(effDelta > 1 ? "📈 IMPROVING" : effDelta < -1 ? "📉 DECLINING" : "➡️ STABLE")")
            }
        }

        print("")
        print("── RECENT RIDES ───────────────────────────────────")
        for ride in recentRides.sorted(by: { $0.date > $1.date }).prefix(10) {
            let tssStr = ride.hrTSS.map { String(format: "%.0f", $0) } ?? "—"
            let powerStr = ride.creatineMetrics.map { String(format: "%.0fW", $0.averagePower) } ?? ""
            let hrStr = ride.averageHeartRate > 0 ? "\(String(format: "%.0f", ride.averageHeartRate))bpm" : ""
            print("  \(formatter.string(from: ride.date)): \(String(format: "%4.1f", ride.distance))mi  \(ride.formattedDuration)  TSS:\(tssStr)  \(powerStr)  \(hrStr)  \(ride.notes ?? "")")
        }
        print("")
        print("═══════════════════════════════════════════════════")
        print("")
    }

    private func runDiagnostics() async {
        await MainActor.run {
            isDiagnosing = true
            diagnosticResults = []
            showingDiagnostics = true
        }

        do {
            let results = try await healthKitService.diagnoseWorkouts(for: diagnosticDate)
            await MainActor.run {
                diagnosticResults = results
                isDiagnosing = false
            }
            print("🔍 Found \(results.count) workouts for \(diagnosticDate)")
            for d in results {
                print("   \(d.activityType) | \(d.source) (\(d.bundleId)) | \(Int(d.duration/60))min | \(Int(d.calories))kcal | \(String(format: "%.1f", d.distance))mi")
            }
        } catch {
            print("❌ Diagnostics error: \(error)")
            await MainActor.run {
                isDiagnosing = false
            }
        }
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
                // Also backfill TSS if missing
                var updatedHR = ride.averageHeartRate
                var updatedMaxHR = ride.maxHeartRate
                var updatedTSS = ride.hrTSS
                if ride.hrTSS == nil, let hrData = await healthKitService.reanalyzeHR(for: ride) {
                    updatedHR = hrData.averageHR
                    updatedMaxHR = Int(hrData.maxHR)
                    updatedTSS = hrData.hrTSS
                }
                let updatedRide = Ride(
                    id: ride.id,
                    date: ride.date,
                    duration: ride.duration,
                    distance: ride.distance,
                    averageSpeed: ride.averageSpeed,
                    maxSpeed: ride.maxSpeed,
                    averageHeartRate: updatedHR,
                    maxHeartRate: updatedMaxHR,
                    calories: ride.calories,
                    averagePower: metrics.averagePower,
                    averageCadence: ride.averageCadence,
                    elevationGain: ride.elevationGain,
                    routeCoordinates: ride.routeCoordinates,
                    notes: ride.notes,
                    bikeName: ride.bikeName,
                    bikeType: ride.bikeType,
                    timeInZone: ride.timeInZone,
                    hrTSS: updatedTSS,
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

    private func recalculateMissingTSS() async {
        await MainActor.run {
            isRecalculatingTSS = true
            tssRecalcProgress = "Requesting HealthKit access..."
        }

        do {
            try await healthKitService.requestAuthorization()
        } catch {
            await MainActor.run {
                isRecalculatingTSS = false
                tssRecalcProgress = "HealthKit access denied"
            }
            return
        }

        let ridesToFix = rideHistory.rides.filter { $0.hrTSS == nil }

        guard !ridesToFix.isEmpty else {
            await MainActor.run {
                isRecalculatingTSS = false
                tssRecalcProgress = "All rides already have TSS."
            }
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run { tssRecalcProgress = "" }
            return
        }

        await MainActor.run {
            tssRecalcProgress = "Checking \(ridesToFix.count) rides for HR data..."
        }

        var updated = 0
        for (i, ride) in ridesToFix.enumerated() {
            await MainActor.run {
                tssRecalcProgress = "Checking \(i + 1) of \(ridesToFix.count)..."
            }

            if let hrData = await healthKitService.reanalyzeHR(for: ride) {
                let updatedRide = Ride(
                    id: ride.id,
                    date: ride.date,
                    duration: ride.duration,
                    distance: ride.distance,
                    averageSpeed: ride.averageSpeed,
                    maxSpeed: ride.maxSpeed,
                    averageHeartRate: hrData.averageHR,
                    maxHeartRate: Int(hrData.maxHR),
                    calories: ride.calories,
                    averagePower: ride.averagePower,
                    averageCadence: ride.averageCadence,
                    elevationGain: ride.elevationGain,
                    routeCoordinates: ride.routeCoordinates,
                    notes: ride.notes,
                    bikeName: ride.bikeName,
                    bikeType: ride.bikeType,
                    timeInZone: ride.timeInZone,
                    hrTSS: hrData.hrTSS,
                    creatineMetrics: ride.creatineMetrics
                )
                await MainActor.run {
                    rideHistory.updateRide(ride.id, with: updatedRide)
                }
                updated += 1
                print("📊 TSS recalc \(ride.formattedDate): avgHR=\(String(format: "%.0f", hrData.averageHR)), TSS=\(String(format: "%.1f", hrData.hrTSS ?? 0))")
            }

            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }

        await MainActor.run {
            isRecalculatingTSS = false
            if updated > 0 {
                tssRecalcProgress = "Done! Recalculated TSS for \(updated) rides."
                trainingLoadManager.syncFromRides(rideHistory.rides)
            } else {
                tssRecalcProgress = "No HR data found in HealthKit for \(ridesToFix.count) rides."
            }
        }

        try? await Task.sleep(nanoseconds: 5_000_000_000)
        await MainActor.run { tssRecalcProgress = "" }
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
