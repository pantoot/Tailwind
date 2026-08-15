import Foundation

/// Packages a ride plus its raw HealthKit streams into a shareable JSON file
/// (AirDrop, Files, etc.) for offline analysis.
struct RideExportService {

    struct Export: Codable {
        let exportVersion: Int
        let exportedAt: Date
        let ride: Ride
        /// Raw 1Hz streams, offsets in seconds from ride start.
        let powerSamples: [Sample]
        let heartRateSamples: [Sample]
        let cadenceSamples: [Sample]

        struct Sample: Codable {
            let offset: TimeInterval
            let value: Double
        }
    }

    private static let currentExportVersion = 2

    /// Write the export JSON to a temp file and return its URL for the share sheet.
    static func writeExportFile(ride: Ride, samples: HealthKitService.RawRideSamples) throws -> URL {
        let export = Export(
            exportVersion: currentExportVersion,
            exportedAt: Date(),
            ride: ride,
            powerSamples: samples.power.map {
                Export.Sample(offset: $0.date.timeIntervalSince(ride.date), value: $0.watts)
            },
            heartRateSamples: samples.heartRate.map {
                Export.Sample(offset: $0.date.timeIntervalSince(ride.date), value: $0.bpm)
            },
            cadenceSamples: samples.cadence.map {
                Export.Sample(offset: $0.date.timeIntervalSince(ride.date), value: $0.rpm)
            }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(export)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(exportFilename(for: ride.date))
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func exportFilename(for rideDate: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return "Tailwind-Ride-\(formatter.string(from: rideDate)).json"
    }
}
