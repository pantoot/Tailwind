import SwiftUI
import Combine
import CoreLocation

@main
struct TailwindApp: App {
    @StateObject private var services = AppServices()

    var body: some Scene {
        WindowGroup {
            ImportView()
                .environmentObject(services.fitImportService)
                .environmentObject(services.rideHistory)
                .environmentObject(services.healthKitService)
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
                .onAppear {
                    processPendingImports()
                }
        }
    }

    /// Handle URLs from share extension or other apps
    private func handleIncomingURL(_ url: URL) {
        // Handle tailwind:// URL scheme
        if url.scheme == "tailwind" && url.host == "import" {
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let fileParam = components.queryItems?.first(where: { $0.name == "file" })?.value,
               let filePath = fileParam.removingPercentEncoding {
                let fileURL = URL(fileURLWithPath: filePath)
                Task {
                    do {
                        _ = try await services.fitImportService.importFITFile(from: fileURL)
                        // Clean up the temp file after import
                        try? FileManager.default.removeItem(at: fileURL)
                    } catch {
                        print("Failed to import from URL: \(error)")
                    }
                }
            }
        }
        // Handle direct FIT file opens
        else if url.pathExtension.lowercased() == "fit" {
            Task {
                do {
                    _ = try await services.fitImportService.importFITFile(from: url)
                } catch {
                    print("Failed to import FIT file: \(error)")
                }
            }
        }
    }

    /// Process any FIT files shared via the extension while app was closed
    private func processPendingImports() {
        guard let defaults = UserDefaults(suiteName: "group.com.tailwind.app") else { return }
        guard let pendingPaths = defaults.stringArray(forKey: "pendingFITImports"), !pendingPaths.isEmpty else { return }

        // Clear the pending list
        defaults.removeObject(forKey: "pendingFITImports")

        // Import each pending file
        Task {
            for path in pendingPaths {
                let url = URL(fileURLWithPath: path)
                guard FileManager.default.fileExists(atPath: path) else { continue }

                do {
                    _ = try await services.fitImportService.importFITFile(from: url)
                    // Clean up after successful import
                    try? FileManager.default.removeItem(at: url)
                    print("Processed pending import: \(url.lastPathComponent)")
                } catch {
                    print("Failed pending import: \(error)")
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

    init() {
        // Initialize core services
        self.rideHistory = RideHistory()
        self.healthKitService = HealthKitService()

        // FIT import service depends on HealthKit and RideHistory
        self.fitImportService = FITImportService(
            healthKitService: healthKitService,
            rideHistory: rideHistory
        )

        print("🚀 Tailwind initialized - FIT Import Mode")
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
