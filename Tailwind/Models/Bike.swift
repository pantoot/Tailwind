import Foundation
import SwiftUI
import Combine

struct Bike: Identifiable, Codable {
    let id: UUID
    var name: String
    var type: BikeType
    var totalMiles: Double // Total miles ridden on this bike
    var maintenanceItems: [MaintenanceItem]
    var assignedSensors: [String: SavedSensor] // sensorType.rawValue -> SavedSensor

    enum BikeType: String, Codable, CaseIterable {
        case road = "Road"
        case gravel = "Gravel"
        case mountain = "Mountain"
        case hybrid = "Hybrid"
        case ebike = "E-Bike"
    }

    init(id: UUID = UUID(), name: String, type: BikeType, totalMiles: Double = 0, maintenanceItems: [MaintenanceItem] = [], assignedSensors: [String: SavedSensor] = [:]) {
        self.id = id
        self.name = name
        self.type = type
        self.totalMiles = totalMiles
        self.maintenanceItems = maintenanceItems
        self.assignedSensors = assignedSensors
    }

    // Get sensor for a specific type
    func sensor(for type: SensorType) -> SavedSensor? {
        assignedSensors[type.rawValue]
    }

    // Assign a sensor to this bike
    mutating func assignSensor(_ sensor: SavedSensor, for type: SensorType) {
        assignedSensors[type.rawValue] = sensor
    }

    // Remove sensor assignment
    mutating func removeSensor(for type: SensorType) {
        assignedSensors.removeValue(forKey: type.rawValue)
    }

    // Get items that need service
    var itemsNeedingService: [MaintenanceItem] {
        maintenanceItems.filter { $0.isServiceDue(currentMiles: totalMiles) }
    }

    // Get items approaching service (>80%)
    var itemsApproachingService: [MaintenanceItem] {
        maintenanceItems.filter {
            let percentage = $0.servicePercentage(currentMiles: totalMiles)
            return percentage >= 80 && percentage < 100
        }
    }
}

// Bike stable management
class BikeStable: ObservableObject {
    @Published var bikes: [Bike] = []
    @Published var selectedBikeId: UUID?
    @Published var profileSensors: [String: SavedSensor] = [:] // sensorType.rawValue -> SavedSensor (for heart rate, etc.)

    private let bikesKey = "SavedBikes"
    private let selectedBikeKey = "SelectedBikeId"
    private let profileSensorsKey = "ProfileSensors"

    // Callback when bike selection changes
    var onBikeChanged: ((Bike) -> Void)?

    init() {
        loadBikes()
        loadSelectedBike()
        loadProfileSensors()

        // Start with empty bike stable - users will add their own bikes
        // No pre-populated bikes in production
    }

    var selectedBike: Bike? {
        guard let id = selectedBikeId else { return bikes.first }
        return bikes.first(where: { $0.id == id }) ?? bikes.first
    }

    func selectBike(_ bike: Bike) {
        selectedBikeId = bike.id
        saveSelectedBike()
        onBikeChanged?(bike)
    }

    func addBike(_ bike: Bike) {
        bikes.append(bike)
        saveBikes()
    }

    func updateBike(_ bike: Bike) {
        if let index = bikes.firstIndex(where: { $0.id == bike.id }) {
            bikes[index] = bike
            saveBikes()
        }
    }

    func deleteBike(_ bike: Bike) {
        bikes.removeAll { $0.id == bike.id }

        // If deleted bike was selected, select first available
        if selectedBikeId == bike.id {
            selectedBikeId = bikes.first?.id
            saveSelectedBike()
        }

        saveBikes()
    }

    func deleteBikes(at offsets: IndexSet) {
        let bikesToDelete = offsets.map { bikes[$0] }
        bikes = bikes.enumerated().filter { !offsets.contains($0.offset) }.map { $0.element }

        // If deleted bike was selected, select first available
        if bikesToDelete.contains(where: { $0.id == selectedBikeId }) {
            selectedBikeId = bikes.first?.id
            saveSelectedBike()
        }

        saveBikes()
    }

    func addMiles(to bikeId: UUID, miles: Double) {
        if let index = bikes.firstIndex(where: { $0.id == bikeId }) {
            bikes[index].totalMiles += miles
            saveBikes()
        }
    }

    func markServiceComplete(bikeId: UUID, maintenanceItemId: UUID) {
        if let bikeIndex = bikes.firstIndex(where: { $0.id == bikeId }),
           let itemIndex = bikes[bikeIndex].maintenanceItems.firstIndex(where: { $0.id == maintenanceItemId }) {
            bikes[bikeIndex].maintenanceItems[itemIndex].lastServiceMiles = bikes[bikeIndex].totalMiles
            bikes[bikeIndex].maintenanceItems[itemIndex].lastServiceDate = Date()
            saveBikes()
        }
    }

    func updateMaintenanceItem(bikeId: UUID, item: MaintenanceItem) {
        if let bikeIndex = bikes.firstIndex(where: { $0.id == bikeId }),
           let itemIndex = bikes[bikeIndex].maintenanceItems.firstIndex(where: { $0.id == item.id }) {
            bikes[bikeIndex].maintenanceItems[itemIndex] = item
            saveBikes()
        }
    }

    func addMaintenanceItem(to bikeId: UUID, item: MaintenanceItem) {
        if let index = bikes.firstIndex(where: { $0.id == bikeId }) {
            bikes[index].maintenanceItems.append(item)
            saveBikes()
        }
    }

    func deleteMaintenanceItem(from bikeId: UUID, itemId: UUID) {
        if let index = bikes.firstIndex(where: { $0.id == bikeId }) {
            bikes[index].maintenanceItems.removeAll { $0.id == itemId }
            saveBikes()
        }
    }

    private func loadBikes() {
        guard let data = UserDefaults.standard.data(forKey: bikesKey) else {
            print("ℹ️ No saved bikes data found")
            return
        }

        do {
            let decoder = JSONDecoder()
            bikes = try decoder.decode([Bike].self, from: data)
            print("✅ Successfully loaded \(bikes.count) bikes")
        } catch {
            print("❌ ERROR: Failed to decode bikes: \(error)")
            print("   Clearing corrupt data and starting fresh")
            UserDefaults.standard.removeObject(forKey: bikesKey)
            bikes = []
        }
    }

    private func saveBikes() {
        print("💾 saveBikes() called - encoding \(bikes.count) bikes...")

        do {
            let encoder = JSONEncoder()
            print("💾 Starting JSON encoding...")
            let encoded = try encoder.encode(bikes)
            print("💾 Encoding complete, size: \(encoded.count) bytes")

            print("💾 Saving to UserDefaults...")
            UserDefaults.standard.set(encoded, forKey: bikesKey)
            print("✅ Successfully saved \(bikes.count) bikes")
        } catch {
            print("❌ ERROR: Failed to encode bikes: \(error)")
            print("   Error type: \(type(of: error))")
            print("   Bikes count: \(bikes.count)")

            // Log each bike's sensor data to find the problematic one
            for (index, bike) in bikes.enumerated() {
                print("   Bike \(index): \(bike.name), sensors: \(bike.assignedSensors.count)")
                for (key, sensor) in bike.assignedSensors {
                    print("     - \(key): \(sensor.displayName) (ID: \(sensor.id))")
                }
            }
        }
    }

    private func loadSelectedBike() {
        guard let uuidString = UserDefaults.standard.string(forKey: selectedBikeKey),
              let uuid = UUID(uuidString: uuidString) else {
            return
        }
        selectedBikeId = uuid
    }

    private func saveSelectedBike() {
        if let id = selectedBikeId {
            UserDefaults.standard.set(id.uuidString, forKey: selectedBikeKey)
        }
    }

    // MARK: - Sensor Management

    // Assign a sensor to the current bike (for bike-specific sensors)
    func assignSensorToBike(_ sensor: SavedSensor, type: SensorType) {
        print("🔧 Starting assignSensorToBike for type: \(type.rawValue)")

        guard let bikeId = selectedBikeId else {
            print("❌ No selected bike ID")
            return
        }

        guard let index = bikes.firstIndex(where: { $0.id == bikeId }) else {
            print("❌ Could not find bike with ID: \(bikeId)")
            return
        }

        print("🔧 Found bike at index \(index): \(bikes[index].name)")
        print("🔧 Assigning sensor: \(sensor.displayName) (ID: \(sensor.id))")

        bikes[index].assignSensor(sensor, for: type)
        print("🔧 Sensor assigned, calling saveBikes()...")

        saveBikes()

        print("🔧 ✅ assignSensorToBike complete!")
    }

    // Assign a profile sensor (for personal sensors like heart rate)
    func assignProfileSensor(_ sensor: SavedSensor, type: SensorType) {
        profileSensors[type.rawValue] = sensor
        saveProfileSensors()
    }

    // Get sensor for current context (checks bike first, then profile)
    func getSensor(for type: SensorType) -> SavedSensor? {
        if type.isProfileSensor {
            return profileSensors[type.rawValue]
        } else if let bike = selectedBike {
            return bike.sensor(for: type)
        }
        return nil
    }

    // Remove sensor assignment
    func removeSensor(for type: SensorType) {
        if type.isProfileSensor {
            profileSensors.removeValue(forKey: type.rawValue)
            saveProfileSensors()
        } else if let bikeId = selectedBikeId,
                  let index = bikes.firstIndex(where: { $0.id == bikeId }) {
            bikes[index].removeSensor(for: type)
            saveBikes()
        }
    }

    private func loadProfileSensors() {
        guard let data = UserDefaults.standard.data(forKey: profileSensorsKey) else {
            print("ℹ️ No saved profile sensors data found")
            return
        }

        do {
            let decoder = JSONDecoder()
            profileSensors = try decoder.decode([String: SavedSensor].self, from: data)
            print("✅ Successfully loaded \(profileSensors.count) profile sensors")
        } catch {
            print("❌ ERROR: Failed to decode profile sensors: \(error)")
            print("   Clearing corrupt data and starting fresh")
            UserDefaults.standard.removeObject(forKey: profileSensorsKey)
            profileSensors = [:]
        }
    }

    private func saveProfileSensors() {
        do {
            let encoder = JSONEncoder()
            let encoded = try encoder.encode(profileSensors)
            UserDefaults.standard.set(encoded, forKey: profileSensorsKey)
            print("✅ Successfully saved \(profileSensors.count) profile sensors")
        } catch {
            print("❌ ERROR: Failed to encode profile sensors: \(error)")
            print("   Profile sensors data: \(profileSensors)")
        }
    }
}
