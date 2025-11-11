import SwiftUI
import Combine
import CoreLocation

@main
struct TailwindApp: App {
    @StateObject private var services = AppServices()

    var body: some Scene {
        WindowGroup {
            TabbedContentView()
                .environmentObject(services.bluetoothService)
                .environmentObject(services.sensorDataService)
                .environmentObject(services.gpsService)
                .environmentObject(services.rideHistory)
                .environmentObject(services.bikeStable)
                .environmentObject(services.trainingLoadManager)
                .environmentObject(services.healthKitService)
                .environmentObject(services.backgroundAudioService)
                .environmentObject(services.routeMatchingService)
                .environmentObject(services.segmentManager)
                .environmentObject(services.audioCueService)
                .environmentObject(services.phoneConnectivity)
        }
    }
}

// Container to manage service lifecycle and wiring
class AppServices: ObservableObject {
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
            sensorDataService?.updateSpeed(speed)
        }

        self.bluetoothService.onCadenceUpdate = { [weak sensorDataService] cadence in
            sensorDataService?.updateCadence(cadence)
        }

        self.bluetoothService.onHeartRateUpdate = { [weak sensorDataService] heartRate in
            sensorDataService?.updateHeartRate(heartRate)
        }

        // GPS -> Sensor Data (backup speed)
        self.gpsService.onSpeedUpdate = { [weak sensorDataService] gpsSpeed in
            // Only use GPS speed if we don't have sensor speed
            if let sensorData = sensorDataService, sensorData.sensorData.speed == 0 {
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

        // Distance -> Audio Cues (check for 5-mile splits)
        // We'll trigger this from MainView when distance updates

        // Bike Selection -> Auto-connect sensors
        self.bikeStable.onBikeChanged = { [weak bluetoothService, weak bikeStable] bike in
            guard let bluetoothService = bluetoothService,
                  let bikeStable = bikeStable else { return }

            print("🚴 Bike changed to: \(bike.name)")

            // Disconnect previous bike's sensors (keep profile sensors)
            bluetoothService.disconnectBikeSensors()

            // Connect profile sensors if not already connected
            for (_, sensor) in bikeStable.profileSensors {
                bluetoothService.connectToPeripheral(withId: sensor.id, type: sensor.type)
            }

            // Connect this bike's sensors
            for (_, sensor) in bike.assignedSensors {
                bluetoothService.connectToPeripheral(withId: sensor.id, type: sensor.type)
            }
        }

        // Auto-connect sensors for initially selected bike
        if let initialBike = bikeStable.selectedBike {
            // Connect profile sensors
            for (_, sensor) in bikeStable.profileSensors {
                bluetoothService.connectToPeripheral(withId: sensor.id, type: sensor.type)
            }

            // Connect bike sensors
            for (_, sensor) in initialBike.assignedSensors {
                bluetoothService.connectToPeripheral(withId: sensor.id, type: sensor.type)
            }
        }

        // Watch Connectivity -> Control iPhone app
        phoneConnectivity.activateSession()

        phoneConnectivity.onStartRide = {
            print("📱 iPhone: Watch requested start ride")
            // Will be handled by MainView's handleStartStop when we wire it up
        }

        phoneConnectivity.onStopRide = {
            print("📱 iPhone: Watch requested stop ride")
            // Will be handled by MainView's handleStartStop when we wire it up
        }

        phoneConnectivity.onToggleAudio = { [weak audioCueService] in
            print("📱 iPhone: Watch requested toggle audio")
            audioCueService?.audioEnabled.toggle()
        }

        // Set up watch heart rate streaming to sensor data
        setupWatchHeartRate()

        // We'll send updates to watch from MainView when data changes
    }

    // Set up watch heart rate forwarding
    func setupWatchHeartRate() {
        // Subscribe to watch HR updates
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
