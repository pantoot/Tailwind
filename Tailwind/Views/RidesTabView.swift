import SwiftUI
import UniformTypeIdentifiers
import HealthKit

struct RidesTabView: View {
    @EnvironmentObject var fitImportService: FITImportService
    @EnvironmentObject var rideHistory: RideHistory
    @EnvironmentObject var healthKitService: HealthKitService
    @EnvironmentObject var trainingLoadManager: TrainingLoadManager
    @EnvironmentObject var weightLogManager: WeightLogManager
    @EnvironmentObject var creatineSettingsManager: CreatineSettingsManager

    enum Segment: String, CaseIterable {
        case history = "History"
        case power = "Power"
    }

    @State private var selectedSegment: Segment = .history

    // FIT import
    @State private var showingFilePicker = false
    @State private var showingSummary = false
    @State private var importedRide: Ride?
    @State private var showingError = false
    @State private var errorMessage = ""

    // Manual entry
    @State private var showingManualEntry = false

    // Apple Health import
    @State private var showingHealthImport = false
    @State private var isImportingFromHealth = false
    @State private var healthImportProgress = ""
    @State private var showingReimportConfirm = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("View", selection: $selectedSegment) {
                    ForEach(Segment.allCases, id: \.self) { segment in
                        Text(segment.rawValue).tag(segment)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                switch selectedSegment {
                case .history:
                    historyContent
                case .power:
                    PowerAnalyticsContent()
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Rides")
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
        .alert("Save Failed", isPresented: Binding(
            get: { rideHistory.persistErrorMessage != nil },
            set: { if !$0 { rideHistory.persistErrorMessage = nil } }
        )) {
            Button("OK") { }
        } message: {
            Text(rideHistory.persistErrorMessage ?? "")
        }
        .sheet(isPresented: $showingManualEntry) {
            ManualRideEntryView()
                .environmentObject(healthKitService)
                .environmentObject(rideHistory)
                .environmentObject(trainingLoadManager)
        }
        .confirmationDialog("Reimport Today", isPresented: $showingReimportConfirm) {
            Button("Reimport Today's Rides", role: .destructive) {
                Task { await reimportToday() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will delete today's rides from Tailwind and remove Tailwind-created HealthKit workouts, then reimport today's Peloton/Zwift rides cleanly.")
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
    }

    // MARK: - History Content

    private var historyContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Import buttons row
                importButtonsRow

                // Health import progress
                if !healthImportProgress.isEmpty {
                    Text(healthImportProgress)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }

                // Ride list grouped by month
                if rideHistory.rides.isEmpty {
                    emptyState
                } else {
                    rideListByMonth
                }

                Spacer(minLength: 40)
            }
            .padding()
        }
    }

    // MARK: - Import Buttons

    private var importButtonsRow: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Button(action: { showingFilePicker = true }) {
                    HStack {
                        if fitImportService.isImporting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "square.and.arrow.down.fill")
                        }
                        Text(fitImportService.isImporting ? "Importing..." : "Import FIT")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(10)
                }
                .disabled(fitImportService.isImporting)

                Button(action: { showingHealthImport = true }) {
                    HStack {
                        if isImportingFromHealth {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "heart.fill")
                        }
                        Text(isImportingFromHealth ? "Importing..." : "Apple Health")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.pink)
                    .foregroundStyle(.white)
                    .cornerRadius(10)
                }
                .disabled(isImportingFromHealth)
            }

            HStack(spacing: 12) {
                Button(action: { showingReimportConfirm = true }) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Reimport Today")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.orange)
                    .foregroundStyle(.white)
                    .cornerRadius(10)
                }
                .disabled(isImportingFromHealth)

                Button(action: { showingManualEntry = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Manual")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .foregroundStyle(.white)
                    .cornerRadius(10)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bicycle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Rides Yet")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Import a FIT file or sync from Apple Health to get started.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Ride List Grouped by Month

    private var rideListByMonth: some View {
        let grouped = Dictionary(grouping: rideHistory.rides) { ride -> String in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM"
            return formatter.string(from: ride.date)
        }

        return ForEach(grouped.keys.sorted(by: >), id: \.self) { monthKey in
            VStack(alignment: .leading, spacing: 8) {
                Text(monthDisplayName(monthKey))
                    .font(.headline)
                    .padding(.top, 8)

                let rides = (grouped[monthKey] ?? []).sorted { $0.date > $1.date }
                ForEach(rides) { ride in
                    NavigationLink(destination: RideDetailView(ride: ride)) {
                        RideRow(ride: ride)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func monthDisplayName(_ monthKey: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        guard let date = formatter.date(from: monthKey) else { return monthKey }
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMMM yyyy"
        return displayFormatter.string(from: date)
    }

    // MARK: - File Import

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

    // MARK: - Apple Health Import

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

            let fetched = try await healthKitService.fetchCyclingWorkouts(from: startDate, to: endDate)

            // Drop Peloton warm-up/cool-down segments, which arrive as their own
            // cycling workouts and would otherwise count as rides.
            let workouts = fetched.filter { $0.duration >= Constants.Import.minimumWorkoutDuration }
            let tooShort = fetched.count - workouts.count

            await MainActor.run {
                healthImportProgress = "Found \(workouts.count) workouts..."
            }

            if workouts.isEmpty {
                await MainActor.run {
                    isImportingFromHealth = false
                    healthImportProgress = tooShort > 0
                        ? "No rides found in the last \(days) days (\(tooShort) were warm-ups/cool-downs)."
                        : "No cycling workouts found in the last \(days) days."
                }
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                await MainActor.run { healthImportProgress = "" }
                return
            }

            var imported = 0
            var skipped = 0
            var errors = 0

            for workout in workouts {
                let isDuplicate = rideHistory.hasOverlappingRide(
                    start: workout.startDate,
                    duration: workout.duration
                )

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
                if tooShort > 0 {
                    message += ", skipped \(tooShort) warm-ups/cool-downs"
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

    // MARK: - Reimport Today

    private func reimportToday() async {
        await MainActor.run {
            isImportingFromHealth = true
            healthImportProgress = "Cleaning up today's rides..."
        }

        do {
            // Step 1: Delete today's rides from Tailwind
            let removedRides = await MainActor.run {
                rideHistory.deleteRidesForDate(Date())
            }
            print("📥 Reimport: removed \(removedRides) rides from Tailwind")

            // Step 2: Delete Tailwind-created HealthKit workouts for today
            await MainActor.run {
                healthImportProgress = "Removing Tailwind workouts from HealthKit..."
            }
            let removedHK = try await healthKitService.deleteTailwindWorkouts(for: Date())
            print("📥 Reimport: removed \(removedHK) Tailwind workouts from HealthKit")

            // Step 3: Reimport today's workouts from Apple Health
            await MainActor.run {
                healthImportProgress = "Reimporting today's workouts..."
            }

            let endDate = Date()
            let startDate = Calendar.current.startOfDay(for: endDate)

            let workouts = try await healthKitService.fetchCyclingWorkouts(from: startDate, to: endDate)

            // Filter out Tailwind-created workouts (skip our own copies), plus the
            // warm-up/cool-down segments Peloton writes as separate activities.
            let externalWorkouts = workouts.filter { workout in
                workout.metadata?["Tailwind"] as? Bool != true
                    && workout.duration >= Constants.Import.minimumWorkoutDuration
            }

            if externalWorkouts.isEmpty {
                await MainActor.run {
                    isImportingFromHealth = false
                    healthImportProgress = "No external workouts found today (removed \(removedRides) dupes)."
                }
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                await MainActor.run { healthImportProgress = "" }
                return
            }

            var imported = 0
            var errors = 0

            // Deduplicate by start time (same ride from multiple sources)
            var seen = Set<Int>()
            let deduped = externalWorkouts.filter { workout in
                let key = Int(workout.startDate.timeIntervalSinceReferenceDate / 60)
                return seen.insert(key).inserted
            }

            for workout in deduped {
                do {
                    let ride = try await healthKitService.importWorkout(workout)

                    await MainActor.run {
                        rideHistory.saveRide(ride)
                        if let tss = ride.hrTSS {
                            trainingLoadManager.addTSS(date: ride.date, tss: tss)
                        }
                        imported += 1
                        healthImportProgress = "Reimported \(imported) of \(deduped.count)..."
                    }
                } catch {
                    print("⚠️ Failed to reimport workout from \(workout.startDate): \(error.localizedDescription)")
                    errors += 1
                }
            }

            await MainActor.run {
                isImportingFromHealth = false
                rideHistory.sortByDate()
                trainingLoadManager.syncFromRides(rideHistory.rides)
                var msg = "Reimported \(imported) rides"
                if removedRides > 0 { msg += " (cleaned \(removedRides) dupes)" }
                if errors > 0 { msg += ", \(errors) failed" }
                healthImportProgress = msg + "."
            }

            try? await Task.sleep(nanoseconds: 5_000_000_000)
            await MainActor.run { healthImportProgress = "" }

        } catch {
            print("❌ Reimport error: \(error)")
            await MainActor.run {
                isImportingFromHealth = false
                healthImportProgress = "Error: \(error.localizedDescription)"
            }
        }
    }

}
