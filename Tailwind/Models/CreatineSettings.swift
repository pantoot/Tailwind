import Foundation
import Combine

struct CreatineSettings: Codable {
    var creatineStartDate: Date?
    var matchThresholdWatts: Double

    init(creatineStartDate: Date? = nil, matchThresholdWatts: Double = 500) {
        self.creatineStartDate = creatineStartDate
        self.matchThresholdWatts = matchThresholdWatts
    }

    /// Effective match threshold: uses Zone 6 floor (120% FTP) if FTP is set, otherwise falls back to manual setting.
    var effectiveMatchThreshold: Double {
        let profile = UserProfile.load()
        if let ftp = profile.ftp, ftp > 0 {
            return Double(ftp) * 1.2  // Zone 6 = 120% FTP
        }
        return matchThresholdWatts
    }

    private static let storageKey = "CreatineSettings"

    static func load() -> CreatineSettings {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let settings = try? JSONDecoder().decode(CreatineSettings.self, from: data) else {
            return CreatineSettings()
        }
        return settings
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: CreatineSettings.storageKey)
        }
    }
}

/// Observable wrapper for SwiftUI environment injection
class CreatineSettingsManager: ObservableObject {
    @Published var settings: CreatineSettings

    init() {
        self.settings = CreatineSettings.load()
    }

    func save() {
        settings.save()
    }
}
