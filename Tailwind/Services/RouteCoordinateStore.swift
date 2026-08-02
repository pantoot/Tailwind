import Foundation

/// Per-ride GPS tracks, stored outside the ride log and read only when something
/// actually draws a map.
///
/// An hour of outdoor riding is several hundred coordinates — tens of kilobytes —
/// and inline in the ride record it had to be decoded at every launch whether or
/// not anyone looked at a map. That made startup cost scale with years of history
/// and was the real reason the ride log couldn't grow. Disk was never the problem.
///
/// Tracks are keyed by ride id, so a deleted ride's track can be cleaned up and a
/// missing file simply means "no route recorded".
struct RouteCoordinateStore {

    static let directoryName = "RouteTracks"

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    private var directoryURL: URL? {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(Self.directoryName)
    }

    private func fileURL(for rideID: UUID) -> URL? {
        directoryURL?.appendingPathComponent("\(rideID.uuidString).json")
    }

    // MARK: - Reading

    /// The track for a ride, or nil when none was recorded.
    func coordinates(for rideID: UUID) -> [Ride.Coordinate]? {
        guard let fileURL = fileURL(for: rideID),
              fileManager.fileExists(atPath: fileURL.path) else { return nil }

        do {
            let data = try Data(contentsOf: fileURL)
            let coordinates = try JSONDecoder().decode([Ride.Coordinate].self, from: data)
            return coordinates.isEmpty ? nil : coordinates
        } catch {
            print("⚠️ Could not read route track for \(rideID): \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Writing

    /// Stores a ride's track. Passing nil or an empty track removes any existing one.
    func save(_ coordinates: [Ride.Coordinate]?, for rideID: UUID) throws {
        guard let directoryURL, let fileURL = fileURL(for: rideID) else {
            throw RideStoreError.noApplicationSupportDirectory
        }

        guard let coordinates, !coordinates.isEmpty else {
            try? fileManager.removeItem(at: fileURL)
            return
        }

        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(coordinates)
        try data.write(to: fileURL, options: .atomic)
    }

    func delete(for rideID: UUID) {
        guard let fileURL = fileURL(for: rideID) else { return }
        try? fileManager.removeItem(at: fileURL)
    }

    /// Drops tracks whose ride no longer exists.
    @discardableResult
    func removeOrphans(keeping rideIDs: Set<UUID>) -> Int {
        guard let directoryURL,
              let files = try? fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
        else { return 0 }

        let orphans = files.filter { file in
            guard let id = UUID(uuidString: file.deletingPathExtension().lastPathComponent) else { return false }
            return !rideIDs.contains(id)
        }

        for orphan in orphans {
            try? fileManager.removeItem(at: orphan)
        }
        return orphans.count
    }
}
