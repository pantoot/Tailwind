import SwiftUI
import Combine
import CoreLocation

@main
struct TailwindApp: App {
    @StateObject private var services = AppServices()
    @Environment(\.scenePhase) private var scenePhase

    /// Track if we're handling a URL import (prevents race with pending imports)
    @State private var isHandlingURLImport = false

    var body: some Scene {
        WindowGroup {
            TabView {
                ImportView()
                    .tabItem { Label("Dashboard", systemImage: "chart.bar.fill") }

                CreatineFocusView()
                    .tabItem { Label("Creatine", systemImage: "bolt.fill") }
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

                        // Clean up the temp file after import
                        try? FileManager.default.removeItem(at: fileURL)
                    } catch {
                        print("❌ Failed to import from URL: \(error)")
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
                } catch {
                    print("❌ Failed to import FIT file: \(error)")
                }
            }
        } else {
            print("⚠️ Unhandled URL scheme/type")
        }
    }

    /// Remove a specific file from pending imports (to prevent double-import)
    private func clearPendingImport(path: String) {
        guard let defaults = UserDefaults(suiteName: "group.com.rick.Tailwind") else { return }
        var pending = defaults.stringArray(forKey: "pendingFITImports") ?? []
        if let index = pending.firstIndex(of: path) {
            pending.remove(at: index)
            defaults.set(pending, forKey: "pendingFITImports")
            print("📥 Cleared \(path) from pending imports")
        }
    }

    /// Process any FIT files shared via the extension while app was closed
    private func processPendingImports() {
        print("📋 Checking for pending imports...")
        guard let defaults = UserDefaults(suiteName: "group.com.rick.Tailwind") else {
            print("❌ Could not access App Group defaults")
            return
        }
        guard let pendingPaths = defaults.stringArray(forKey: "pendingFITImports"), !pendingPaths.isEmpty else {
            print("📋 No pending imports found")
            return
        }

        print("📋 Found \(pendingPaths.count) pending imports: \(pendingPaths)")

        // Clear the pending list
        defaults.removeObject(forKey: "pendingFITImports")

        // Import each pending file
        Task {
            for path in pendingPaths {
                let url = URL(fileURLWithPath: path)
                print("📋 Processing: \(path)")
                print("📋 File exists: \(FileManager.default.fileExists(atPath: path))")

                guard FileManager.default.fileExists(atPath: path) else {
                    print("⚠️ File not found, skipping: \(path)")
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

                    // Clean up after successful import
                    try? FileManager.default.removeItem(at: url)
                    print("✅ Processed pending import: \(ride.formattedDate), \(ride.formattedDistance)")
                } catch {
                    print("❌ Failed pending import: \(error)")
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

// MARK: - Legacy AppServices (preserved for reference)
// The original ride-tracking services are preserved below for potential future use
// or if we want to add a hybrid mode that supports both import and live tracking.

/*
class LegacyAppServices: ObservableObject {
    let bluetoothService: BluetoothService
    let sensorDataService: SensorDataService
    let gpsService: GPSService
    let rideHistory: RideHistory
    let bikeStable: BikeStable
    let trainingLoadManager: TrainingLoadManager
    let healthKitService: HealthKitService
    let backgroundAudioService: BackgroundAudioService
    let routeMatchingService: RouteMatchingService
    let segmentManager: SegmentManager
    let audioCueService: AudioCueService
    let phoneConnectivity: PhoneConnectivityManager

    init() {
        // Initialize all services first
        self.bluetoothService = BluetoothService()
        self.sensorDataService = SensorDataService()
        self.gpsService = GPSService()
        self.rideHistory = RideHistory()
        self.bikeStable = BikeStable()
        self.trainingLoadManager = TrainingLoadManager()
        self.healthKitService = HealthKitService()
        self.backgroundAudioService = BackgroundAudioService()
        self.routeMatchingService = RouteMatchingService()
        self.segmentManager = SegmentManager()
        self.audioCueService = AudioCueService()
        self.phoneConnectivity = PhoneConnectivityManager()

        // Wire up callbacks after all services are created
        // Bluetooth -> Sensor Data
        self.bluetoothService.onSpeedUpdate = { [weak sensorDataService] speed in
            sensorDataService?.updateSpeed(speed, fromSensor: true)
        }

        self.bluetoothService.onCadenceUpdate = { [weak sensorDataService] cadence in
            sensorDataService?.updateCadence(cadence)
        }

        self.bluetoothService.onHeartRateUpdate = { [weak sensorDataService] heartRate in
            sensorDataService?.updateHeartRate(heartRate)
        }

        // GPS -> Sensor Data (backup speed)
        self.gpsService.onSpeedUpdate = { [weak sensorDataService, weak bluetoothService] gpsSpeed in
            // Only use GPS speed if we don't have a connected speed sensor
            guard let sensorData = sensorDataService,
                  let bluetooth = bluetoothService else { return }

            // Check if we have an active speed sensor (not just if speed is 0)
            let hasSpeedSensor = bluetooth.isConnected(.speed)

            if !hasSpeedSensor {
                sensorData.updateSpeed(gpsSpeed)
            }
        }

        // GPS -> Route Matching (track coordinates for route detection)
        self.gpsService.onLocationUpdate = { [weak routeMatchingService, weak segmentManager] location in
            routeMatchingService?.addCoordinate(location.coordinate)

            // Segment detection
            segmentManager?.checkForSegmentStart(location.coordinate)
            segmentManager?.checkForSegmentEnd(location.coordinate)
            segmentManager?.updateActiveEffort(coordinate: location.coordinate)
        }

        // Bike Selection -> Auto-connect sensors
        self.bikeStable.onBikeChanged = { [weak bluetoothService, weak bikeStable] bike in
            guard let bluetoothService = bluetoothService,
                  let bikeStable = bikeStable else { return }

            print("🚴 Bike changed to: \(bike.name)")
            bluetoothService.disconnectBikeSensors()

            for (_, sensor) in bikeStable.profileSensors {
                bluetoothService.connectToPeripheral(withId: sensor.id, type: sensor.type)
            }

            for (_, sensor) in bike.assignedSensors {
                bluetoothService.connectToPeripheral(withId: sensor.id, type: sensor.type)
            }
        }

        // Auto-connect sensors for initially selected bike
        if let initialBike = bikeStable.selectedBike {
            for (_, sensor) in bikeStable.profileSensors {
                bluetoothService.connectToPeripheral(withId: sensor.id, type: sensor.type)
            }

            for (_, sensor) in initialBike.assignedSensors {
                bluetoothService.connectToPeripheral(withId: sensor.id, type: sensor.type)
            }
        }

        // Watch Connectivity
        phoneConnectivity.activateSession()

        phoneConnectivity.onStartRide = { [weak phoneConnectivity] in
            print("📱 iPhone: Watch requested start ride")
            DispatchQueue.main.async {
                phoneConnectivity?.watchRequestsStartRide.toggle()
            }
        }

        phoneConnectivity.onStopRide = { [weak phoneConnectivity] in
            print("📱 iPhone: Watch requested stop ride")
            DispatchQueue.main.async {
                phoneConnectivity?.watchRequestsStopRide.toggle()
            }
        }

        phoneConnectivity.onToggleAudio = { [weak audioCueService] in
            audioCueService?.audioEnabled.toggle()
        }

        setupWatchHeartRate()
    }

    func setupWatchHeartRate() {
        phoneConnectivity.$watchHeartRate
            .sink { [weak sensorDataService] watchHR in
                if watchHR > 0 {
                    sensorDataService?.updateWatchHeartRate(watchHR)
                }
            }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()
}
*/
