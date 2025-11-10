import Foundation
import CoreLocation
import CoreMotion
import Combine

class GPSService: NSObject, ObservableObject {
    @Published var currentLocation: CLLocation?
    @Published var currentSpeed: Double = 0.0 // mph from GPS
    @Published var currentAltitude: Double = 0.0 // feet
    @Published var totalElevationGain: Double = 0.0 // feet
    @Published var isTracking = false
    @Published var locationPermission: CLAuthorizationStatus = .notDetermined
    @Published var routeCoordinates: [CLLocationCoordinate2D] = []

    private let locationManager = CLLocationManager()
    private var lastAltitude: Double?

    // Track full location data for speed heatmap
    private var routeLocations: [CLLocation] = []

    // Motion detection to filter GPS drift
    private let motionManager = CMMotionManager()
    private var isDeviceMoving: Bool = false
    private let motionQueue = OperationQueue()
    private let movementThreshold: Double = 0.1 // m/s² acceleration threshold

    // Callbacks
    var onLocationUpdate: ((CLLocation) -> Void)?
    var onSpeedUpdate: ((Double) -> Void)? // GPS speed as backup

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5 // Update every 5 meters
        locationManager.activityType = .fitness
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.showsBackgroundLocationIndicator = true // Show blue bar when tracking in background
        locationManager.allowsBackgroundLocationUpdates = true // Enable background GPS

        locationPermission = locationManager.authorizationStatus

        // Don't start motion detection until tracking begins
    }

    private func setupMotionDetection() {
        guard motionManager.isAccelerometerAvailable else {
            print("GPS: Accelerometer not available")
            return
        }

        motionManager.accelerometerUpdateInterval = 0.5 // Check twice per second
        motionManager.startAccelerometerUpdates(to: motionQueue) { [weak self] (data, error) in
            guard let self = self, let data = data else { return }

            // Calculate total acceleration (magnitude)
            let x = data.acceleration.x
            let y = data.acceleration.y
            let z = data.acceleration.z
            let totalAcceleration = sqrt(x*x + y*y + z*z)

            // Subtract gravity (1G = 9.8 m/s²) to get movement acceleration
            let movementAcceleration = abs(totalAcceleration - 1.0)

            // If acceleration exceeds threshold, device is moving
            self.isDeviceMoving = movementAcceleration > self.movementThreshold

            if movementAcceleration > 0.05 {
                print("📱 Motion: \(String(format: "%.3f", movementAcceleration)) m/s² - Moving: \(self.isDeviceMoving)")
            }
        }

        print("GPS: Motion detection started")
    }

    func requestPermission() {
        // Request "Always" permission for background tracking
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if locationManager.authorizationStatus == .authorizedWhenInUse {
            locationManager.requestAlwaysAuthorization()
        }
    }

    func startTracking() {
        guard locationManager.authorizationStatus == .authorizedWhenInUse ||
              locationManager.authorizationStatus == .authorizedAlways else {
            print("GPS: Location permission not granted")
            requestPermission()
            return
        }

        isTracking = true
        routeCoordinates.removeAll()
        routeLocations.removeAll()
        totalElevationGain = 0.0
        lastAltitude = nil

        // Start motion detection only when tracking begins
        setupMotionDetection()

        locationManager.startUpdatingLocation()
        print("GPS: Started tracking")
    }

    func stopTracking() {
        isTracking = false
        locationManager.stopUpdatingLocation()

        // Stop motion detection to save battery and memory
        motionManager.stopAccelerometerUpdates()
        isDeviceMoving = false

        print("GPS: Stopped tracking")
    }

    deinit {
        motionManager.stopAccelerometerUpdates()
    }

    func getRoute() -> [CLLocationCoordinate2D] {
        return routeCoordinates
    }

    func clearRoute() {
        routeCoordinates.removeAll()
        routeLocations.removeAll()
        totalElevationGain = 0.0
        lastAltitude = nil
    }

    // Calculate mile markers along the route
    func getMileMarkers() -> [(coordinate: CLLocationCoordinate2D, mile: Int)] {
        var markers: [(coordinate: CLLocationCoordinate2D, mile: Int)] = []
        var cumulativeDistance: Double = 0.0 // miles
        var nextMilestone: Double = 1.0 // Next mile marker to place

        for i in 1..<routeLocations.count {
            let previous = routeLocations[i - 1]
            let current = routeLocations[i]

            // Calculate distance between points in miles
            let segmentDistance = previous.distance(from: current) * 0.000621371 // meters to miles
            cumulativeDistance += segmentDistance

            // Check if we've passed a mile marker
            if cumulativeDistance >= nextMilestone {
                markers.append((coordinate: current.coordinate, mile: Int(nextMilestone)))
                nextMilestone += 1.0
            }
        }

        return markers
    }

    // Get speed data for heatmap coloring
    func getSpeedData() -> [(coordinate: CLLocationCoordinate2D, speed: Double)] {
        return routeLocations.map { location in
            let speedMPH = location.speed >= 0 ? location.speed * 2.23694 : 0.0
            return (coordinate: location.coordinate, speed: speedMPH)
        }
    }

    private func calculateElevationGain(newAltitude: Double) {
        guard let last = lastAltitude else {
            lastAltitude = newAltitude
            return
        }

        // Only count uphill changes > 3 feet (filter out GPS noise)
        let change = newAltitude - last
        if change > 3.0 {
            totalElevationGain += change
        }

        lastAltitude = newAltitude
    }
}

// MARK: - CLLocationManagerDelegate
extension GPSService: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        locationPermission = manager.authorizationStatus
        print("GPS: Authorization status changed to \(manager.authorizationStatus.rawValue)")

        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            if isTracking {
                locationManager.startUpdatingLocation()
            }
        case .denied, .restricted:
            print("GPS: Location access denied")
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        // Filter out inaccurate readings (even tighter threshold)
        guard location.horizontalAccuracy > 0 && location.horizontalAccuracy <= 10 else {
            print("GPS: Location accuracy too low: \(location.horizontalAccuracy)m - rejecting")
            return
        }

        // Filter out stale locations (older than 10 seconds)
        guard location.timestamp.timeIntervalSinceNow > -10 else {
            print("GPS: Location too old - rejecting")
            return
        }

        currentLocation = location

        // Update altitude (convert meters to feet)
        if location.verticalAccuracy >= 0 && location.verticalAccuracy <= 30 {
            let altitudeFeet = location.altitude * 3.28084
            currentAltitude = altitudeFeet
            calculateElevationGain(newAltitude: altitudeFeet)
        }

        // Update GPS speed (convert m/s to mph)
        // Only use speed if:
        // 1. Speed is valid (>= 0)
        // 2. Speed accuracy is good (iOS provides this via location.speedAccuracy)
        // 3. Device is actually moving (accelerometer confirms)
        // 4. Speed is above GPS drift threshold (2.5 mph)
        if location.speed >= 0 {
            let speedMPH = location.speed * 2.23694

            // Additional speed accuracy check (if available on iOS version)
            let hasGoodSpeedAccuracy = location.speedAccuracy >= 0 && location.speedAccuracy <= 5.0

            // Filter GPS drift using motion detection + speed thresholds
            let filteredSpeed: Double
            if !isDeviceMoving && speedMPH < 3.0 {
                // Device not moving and low speed = GPS drift, show 0
                filteredSpeed = 0.0
            } else if hasGoodSpeedAccuracy && speedMPH > 1.0 {
                // Good accuracy and moving = trust the speed
                filteredSpeed = speedMPH
            } else if speedMPH > 2.5 {
                // Speed above drift threshold = probably real
                filteredSpeed = speedMPH
            } else {
                // Everything else = likely drift
                filteredSpeed = 0.0
            }

            // Always update speed (even when 0.0) to clear the display
            currentSpeed = filteredSpeed
            onSpeedUpdate?(filteredSpeed)

            if filteredSpeed > 0 || speedMPH > 0.5 {
                print("GPS: Speed=\(String(format: "%.1f", speedMPH)) mph, Accuracy=\(location.horizontalAccuracy)m, SpeedAccuracy=\(location.speedAccuracy), Motion=\(isDeviceMoving), Filtered=\(String(format: "%.1f", filteredSpeed))")
            }
        }

        // Add to route
        if isTracking {
            routeCoordinates.append(location.coordinate)
            routeLocations.append(location)
        }

        // Callback
        onLocationUpdate?(location)

        print("GPS: Location updated - Speed: \(String(format: "%.1f", currentSpeed)) mph, Alt: \(String(format: "%.0f", currentAltitude)) ft, Accuracy: \(location.horizontalAccuracy)m")
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("GPS: Location error: \(error.localizedDescription)")
    }
}
