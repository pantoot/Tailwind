import Foundation
import CoreLocation

// Represents a detected/saved route segment
struct RouteSegment: Identifiable, Codable {
    let id: UUID
    var name: String
    var distance: Double // miles
    var simplifiedCoordinates: [SimpleCoordinate] // Reduced for matching
    var allRides: [RouteRideStats] // All rides on this route

    init(id: UUID = UUID(), name: String, distance: Double, coordinates: [CLLocationCoordinate2D]) {
        self.id = id
        self.name = name
        self.distance = distance
        self.simplifiedCoordinates = RouteSegment.simplifyRoute(coordinates)
        self.allRides = []
    }

    // Statistics computed from all rides
    var bestTime: TimeInterval? {
        allRides.map { $0.duration }.min()
    }

    var averageTime: TimeInterval {
        guard !allRides.isEmpty else { return 0 }
        return allRides.map { $0.duration }.reduce(0, +) / Double(allRides.count)
    }

    var bestSpeed: Double? {
        allRides.map { $0.averageSpeed }.max()
    }

    var averageSpeed: Double {
        guard !allRides.isEmpty else { return 0 }
        return allRides.map { $0.averageSpeed }.reduce(0, +) / Double(allRides.count)
    }

    var rideCount: Int {
        allRides.count
    }

    var lastRideDate: Date? {
        allRides.map { $0.date }.max()
    }

    // Add a ride to this route's history
    mutating func addRide(_ ride: Ride) {
        let stats = RouteRideStats(
            rideId: ride.id,
            date: ride.date,
            duration: ride.duration,
            averageSpeed: ride.averageSpeed,
            maxSpeed: ride.maxSpeed,
            averageHeartRate: Int(ride.averageHeartRate),
            calories: ride.calories
        )
        allRides.append(stats)
        allRides.sort { $0.date > $1.date } // Most recent first
    }

    // Douglas-Peucker algorithm to simplify route for matching
    // Reduces GPS noise and creates a cleaner route signature
    static func simplifyRoute(_ coordinates: [CLLocationCoordinate2D], tolerance: Double = 0.0001) -> [SimpleCoordinate] {
        guard coordinates.count > 2 else {
            return coordinates.map { SimpleCoordinate(latitude: $0.latitude, longitude: $0.longitude) }
        }

        // Find the point with maximum distance from line between first and last
        var maxDistance = 0.0
        var maxIndex = 0
        let start = coordinates.first!
        let end = coordinates.last!

        for i in 1..<coordinates.count - 1 {
            let distance = perpendicularDistance(point: coordinates[i], lineStart: start, lineEnd: end)
            if distance > maxDistance {
                maxDistance = distance
                maxIndex = i
            }
        }

        // If max distance is greater than tolerance, recursively simplify
        if maxDistance > tolerance {
            let leftSegment = simplifyRoute(Array(coordinates[0...maxIndex]), tolerance: tolerance)
            let rightSegment = simplifyRoute(Array(coordinates[maxIndex..<coordinates.count]), tolerance: tolerance)
            return leftSegment + rightSegment.dropFirst()
        } else {
            return [
                SimpleCoordinate(latitude: start.latitude, longitude: start.longitude),
                SimpleCoordinate(latitude: end.latitude, longitude: end.longitude)
            ]
        }
    }

    // Calculate perpendicular distance from point to line
    private static func perpendicularDistance(point: CLLocationCoordinate2D, lineStart: CLLocationCoordinate2D, lineEnd: CLLocationCoordinate2D) -> Double {
        let x0 = point.latitude
        let y0 = point.longitude
        let x1 = lineStart.latitude
        let y1 = lineStart.longitude
        let x2 = lineEnd.latitude
        let y2 = lineEnd.longitude

        let numerator = abs((y2 - y1) * x0 - (x2 - x1) * y0 + x2 * y1 - y2 * x1)
        let denominator = sqrt(pow(y2 - y1, 2) + pow(x2 - x1, 2))

        return denominator == 0 ? 0 : numerator / denominator
    }

    // Check if a given route matches this segment
    func matches(_ coordinates: [CLLocationCoordinate2D], threshold: Double = 0.001) -> Bool {
        let simplified = RouteSegment.simplifyRoute(coordinates)

        // Routes must have similar number of key points
        guard abs(simplified.count - simplifiedCoordinates.count) <= simplified.count / 3 else {
            return false
        }

        // Check if coordinates are generally close
        var matchingPoints = 0
        for coord in simplified {
            for savedCoord in simplifiedCoordinates {
                let distance = coord.distance(to: savedCoord)
                if distance < threshold {
                    matchingPoints += 1
                    break
                }
            }
        }

        // Require at least 70% of points to match
        let matchPercentage = Double(matchingPoints) / Double(simplified.count)
        return matchPercentage >= 0.7
    }
}

// Stats for a single ride on this route
struct RouteRideStats: Codable, Identifiable {
    let id: UUID
    let rideId: UUID
    let date: Date
    let duration: TimeInterval
    let averageSpeed: Double
    let maxSpeed: Double
    let averageHeartRate: Int
    let calories: Double

    init(id: UUID = UUID(), rideId: UUID, date: Date, duration: TimeInterval, averageSpeed: Double, maxSpeed: Double, averageHeartRate: Int, calories: Double) {
        self.id = id
        self.rideId = rideId
        self.date = date
        self.duration = duration
        self.averageSpeed = averageSpeed
        self.maxSpeed = maxSpeed
        self.averageHeartRate = averageHeartRate
        self.calories = calories
    }
}

// Codable coordinate
struct SimpleCoordinate: Codable {
    let latitude: Double
    let longitude: Double

    func distance(to other: SimpleCoordinate) -> Double {
        let lat1 = latitude
        let lon1 = longitude
        let lat2 = other.latitude
        let lon2 = other.longitude

        return sqrt(pow(lat2 - lat1, 2) + pow(lon2 - lon1, 2))
    }
}
