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
    @EnvironmentObject var statusCenter: ImportStatusCenter
    @EnvironmentObject var router: AppRouter

    typealias Segment = AppRouter.RidesSegment


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
    @State private var showingReimportConfirm = false

    /// Nil until the user first toggles a section, so the default expansion
    /// can follow the data rather than being frozen at first render.
    @State private var expandedMonths: Set<String>?
    /// Set only for rides whose deletion is irreversible beyond the ride
    /// itself — deleting a ride prunes its GPS track from disk.
    @State private var pendingDeletion: Ride?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("View", selection: $router.ridesSegment) {
                    ForEach(Segment.allCases, id: \.self) { segment in
                        Text(segment.rawValue).tag(segment)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                // Above the segment switch so progress survives History<->Power.
                ImportStatusBanner()

                switch router.ridesSegment {
                case .history:
                    historyContent
                case .power:
                    PowerAnalyticsContent()
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Rides")
            .toolbar {
                if router.ridesSegment == .history {
                    ToolbarItem(placement: .topBarTrailing) { importMenu }
                }
            }
        }
        .onChange(of: rideHistory.rides.count) { oldCount, newCount in
            // A fresh import routes here; if the user has previously collapsed
            // sections, make sure the new ride's month is open so it doesn't
            // look like the import silently did nothing.
            guard newCount > oldCount,
                  var expanded = expandedMonths,
                  let newest = rideHistory.rides.max(by: { $0.date < $1.date }) else { return }
            expanded.insert(RideListService.monthKey(for: newest.date))
            expandedMonths = expanded
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
        Group {
            if rideHistory.rides.isEmpty {
                ScrollView {
                    VStack(spacing: 16) {
                        emptyState
                    }
                    .padding()
                }
            } else {
                rideList
            }
        }
        .confirmationDialog(
            "Delete this ride?",
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            presenting: pendingDeletion
        ) { ride in
            Button("Delete Ride", role: .destructive) {
                delete(ride)
                pendingDeletion = nil
            }
            Button("Cancel", role: .cancel) { pendingDeletion = nil }
        } message: { ride in
            Text("\(ride.formattedDate) — this also deletes the ride's GPS route, which can't be recovered.")
        }
    }

    // MARK: - Import Menu

    private var isImporting: Bool {
        fitImportService.isImporting || isImportingFromHealth
    }

    private var importMenu: some View {
        Menu {
            Button {
                showingFilePicker = true
            } label: {
                Label("Import FIT File", systemImage: "doc.badge.plus")
            }

            Button {
                showingHealthImport = true
            } label: {
                Label("Import from Apple Health", systemImage: "heart.fill")
            }

            Button {
                showingManualEntry = true
            } label: {
                Label("Manual Entry", systemImage: "square.and.pencil")
            }

            Divider()

            Button(role: .destructive) {
                showingReimportConfirm = true
            } label: {
                Label("Reimport Today", systemImage: "arrow.clockwise")
            }
        } label: {
            if isImporting {
                ProgressView()
            } else {
                Image(systemName: "plus")
            }
        }
        .disabled(isImporting)
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

    private var rideList: some View {
        let grouped = Dictionary(grouping: rideHistory.rides) {
            RideListService.monthKey(for: $0.date)
        }
        let monthKeys = RideListService.sortedMonthKeys(grouped.keys)
        let expanded = expandedMonths ?? RideListService.defaultExpandedKeys(allKeys: monthKeys)

        return List {
            // Interim home until Phase 3's Trends tab exists — this was the
            // only entry point to trend charts and it lived behind a "See All"
            // link that looked like it opened a ride list.
            Section {
                NavigationLink {
                    PerformanceTrendsView()
                } label: {
                    Label("Performance Trends", systemImage: "chart.xyaxis.line")
                }
            }

            totalsSection

            ForEach(monthKeys, id: \.self) { key in
                Section {
                    if expanded.contains(key) {
                        ForEach((grouped[key] ?? []).sorted { $0.date > $1.date }) { ride in
                            rideRow(ride)
                        }
                    }
                } header: {
                    monthHeader(key: key, count: grouped[key]?.count ?? 0, isExpanded: expanded.contains(key)) {
                        var next = expanded
                        if next.contains(key) { next.remove(key) } else { next.insert(key) }
                        expandedMonths = next
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var totalsSection: some View {
        Section {
            HStack(alignment: .top) {
                totalStat("Rides", "\(rideHistory.totalRides)")
                Spacer()
                totalStat("Miles", String(format: "%.0f", rideHistory.totalDistance))
                Spacer()
                totalStat("Time", RideListService.formatDuration(rideHistory.totalDuration))
                Spacer()
                totalStat("Calories", String(format: "%.0f", rideHistory.totalCalories))
            }
            .padding(.vertical, 4)
        }
    }

    private func totalStat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private func monthHeader(key: String, count: Int, isExpanded: Bool, toggle: @escaping () -> Void) -> some View {
        Button(action: toggle) {
            HStack {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption2)
                Text(RideListService.monthTitle(forKey: key))
                Spacer()
                Text("\(count)")
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func rideRow(_ ride: Ride) -> some View {
        NavigationLink(destination: RideDetailView(ride: ride)) {
            RideRow(ride: ride)
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                // Deleting prunes the ride's GPS track from disk, so outdoor
                // rides confirm first. Indoor rides lose nothing recoverable.
                if ride.hasRouteData {
                    pendingDeletion = ride
                } else {
                    delete(ride)
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    /// The one delete path. Training load must be resynced here or CTL/ATL
    /// keep counting the deleted ride's TSS until the next launch.
    private func delete(_ ride: Ride) {
        rideHistory.deleteRide(ride)
        trainingLoadManager.syncFromRides(rideHistory.rides)
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
            statusCenter.start("Apple Health import", detail: "Requesting access…")
        }

        do {
            try await healthKitService.requestAuthorization()

            await MainActor.run {
                statusCenter.progress("Fetching workouts…")
            }

            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate) ?? endDate

            let fetched = try await healthKitService.fetchCyclingWorkouts(from: startDate, to: endDate)

            // Drop Peloton warm-up/cool-down segments, which arrive as their own
            // cycling workouts and would otherwise count as rides.
            let workouts = fetched.filter { $0.duration >= Constants.Import.minimumWorkoutDuration }
            let tooShort = fetched.count - workouts.count

            await MainActor.run {
                statusCenter.progress("Found \(workouts.count) workouts…")
            }

            if workouts.isEmpty {
                await MainActor.run {
                    isImportingFromHealth = false
                    statusCenter.succeed(tooShort > 0
                        ? "No rides found in the last \(days) days (\(tooShort) were warm-ups/cool-downs)."
                        : "No cycling workouts found in the last \(days) days.")
                }
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
                        statusCenter.progress("Imported \(imported) of \(workouts.count - skipped)…")
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
                statusCenter.succeed(message + ".")

                rideHistory.sortByDate()
            }

        } catch {
            print("❌ Health import error: \(error)")
            await MainActor.run {
                isImportingFromHealth = false
                statusCenter.fail(error.localizedDescription)
            }
        }
    }

    // MARK: - Reimport Today

    private func reimportToday() async {
        await MainActor.run {
            isImportingFromHealth = true
            statusCenter.start("Reimport today", detail: "Cleaning up today's rides…")
        }

        do {
            // Step 1: Delete today's rides from Tailwind
            let removedRides = await MainActor.run {
                rideHistory.deleteRidesForDate(Date())
            }
            print("📥 Reimport: removed \(removedRides) rides from Tailwind")

            // Step 2: Delete Tailwind-created HealthKit workouts for today
            await MainActor.run {
                statusCenter.progress("Removing Tailwind workouts from HealthKit…")
            }
            let removedHK = try await healthKitService.deleteTailwindWorkouts(for: Date())
            print("📥 Reimport: removed \(removedHK) Tailwind workouts from HealthKit")

            // Step 3: Reimport today's workouts from Apple Health
            await MainActor.run {
                statusCenter.progress("Reimporting today's workouts…")
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
                    statusCenter.succeed("No external workouts found today (removed \(removedRides) dupes).")
                }
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
                        statusCenter.progress("Reimported \(imported) of \(deduped.count)…")
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
                statusCenter.succeed(msg + ".")
            }

        } catch {
            print("❌ Reimport error: \(error)")
            await MainActor.run {
                isImportingFromHealth = false
                statusCenter.fail(error.localizedDescription)
            }
        }
    }

}
