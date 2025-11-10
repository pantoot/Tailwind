import Foundation
import CoreLocation
import Combine

// A segment is a named section of a route (e.g., "Mesa Climb", "River Sprint")
struct Segment: Identifiable, Codable {
    let id: UUID
    let name: String
    let startCoordinate: Coordinate
    let endCoordinate: Coordinate
    let routeCoordinates: [Coordinate] // Full path of segment
    let distance: Double // miles
    let createdDate: Date

    // Best effort on this segment
    var bestTime: TimeInterval? // seconds
    var bestSpeed: Double? // mph
    var bestDate: Date?

    // Coordinate wrapper for Codable
    struct Coordinate: Codable, Equatable {
        let latitude: Double
        let longitude: Double

        init(latitude: Double, longitude: Double) {
            self.latitude = latitude
            self.longitude = longitude
        }

        init(from coordinate: CLLocationCoordinate2D) {
            self.latitude = coordinate.latitude
            self.longitude = coordinate.longitude
        }

        var clCoordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
    }

    init(id: UUID = UUID(),
         name: String,
         startCoordinate: Coordinate,
         endCoordinate: Coordinate,
         routeCoordinates: [Coordinate],
         distance: Double,
         createdDate: Date = Date(),
         bestTime: TimeInterval? = nil,
         bestSpeed: Double? = nil,
         bestDate: Date? = nil) {
        self.id = id
        self.name = name
        self.startCoordinate = startCoordinate
        self.endCoordinate = endCoordinate
        self.routeCoordinates = routeCoordinates
        self.distance = distance
        self.createdDate = createdDate
        self.bestTime = bestTime
        self.bestSpeed = bestSpeed
        self.bestDate = bestDate
    }

    // Check if a coordinate is near the start (within ~50 meters)
    func isNearStart(_ coordinate: CLLocationCoordinate2D) -> Bool {
        let start = CLLocation(latitude: startCoordinate.latitude, longitude: startCoordinate.longitude)
        let current = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return start.distance(from: current) < 50 // 50 meters
    }

    // Check if a coordinate is near the end (within ~50 meters)
    func isNearEnd(_ coordinate: CLLocationCoordinate2D) -> Bool {
        let end = CLLocation(latitude: endCoordinate.latitude, longitude: endCoordinate.longitude)
        let current = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return end.distance(from: current) < 50 // 50 meters
    }
}

// Segment effort - a single attempt at a segment
struct SegmentEffort: Identifiable {
    let id = UUID()
    let segmentId: UUID
    let startTime: Date
    var endTime: Date?
    var duration: TimeInterval {
        guard let end = endTime else { return 0 }
        return end.timeIntervalSince(startTime)
    }
    var averageSpeed: Double? // mph
    var coordinates: [CLLocationCoordinate2D] = []

    var isComplete: Bool {
        endTime != nil
    }
}

// Manager for segments
class SegmentManager: ObservableObject {
    @Published var segments: [Segment] = []
    @Published var activeEffort: SegmentEffort?
    @Published var detectedSegment: Segment?

    private let segmentsKey = "SavedSegments"

    init() {
        loadSegments()
    }

    // Create a new segment from a route section
    func createSegment(name: String, startIndex: Int, endIndex: Int, routeCoordinates: [CLLocationCoordinate2D]) {
        guard startIndex < endIndex && endIndex < routeCoordinates.count else {
            print("Invalid segment indices")
            return
        }

        let segmentCoords = Array(routeCoordinates[startIndex...endIndex])

        // Calculate distance
        var distance: Double = 0.0
        for i in 1..<segmentCoords.count {
            let start = CLLocation(latitude: segmentCoords[i-1].latitude, longitude: segmentCoords[i-1].longitude)
            let end = CLLocation(latitude: segmentCoords[i].latitude, longitude: segmentCoords[i].longitude)
            distance += start.distance(from: end)
        }
        distance *= 0.000621371 // meters to miles

        let segment = Segment(
            name: name,
            startCoordinate: Segment.Coordinate(from: segmentCoords.first!),
            endCoordinate: Segment.Coordinate(from: segmentCoords.last!),
            routeCoordinates: segmentCoords.map { Segment.Coordinate(from: $0) },
            distance: distance
        )

        segments.append(segment)
        saveSegments()
        print("📍 Created segment: \(name) (\(String(format: "%.2f", distance)) mi)")
    }

    // Check if current location matches any segment start
    func checkForSegmentStart(_ coordinate: CLLocationCoordinate2D) {
        // Don't detect new segment if already on one
        guard activeEffort == nil else { return }

        for segment in segments {
            if segment.isNearStart(coordinate) {
                startSegmentEffort(segment)
                break
            }
        }
    }

    // Check if current location matches active segment end
    func checkForSegmentEnd(_ coordinate: CLLocationCoordinate2D) {
        guard var effort = activeEffort,
              let segment = segments.first(where: { $0.id == effort.segmentId }) else {
            return
        }

        if segment.isNearEnd(coordinate) {
            effort.endTime = Date()
            completeSegmentEffort(effort)
        }
    }

    // Start tracking a segment effort
    private func startSegmentEffort(_ segment: Segment) {
        activeEffort = SegmentEffort(
            segmentId: segment.id,
            startTime: Date()
        )
        detectedSegment = segment
        print("🏁 Started segment: \(segment.name)")
    }

    // Complete segment effort and check if it's a PR
    private func completeSegmentEffort(_ effort: SegmentEffort) {
        guard let segmentIndex = segments.firstIndex(where: { $0.id == effort.segmentId }) else {
            return
        }

        var segment = segments[segmentIndex]
        let avgSpeed = segment.distance / (effort.duration / 3600.0) // mph

        // Check if this is a PR
        let isPR = segment.bestTime == nil || effort.duration < segment.bestTime!

        if isPR {
            segment.bestTime = effort.duration
            segment.bestSpeed = avgSpeed
            segment.bestDate = Date()
            segments[segmentIndex] = segment
            saveSegments()
            print("🏆 NEW PR on \(segment.name)! \(formatTime(effort.duration)) at \(String(format: "%.1f", avgSpeed)) mph")
        } else {
            print("✅ Completed \(segment.name): \(formatTime(effort.duration)) at \(String(format: "%.1f", avgSpeed)) mph")
        }

        activeEffort = nil
        detectedSegment = nil
    }

    // Update active effort with new coordinate
    func updateActiveEffort(coordinate: CLLocationCoordinate2D) {
        guard var effort = activeEffort else { return }
        effort.coordinates.append(coordinate)
        activeEffort = effort
    }

    // Cancel active effort
    func cancelActiveEffort() {
        activeEffort = nil
        detectedSegment = nil
    }

    // Delete a segment
    func deleteSegment(_ segment: Segment) {
        segments.removeAll { $0.id == segment.id }
        saveSegments()
    }

    // MARK: - Persistence

    private func loadSegments() {
        guard let data = UserDefaults.standard.data(forKey: segmentsKey),
              let decoded = try? JSONDecoder().decode([Segment].self, from: data) else {
            return
        }
        segments = decoded
    }

    private func saveSegments() {
        if let encoded = try? JSONEncoder().encode(segments) {
            UserDefaults.standard.set(encoded, forKey: segmentsKey)
        }
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}
