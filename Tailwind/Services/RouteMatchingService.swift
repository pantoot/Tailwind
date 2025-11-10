import Foundation
import CoreLocation
import Combine

class RouteMatchingService: ObservableObject {
    @Published var detectedRoute: RouteSegment?
    @Published var currentProgress: RouteProgress?
    @Published var savedRoutes: [RouteSegment] = []

    private let storageKey = "savedRoutes"
    private var currentRideCoordinates: [CLLocationCoordinate2D] = []

    init() {
        loadRoutes()
    }

    // Start tracking a new ride
    func startRide() {
        currentRideCoordinates.removeAll()
        detectedRoute = nil
        currentProgress = nil
    }

    // Add coordinate during ride
    func addCoordinate(_ coordinate: CLLocationCoordinate2D) {
        currentRideCoordinates.append(coordinate)

        // Try to detect route after we have enough data points
        if currentRideCoordinates.count == 20 {
            attemptRouteDetection()
        }

        // Update progress if we've detected a route
        if let route = detectedRoute {
            updateProgress(for: route)
        }
    }

    // Try to match current ride to saved routes
    private func attemptRouteDetection() {
        for route in savedRoutes {
            if route.matches(currentRideCoordinates) {
                print("🎯 Route detected: \(route.name)")
                detectedRoute = route
                currentProgress = RouteProgress(route: route)
                return
            }
        }
        print("📍 No matching route found yet")
    }

    // Update progress along detected route
    private func updateProgress(for route: RouteSegment) {
        guard currentRideCoordinates.count > 1 else { return }

        // Calculate current distance traveled
        var distance = 0.0
        for i in 1..<currentRideCoordinates.count {
            let loc1 = CLLocation(
                latitude: currentRideCoordinates[i-1].latitude,
                longitude: currentRideCoordinates[i-1].longitude
            )
            let loc2 = CLLocation(
                latitude: currentRideCoordinates[i].latitude,
                longitude: currentRideCoordinates[i].longitude
            )
            distance += loc2.distance(from: loc1) / 1609.34 // Convert to miles
        }

        let percentComplete = (distance / route.distance) * 100

        currentProgress = RouteProgress(
            route: route,
            distanceTraveled: distance,
            percentComplete: min(percentComplete, 100)
        )
    }

    // End ride and potentially save as new route or add to existing
    func endRide(_ ride: Ride, coordinates: [CLLocationCoordinate2D]) {
        guard coordinates.count > 10 else { return }

        if let detected = detectedRoute {
            // Add this ride to the detected route
            if let index = savedRoutes.firstIndex(where: { $0.id == detected.id }) {
                savedRoutes[index].addRide(ride)
                print("✅ Added ride to route: \(detected.name)")
                saveRoutes()
            }
        } else {
            // Check if this should be a new route
            if ride.distance > 0.5 { // At least 0.5 miles
                createNewRoute(from: ride, coordinates: coordinates)
            }
        }

        currentRideCoordinates.removeAll()
        detectedRoute = nil
        currentProgress = nil
    }

    // Create a new route from a ride
    private func createNewRoute(from ride: Ride, coordinates: [CLLocationCoordinate2D]) {
        let routeName = generateRouteName()
        var newRoute = RouteSegment(
            name: routeName,
            distance: ride.distance,
            coordinates: coordinates
        )
        newRoute.addRide(ride)
        savedRoutes.append(newRoute)
        saveRoutes()
        print("🆕 Created new route: \(routeName)")
    }

    // Generate a unique route name
    private func generateRouteName() -> String {
        let count = savedRoutes.count + 1
        return "Route \(count)"
    }

    // Manual route naming
    func renameRoute(_ routeId: UUID, newName: String) {
        if let index = savedRoutes.firstIndex(where: { $0.id == routeId }) {
            savedRoutes[index].name = newName
            saveRoutes()
        }
    }

    // Delete a route
    func deleteRoute(_ routeId: UUID) {
        savedRoutes.removeAll { $0.id == routeId }
        saveRoutes()
    }

    // MARK: - Persistence
    private func saveRoutes() {
        if let encoded = try? JSONEncoder().encode(savedRoutes) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    private func loadRoutes() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([RouteSegment].self, from: data) else {
            return
        }
        savedRoutes = decoded
        print("📂 Loaded \(savedRoutes.count) saved routes")
    }
}

// Current progress on a detected route
struct RouteProgress {
    let route: RouteSegment
    var distanceTraveled: Double = 0
    var percentComplete: Double = 0

    // Performance comparison
    var timeDelta: TimeInterval? {
        guard let _ = route.bestTime else { return nil }
        // We'll get actual elapsed time from the ride
        return nil // Will be calculated with actual ride time
    }

    var speedComparison: String {
        // This will be populated during live ride
        return ""
    }
}
