import Foundation

/// File-backed persistence for the ride log.
///
/// Rides used to live in UserDefaults, which is built for small preference values
/// and loads its whole domain into memory at launch. A single outdoor ride carries
/// several hundred GPS coordinates — tens of kilobytes — so the log outgrew that
/// store years before anyone noticed. The 100-ride cap that silently discarded the
/// oldest ride on every save existed to hold that line, which meant training
/// history quietly stopped at whatever the cap allowed.
///
/// Moving to a JSON file in Application Support removes the storage pressure, so
/// the cap can be generous instead of load-bearing.
struct RideStore {

    /// Where the ride log lives once migrated off UserDefaults.
    static let fileName = "rides.json"

    /// The UserDefaults key rides were stored under before the move. Read once
    /// during migration, then cleared.
    static let legacyDefaultsKey = "SavedRides"

    private let fileManager: FileManager
    private let defaults: UserDefaults

    init(fileManager: FileManager = .default, defaults: UserDefaults = .standard) {
        self.fileManager = fileManager
        self.defaults = defaults
    }

    // MARK: - Locations

    private var directoryURL: URL? {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    }

    private var fileURL: URL? {
        directoryURL?.appendingPathComponent(Self.fileName)
    }

    // MARK: - Loading

    /// Reads the ride log, migrating from UserDefaults on first run.
    ///
    /// Returns an empty array when nothing has been saved yet. A file that fails to
    /// decode is preserved alongside the original rather than deleted — a transient
    /// decode failure should never be the reason a training history disappears.
    func load() -> [Ride] {
        guard let fileURL else {
            print("❌ ERROR: Could not locate Application Support directory")
            return []
        }

        if !fileManager.fileExists(atPath: fileURL.path) {
            return migrateFromDefaults()
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let rides = try JSONDecoder().decode([Ride].self, from: data)
            print("✅ Loaded \(rides.count) rides from \(Self.fileName)")
            return rides
        } catch {
            print("❌ ERROR: Failed to read rides from \(Self.fileName): \(error)")
            quarantine(fileURL)
            return []
        }
    }

    /// Moves an unreadable ride file aside so it can be recovered by hand.
    private func quarantine(_ fileURL: URL) {
        let corruptURL = fileURL.appendingPathExtension("corrupt")
        try? fileManager.removeItem(at: corruptURL)

        do {
            try fileManager.moveItem(at: fileURL, to: corruptURL)
            print("⚠️ Preserved the unreadable file at \(corruptURL.lastPathComponent) — rides were not deleted")
        } catch {
            print("❌ ERROR: Could not preserve the unreadable ride file: \(error)")
        }
    }

    /// One-time move of the ride log out of UserDefaults.
    private func migrateFromDefaults() -> [Ride] {
        guard let data = defaults.data(forKey: Self.legacyDefaultsKey) else {
            print("ℹ️ No saved rides found")
            return []
        }

        do {
            let rides = try JSONDecoder().decode([Ride].self, from: data)
            print("📦 Migrating \(rides.count) rides out of UserDefaults...")

            // Only drop the old copy once the new one is safely on disk.
            try save(rides)
            defaults.removeObject(forKey: Self.legacyDefaultsKey)
            print("✅ Migrated \(rides.count) rides to \(Self.fileName)")
            return rides
        } catch {
            print("❌ ERROR: Failed to migrate rides from UserDefaults: \(error)")
            print("   Leaving the UserDefaults copy in place for recovery")
            return []
        }
    }

    // MARK: - Saving

    /// Writes the ride log atomically, so a crash mid-save can't truncate it.
    func save(_ rides: [Ride]) throws {
        guard let directoryURL, let fileURL else {
            throw RideStoreError.noApplicationSupportDirectory
        }

        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let data = try JSONEncoder().encode(rides)
        try data.write(to: fileURL, options: .atomic)
    }
}

enum RideStoreError: LocalizedError {
    case noApplicationSupportDirectory

    var errorDescription: String? {
        switch self {
        case .noApplicationSupportDirectory:
            return "Could not locate the Application Support directory to save rides."
        }
    }
}
