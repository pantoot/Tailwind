import Foundation
import Combine

class SensorDataService: ObservableObject {
    @Published var sensorData = SensorData()
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var userProfile = UserProfile.load()

    private var timer: Timer?
    private var startTime: Date?
    private var lastSpeedUpdate: Date?
    private var lastCalorieUpdate: Date?
    private var lastHeartRateUpdate: Date? // Track when we last got HR data
    private var pausedTime: TimeInterval = 0 // Total time spent paused
    private var pauseStartTime: Date? // When current pause started

    // Stale data timeout - if no HR update in 10 seconds, clear display
    private let hrStaleTimeout: TimeInterval = 10.0

    // Track max values during ride
    private var maxSpeed: Double = 0.0
    private var maxHeartRate: Int = 0

    // Track time in zones
    private var timeInZone = TimeInZone()
    private var lastZoneUpdate: Date?
    private var lastHeartRate: Int = 0

    // Auto-pause settings
    var autoPauseEnabled = true
    private let autoPauseSpeedThreshold = 0.5 // mph - pause when below this speed
    private let autoPauseDelay = 3.0 // seconds - delay before auto-pausing

    func startRecording() {
        isRecording = true
        isPaused = false
        startTime = Date()
        lastZoneUpdate = Date()
        timeInZone = TimeInZone()
        pausedTime = 0
        pauseStartTime = nil

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateDuration()
            self?.updateTimeInZone()
        }
    }

    func stopRecording(gpsRoute: [Ride.Coordinate]? = nil, elevationGain: Double? = nil) -> Ride? {
        isRecording = false
        isPaused = false
        timer?.invalidate()
        timer = nil
        startTime = nil
        lastZoneUpdate = nil
        pauseStartTime = nil

        // Create ride object if there was actual activity
        guard sensorData.duration > 60 else { return nil } // At least 1 minute

        // Calculate hrTSS
        let hrTSS = timeInZone.calculateHrTSS()

        let ride = Ride(
            duration: sensorData.duration,
            distance: sensorData.distance,
            averageSpeed: sensorData.averageSpeed,
            maxSpeed: maxSpeed,
            averageHeartRate: sensorData.averageHeartRate,
            maxHeartRate: maxHeartRate,
            calories: sensorData.calories,
            elevationGain: elevationGain,
            routeCoordinates: gpsRoute,
            timeInZone: timeInZone,
            hrTSS: hrTSS
        )

        return ride
    }

    func resetData() {
        sensorData = SensorData()
        maxSpeed = 0.0
        maxHeartRate = 0
        timeInZone = TimeInZone()
        lastZoneUpdate = nil
        lastHeartRate = 0
        if isRecording {
            _ = stopRecording()
        }
    }

    func updateSpeed(_ speed: Double) {
        sensorData.speed = speed

        // Handle auto-pause
        if isRecording && autoPauseEnabled {
            if speed < autoPauseSpeedThreshold {
                // Speed is low - start pause timer if not already paused
                if !isPaused && pauseStartTime == nil {
                    pauseStartTime = Date()
                } else if !isPaused, let pauseStart = pauseStartTime {
                    // Check if we've been below threshold long enough
                    if Date().timeIntervalSince(pauseStart) >= autoPauseDelay {
                        isPaused = true
                        print("🛑 Auto-paused at \(String(format: "%.1f", speed)) mph")
                    }
                }
            } else {
                // Speed is above threshold
                if isPaused {
                    // Resume from pause
                    isPaused = false
                    if let pauseStart = pauseStartTime {
                        pausedTime += Date().timeIntervalSince(pauseStart)
                    }
                    pauseStartTime = nil
                    print("▶️ Auto-resumed at \(String(format: "%.1f", speed)) mph")
                }
                // Reset pause timer
                pauseStartTime = nil
            }
        }

        // Track max speed
        if speed > maxSpeed {
            maxSpeed = speed
        }

        // Update distance based on speed (only when not paused)
        if !isPaused, let lastUpdate = lastSpeedUpdate {
            let timeDelta = Date().timeIntervalSince(lastUpdate)
            let distanceDelta = speed * (timeDelta / 3600) // Convert to miles
            sensorData.distance += distanceDelta
        }

        lastSpeedUpdate = Date()
    }

    func updateCadence(_ cadence: Int) {
        sensorData.cadence = cadence
    }

    func updateHeartRate(_ heartRate: Int) {
        // Validate HR is in reasonable range
        guard heartRate >= 30 && heartRate <= 220 else {
            print("⚠️ Invalid HR value: \(heartRate) - ignoring")
            return
        }

        sensorData.heartRate = heartRate
        lastHeartRateUpdate = Date() // Track when we got this update

        // Track max heart rate
        if heartRate > maxHeartRate {
            maxHeartRate = heartRate
        }

        // Store for zone tracking
        if isRecording && heartRate > 0 {
            lastHeartRate = heartRate
        }

        // Track for average HR calculation
        if isRecording && heartRate > 0 {
            sensorData.totalHeartRateSum += Double(heartRate)
            sensorData.heartRateSampleCount += 1
            // Calorie updates now happen in updateDuration() every 5 seconds
        }
    }

    private func updateCalories() {
        guard sensorData.duration > 0 else { return }

        let durationMinutes = sensorData.duration / 60.0

        // Use actual average HR if available, otherwise use baseline of 135 bpm
        let hrForCalories = sensorData.averageHeartRate > 0 ? sensorData.averageHeartRate : 135.0

        if sensorData.averageHeartRate == 0 {
            print("⚠️ No HR data available - using baseline 135 bpm for calorie calculation")
        }

        sensorData.calories = userProfile.calculateCalories(
            averageHeartRate: hrForCalories,
            durationMinutes: durationMinutes
        )
    }

    func updatePower(_ power: Int) {
        sensorData.power = power
    }

    private func updateDuration() {
        guard let start = startTime else { return }

        // Calculate elapsed time minus paused time
        var elapsed = Date().timeIntervalSince(start) - pausedTime

        // If currently paused, also subtract current pause duration
        if isPaused, let pauseStart = pauseStartTime {
            elapsed -= Date().timeIntervalSince(pauseStart)
        }

        sensorData.duration = elapsed

        // Check for stale HR data - clear if no update in 10 seconds during recording
        if isRecording,
           let lastHR = lastHeartRateUpdate,
           Date().timeIntervalSince(lastHR) > hrStaleTimeout,
           sensorData.heartRate != 0 {
            print("⚠️ No HR data for \(Int(Date().timeIntervalSince(lastHR)))s - clearing display")
            sensorData.heartRate = 0
        }

        // Update calories every 5 seconds even if no HR updates (uses baseline)
        let now = Date()
        if lastCalorieUpdate == nil || now.timeIntervalSince(lastCalorieUpdate!) >= 5.0 {
            updateCalories()
            lastCalorieUpdate = now
        }
    }

    private func updateTimeInZone() {
        guard isRecording,
              !isPaused, // Don't update zones when paused
              lastHeartRate > 0,
              let lthr = userProfile.lactateThresholdHR,
              let lastUpdate = lastZoneUpdate else {
            return
        }

        // Calculate time since last update
        let now = Date()
        let timeDelta = now.timeIntervalSince(lastUpdate)

        // Determine which zone we're in
        let zones = HeartRateZones(lthr: lthr)
        let currentZone = zones.zone(for: lastHeartRate)

        // Add time to that zone
        timeInZone.add(seconds: timeDelta, for: currentZone)

        lastZoneUpdate = now
    }

    // Get current HR zone for display
    func getCurrentZone() -> HeartRateZones.Zone? {
        guard let lthr = userProfile.lactateThresholdHR, lastHeartRate > 0 else {
            return nil
        }
        let zones = HeartRateZones(lthr: lthr)
        return zones.zone(for: lastHeartRate)
    }
}
