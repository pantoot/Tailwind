import Foundation
import HealthKit
import Combine

class WatchHealthKitService: NSObject, ObservableObject {
    private let healthStore = HKHealthStore()
    @Published var currentHeartRate: Int = 0
    @Published var isAuthorized: Bool = false

    // Heart rate query
    private var heartRateQuery: HKQuery?
    private var heartRateAnchor: HKQueryAnchor?

    override init() {
        super.init()
    }

    // Request HealthKit authorization (heart rate only)
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("⌚ Watch: HealthKit not available")
            return
        }

        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!

        let typesToRead: Set<HKObjectType> = [heartRateType]

        try await healthStore.requestAuthorization(toShare: [], read: typesToRead)

        DispatchQueue.main.async {
            self.isAuthorized = true
            print("⌚ Watch: HealthKit authorized")
        }
    }

    // Start streaming heart rate data
    func startHeartRateStreaming() {
        guard isAuthorized else {
            print("⌚ Watch: Not authorized for HealthKit")
            return
        }

        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!

        // Create predicate for only very recent samples (last 10 seconds)
        let predicate = HKQuery.predicateForSamples(
            withStart: Date().addingTimeInterval(-10),
            end: nil,
            options: .strictStartDate
        )

        // Use anchored query with strict limit to prevent memory issues
        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: predicate,
            anchor: heartRateAnchor,
            limit: 1  // Only get 1 most recent sample, not unlimited
        ) { [weak self] query, samples, deletedObjects, anchor, error in
            guard let self = self else { return }

            if let error = error {
                print("⌚ Watch: Error reading heart rate: \(error.localizedDescription)")
                return
            }

            // Update anchor for next query
            self.heartRateAnchor = anchor

            // Process new samples
            self.processSamples(samples)
        }

        // Set update handler for continuous streaming
        query.updateHandler = { [weak self] query, samples, deletedObjects, anchor, error in
            guard let self = self else { return }

            if let error = error {
                print("⌚ Watch: Error in heart rate update: \(error.localizedDescription)")
                return
            }

            // Update anchor
            self.heartRateAnchor = anchor

            // Process new samples
            self.processSamples(samples)
        }

        heartRateQuery = query
        healthStore.execute(query)

        print("⌚ Watch: Started heart rate streaming")
    }

    // Stop streaming heart rate
    func stopHeartRateStreaming() {
        if let query = heartRateQuery {
            healthStore.stop(query)
            heartRateQuery = nil
            heartRateAnchor = nil  // Reset anchor to prevent memory buildup
            print("⌚ Watch: Stopped heart rate streaming")
        }

        DispatchQueue.main.async {
            self.currentHeartRate = 0
        }
    }

    // Process heart rate samples
    private func processSamples(_ samples: [HKSample]?) {
        guard let quantitySamples = samples as? [HKQuantitySample] else { return }

        // Get most recent sample
        guard let mostRecentSample = quantitySamples.max(by: { $0.endDate < $1.endDate }) else {
            return
        }

        let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
        let heartRate = mostRecentSample.quantity.doubleValue(for: heartRateUnit)

        DispatchQueue.main.async {
            self.currentHeartRate = Int(heartRate)
            print("⌚ Watch: HR from HealthKit: \(self.currentHeartRate) bpm")
        }
    }
}
