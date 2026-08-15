import SwiftUI
import Combine
import CoreLocation

@main
struct TailwindApp: App {
    @StateObject private var services = AppServices()
    @Environment(\.scenePhase) private var scenePhase

    /// Track if we're handling a URL import (prevents race with pending imports)
    @State private var isHandlingURLImport = false

    /// Shared App Group defaults — lazy to avoid CFPrefs warning at launch
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: "group.com.rick.Tailwind")
    }

    @State private var selectedTab = 0

    /// Guards against two overlapping pending-import sweeps (onAppear + foreground
    /// can both fire within the same half-second).
    @State private var isProcessingPendingImports = false

    /// Set when any import path fails; drives the user-visible alert.
    @State private var importFailureMessage: String?

    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                ImportView()
                    .tabItem { Label("Dashboard", systemImage: "chart.bar.fill") }
                    .tag(0)

                RidesTabView()
                    .tabItem { Label("Rides", systemImage: "bicycle") }
                    .tag(1)

                SettingsTabView()
                    .tabItem { Label("Settings", systemImage: "gearshape") }
                    .tag(2)
            }
                .environmentObject(services.fitImportService)
                .environmentObject(services.rideHistory)
                .environmentObject(services.healthKitService)
                .environmentObject(services.trainingLoadManager)
                .environmentObject(services.weightLogManager)
                .environmentObject(services.creatineSettingsManager)
                .onOpenURL { url in
                    isHandlingURLImport = true
                    handleIncomingURL(url)
                }
                .onAppear {
                    // Delay to allow URL handler to fire first if app opened via URL
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if !isHandlingURLImport {
                            processPendingImports()
                        }
                    }
                }
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    if newPhase == .active && oldPhase == .background {
                        print("📱 App became active from background")
                        // Delay to allow URL handler to fire first
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            if !isHandlingURLImport {
                                processPendingImports()
                            }
                            isHandlingURLImport = false  // Reset for next time
                        }
                    }
                }
                .alert("Import Failed", isPresented: Binding(
                    get: { importFailureMessage != nil },
                    set: { if !$0 { importFailureMessage = nil } }
                )) {
                    Button("OK") { }
                } message: {
                    Text(importFailureMessage ?? "")
                }
        }
    }

    /// Handle URLs from share extension or other apps
    private func handleIncomingURL(_ url: URL) {
        print("📥 Received URL: \(url)")
        print("📥 Scheme: \(url.scheme ?? "nil"), Host: \(url.host ?? "nil")")

        // Handle tailwind:// URL scheme
        if url.scheme == "tailwind" && url.host == "import" {
            print("📥 Processing tailwind://import URL")
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let fileParam = components.queryItems?.first(where: { $0.name == "file" })?.value,
               let filePath = fileParam.removingPercentEncoding {
                let fileURL = URL(fileURLWithPath: filePath)
                print("📥 File path: \(filePath)")
                print("📥 File exists: \(FileManager.default.fileExists(atPath: filePath))")

                // Clear this file from pending imports to prevent double-import
                clearPendingImport(path: filePath)

                Task {
                    do {
                        let ride = try await services.fitImportService.importFITFile(from: fileURL)
                        print("✅ Successfully imported ride: \(ride.formattedDate), \(ride.formattedDistance)")

                        // Update training load stats
                        if let tss = ride.hrTSS {
                            await MainActor.run {
                                services.trainingLoadManager.addTSS(date: ride.date, tss: tss)
                            }
                            print("📊 Added TSS: \(String(format: "%.0f", tss))")
                        }

                        // Switch to Rides tab
                        await MainActor.run { selectedTab = 1 }

                        // Clean up the temp file after import
                        try? FileManager.default.removeItem(at: fileURL)
                    } catch FITImportService.ImportError.duplicateRide {
                        // Terminal, not retryable — re-queueing would alert forever.
                        print("⚠️ Duplicate FIT import ignored: \(filePath)")
                        try? FileManager.default.removeItem(at: fileURL)
                    } catch {
                        print("❌ Failed to import from URL: \(error)")
                        // The file was dequeued before parsing to prevent a
                        // double-import race — put it back so a retry is possible,
                        // and tell the user instead of failing silently.
                        await MainActor.run {
                            requeuePendingImport(path: filePath)
                            importFailureMessage = "Could not import \(fileURL.lastPathComponent): \(error.localizedDescription)"
                        }
                    }
                }
            } else {
                print("❌ Could not parse file parameter from URL")
            }
        }
        // Handle direct FIT file opens
        else if url.pathExtension.lowercased() == "fit" {
            print("📥 Processing direct FIT file: \(url.path)")
            Task {
                do {
                    let ride = try await services.fitImportService.importFITFile(from: url)
                    print("✅ Successfully imported ride: \(ride.formattedDate), \(ride.formattedDistance)")

                    // Update training load stats
                    if let tss = ride.hrTSS {
                        await MainActor.run {
                            services.trainingLoadManager.addTSS(date: ride.date, tss: tss)
                        }
                        print("📊 Added TSS: \(String(format: "%.0f", tss))")
                    }

                    // Switch to Rides tab
                    await MainActor.run { selectedTab = 1 }
                } catch {
                    print("❌ Failed to import FIT file: \(error)")
                    await MainActor.run {
                        importFailureMessage = "Could not import \(url.lastPathComponent): \(error.localizedDescription)"
                    }
                }
            }
        } else {
            print("⚠️ Unhandled URL scheme/type")
        }
    }

    /// Remove a specific file from pending imports (to prevent double-import)
    private func clearPendingImport(path: String) {
        guard let defaults = sharedDefaults else { return }
        var pending = defaults.stringArray(forKey: "pendingFITImports") ?? []
        if let index = pending.firstIndex(of: path) {
            pending.remove(at: index)
            defaults.set(pending, forKey: "pendingFITImports")
            print("📥 Cleared \(path) from pending imports")
        }
    }

    /// Put a failed import back in the queue so the next foreground retries it.
    private func requeuePendingImport(path: String) {
        guard let defaults = sharedDefaults else { return }
        var pending = defaults.stringArray(forKey: "pendingFITImports") ?? []
        if !pending.contains(path) {
            pending.append(path)
            defaults.set(pending, forKey: "pendingFITImports")
            print("📥 Re-queued failed import: \(path)")
        }
    }

    /// Process any FIT files shared via the extension while app was closed
    private func processPendingImports() {
        print("📋 Checking for pending imports...")
        guard let defaults = sharedDefaults else {
            print("❌ Could not access App Group defaults")
            return
        }
        guard let pendingPaths = defaults.stringArray(forKey: "pendingFITImports"), !pendingPaths.isEmpty else {
            print("📋 No pending imports found")
            return
        }

        print("📋 Found \(pendingPaths.count) pending imports: \(pendingPaths)")

        // Entries stay queued until their import actually succeeds — clearing the
        // list up front meant a failed parse silently lost the ride forever.
        guard !isProcessingPendingImports else {
            print("📋 Pending-import sweep already running, skipping")
            return
        }
        isProcessingPendingImports = true

        // Import each pending file
        Task {
            defer { Task { @MainActor in isProcessingPendingImports = false } }
            var failures: [String] = []

            for path in pendingPaths {
                let url = URL(fileURLWithPath: path)
                print("📋 Processing: \(path)")

                guard FileManager.default.fileExists(atPath: path) else {
                    print("⚠️ File not found, dropping from queue: \(path)")
                    await MainActor.run { clearPendingImport(path: path) }
                    continue
                }

                do {
                    let ride = try await services.fitImportService.importFITFile(from: url)

                    // Update training load stats
                    if let tss = ride.hrTSS {
                        await MainActor.run {
                            services.trainingLoadManager.addTSS(date: ride.date, tss: tss)
                        }
                        print("📊 Added TSS: \(String(format: "%.0f", tss))")
                    }

                    await MainActor.run {
                        // Dequeue only now that the import has fully succeeded
                        clearPendingImport(path: path)
                        selectedTab = 1
                    }

                    // Clean up after successful import
                    try? FileManager.default.removeItem(at: url)
                    print("✅ Processed pending import: \(ride.formattedDate), \(ride.formattedDistance)")
                } catch FITImportService.ImportError.duplicateRide {
                    // Terminal, not retryable — dequeue so it doesn't alert forever.
                    print("⚠️ Duplicate pending import ignored: \(path)")
                    await MainActor.run { clearPendingImport(path: path) }
                    try? FileManager.default.removeItem(at: url)
                } catch {
                    print("❌ Failed pending import (kept in queue for retry): \(error)")
                    failures.append("\(url.lastPathComponent): \(error.localizedDescription)")
                }
            }

            if !failures.isEmpty {
                await MainActor.run {
                    importFailureMessage = "Some shared rides could not be imported. They will be retried next launch.\n\n" + failures.joined(separator: "\n")
                }
            }
        }
    }
}

/// Simplified service container for FIT import focused app
class AppServices: ObservableObject {
    let rideHistory: RideHistory
    let healthKitService: HealthKitService
    let fitImportService: FITImportService
    let trainingLoadManager: TrainingLoadManager
    let weightLogManager: WeightLogManager
    let creatineSettingsManager: CreatineSettingsManager

    init() {
        // Initialize core services
        self.rideHistory = RideHistory()
        self.healthKitService = HealthKitService()
        self.trainingLoadManager = TrainingLoadManager()
        self.weightLogManager = WeightLogManager()
        self.creatineSettingsManager = CreatineSettingsManager()

        // FIT import service depends on HealthKit and RideHistory
        self.fitImportService = FITImportService(
            healthKitService: healthKitService,
            rideHistory: rideHistory
        )

        print("🚀 Tailwind initialized - FIT Import Mode")

        // Clean up duplicates
        let removed = rideHistory.removeDuplicates()
        if removed > 0 {
            print("🧹 Removed \(removed) duplicate ride(s)")
        }

        // Sync TSS data from rides to training load manager
        trainingLoadManager.syncFromRides(rideHistory.rides)

        // Debug: Print rides and training load calculation
        print("🚴 === RIDES DEBUG ===")
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        for ride in rideHistory.rides.prefix(10) {
            let tssStr = ride.hrTSS.map { String(format: "%.0f TSS", $0) } ?? "no TSS"
            print("   \(formatter.string(from: ride.date)): \(ride.formattedDistance), \(ride.formattedDuration), \(tssStr)")
        }
        print("🚴 ===================")

        trainingLoadManager.debugPrintMetrics()
    }
}

