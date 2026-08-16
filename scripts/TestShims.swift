import Foundation

// Harness-only shim. TrainingLoad.swift references Ride, but the real
// Ride.swift drags in CoreLocation, CreatineMetrics, and the route-track
// store — none of which the pure-logic tests exercise. TrainingLoadManager
// only reads `date` and `hrTSS` from a ride, so the shim declares exactly
// that surface. If TrainingLoad.swift ever reads more of Ride, this shim
// fails to compile — which is the correct signal to widen it.
struct Ride {
    let date: Date
    let hrTSS: Double?
}
