import SwiftUI
import HealthKit

struct SettingsTabView: View {
    @EnvironmentObject var healthKitService: HealthKitService
    @EnvironmentObject var bluetoothService: BluetoothService
    @EnvironmentObject var bikeStable: BikeStable
    @EnvironmentObject var rideHistory: RideHistory
    @EnvironmentObject var trainingLoadManager: TrainingLoadManager
    @EnvironmentObject var routeMatchingService: RouteMatchingService
    @EnvironmentObject var segmentManager: SegmentManager
    @EnvironmentObject var gpsService: GPSService
    @EnvironmentObject var sensorDataService: SensorDataService

    @State private var showingUserProfile = false
    @State private var showingBikeManagement = false
    @State private var showingHealthKitImport = false
    @State private var showingHealthKitFix = false
    @State private var showingRoutes = false
    @State private var showingSegments = false
    @State private var showingSensorSettings = false
    @State private var showingMaintenance = false
    @State private var selectedFixDate = Date()
    @State private var fixResultMessage = ""
    @State private var showingFixResult = false
    @State private var isFixingCalories = false

    var body: some View {
        NavigationView {
            List {
                // Profile Section
                profileSection

                // HealthKit Section
                healthKitSection

                // Bikes Section
                bikesSection

                // Sensors Section
                sensorsSection

                // Routes & Segments Section
                routesSegmentsSection

                // App Info Section
                appInfoSection
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingUserProfile) {
                UserProfileView()
                    .environmentObject(sensorDataService)
            }
            .sheet(isPresented: $showingBikeManagement) {
                BikeManagementView()
                    .environmentObject(bikeStable)
            }
            .sheet(isPresented: $showingHealthKitImport) {
                HealthKitImportSheet()
                    .environmentObject(healthKitService)
                    .environmentObject(rideHistory)
                    .environmentObject(trainingLoadManager)
            }
            .sheet(isPresented: $showingHealthKitFix) {
                HealthKitFixSheet(
                    selectedDate: $selectedFixDate,
                    onFix: fixCaloriesForDate
                )
            }
            .sheet(isPresented: $showingRoutes) {
                RoutesView()
                    .environmentObject(routeMatchingService)
            }
            .sheet(isPresented: $showingSegments) {
                SegmentsView()
                    .environmentObject(segmentManager)
                    .environmentObject(gpsService)
                    .environmentObject(rideHistory)
            }
            .sheet(isPresented: $showingSensorSettings) {
                SensorSettingsSheet()
                    .environmentObject(bluetoothService)
                    .environmentObject(bikeStable)
            }
            .sheet(isPresented: $showingMaintenance) {
                if let bike = bikeStable.selectedBike {
                    MaintenanceView(bike: bike)
                        .environmentObject(bikeStable)
                }
            }
            .alert("Calorie Fix Results", isPresented: $showingFixResult) {
                Button("OK") { }
            } message: {
                Text(fixResultMessage)
            }
        }
    }

    // MARK: - Profile Section

    private var profileSection: some View {
        Section(header: Text("Profile")) {
            Button(action: { showingUserProfile = true }) {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.blue)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Personal Information")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("Age, weight, threshold HR")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
            }
        }
    }

    // MARK: - HealthKit Section

    private var healthKitSection: some View {
        Section(header: Text("HealthKit Integration")) {
            // Authorization Status
            HStack {
                Image(systemName: healthKitService.isAuthorized ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(healthKitService.isAuthorized ? .green : .red)
                Text("Authorization")
                Spacer()
                Text(healthKitService.isAuthorized ? "Authorized" : "Not Authorized")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Import Rides
            Button(action: { showingHealthKitImport = true }) {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                        .foregroundColor(.blue)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Import Rides")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("Import from last 60 days")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
            }

            // Fix Calorie Data
            Button(action: { showingHealthKitFix = true }) {
                HStack {
                    Image(systemName: "wrench.and.screwdriver")
                        .foregroundColor(.orange)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Fix Calorie Data")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("Recalculate & update in Apple Health")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
            }
        }
    }

    // MARK: - Bikes Section

    private var bikesSection: some View {
        Section(header: Text("Bikes")) {
            // Current Bike
            HStack {
                Image(systemName: "bicycle")
                    .foregroundColor(.green)
                Text("Current Bike")
                Spacer()
                Text(bikeStable.selectedBike?.name ?? "None")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Manage Bikes
            Button(action: { showingBikeManagement = true }) {
                HStack {
                    Image(systemName: "list.bullet")
                        .foregroundColor(.blue)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Manage Bikes")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("\(bikeStable.bikes.count) bike\(bikeStable.bikes.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
            }

            // Maintenance
            if bikeStable.selectedBike != nil {
                Button(action: { showingMaintenance = true }) {
                    HStack {
                        Image(systemName: "wrench.fill")
                            .foregroundColor(.orange)
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Maintenance")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("Track service and repairs")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                }
            }
        }
    }

    // MARK: - Sensors Section

    private var sensorsSection: some View {
        Section(header: Text("Sensors")) {
            Button(action: { showingSensorSettings = true }) {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .foregroundColor(.purple)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Bluetooth Sensors")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("Pair and manage sensors")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()

                    // Connection indicator
                    if bluetoothService.connectedSensors.count > 0 {
                        HStack(spacing: 4) {
                            Text("\(bluetoothService.connectedSensors.count)")
                                .font(.caption2)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .clipShape(Capsule())
                        }
                    }

                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
            }
        }
    }

    // MARK: - Routes & Segments Section

    private var routesSegmentsSection: some View {
        Section(header: Text("Routes & Segments")) {
            Button(action: { showingRoutes = true }) {
                HStack {
                    Image(systemName: "map")
                        .foregroundColor(.blue)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("My Routes")
                            .font(.headline)
                            .foregroundColor(.primary)
                        if routeMatchingService.savedRoutes.count > 0 {
                            Text("\(routeMatchingService.savedRoutes.count) route\(routeMatchingService.savedRoutes.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundColor(.gray)
                        } else {
                            Text("No saved routes")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
            }

            Button(action: { showingSegments = true }) {
                HStack {
                    Image(systemName: "flag.fill")
                        .foregroundColor(.orange)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("My Segments")
                            .font(.headline)
                            .foregroundColor(.primary)
                        if segmentManager.segments.count > 0 {
                            Text("\(segmentManager.segments.count) segment\(segmentManager.segments.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundColor(.gray)
                        } else {
                            Text("No saved segments")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
            }
        }
    }

    // MARK: - App Info Section

    private var appInfoSection: some View {
        Section(header: Text("About")) {
            HStack {
                Text("Version")
                Spacer()
                Text("1.0.0")
                    .foregroundColor(.secondary)
            }

            Link(destination: URL(string: "https://github.com/pantoot/Tailwind")!) {
                HStack {
                    Text("GitHub Repository")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
    }

    // MARK: - Fix Calories

    private func fixCaloriesForDate() {
        isFixingCalories = true
        Task {
            let userProfile = UserProfile.load()
            fixResultMessage = await rideHistory.fixCalories(
                for: selectedFixDate,
                userProfile: userProfile,
                healthKitService: healthKitService
            )
            await MainActor.run {
                isFixingCalories = false
                showingHealthKitFix = false
                showingFixResult = true
            }
        }
    }
}

// MARK: - HealthKit Import Sheet

struct HealthKitImportSheet: View {
    @EnvironmentObject var healthKitService: HealthKitService
    @EnvironmentObject var rideHistory: RideHistory
    @EnvironmentObject var trainingLoadManager: TrainingLoadManager
    @Environment(\.dismiss) var dismiss

    @State private var importedWorkouts: [HKWorkout] = []
    @State private var isImporting = false
    @State private var importError: String?

    var body: some View {
        NavigationView {
            VStack {
                if isImporting {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading workouts...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = importError {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 60))
                            .foregroundColor(.red)
                        Text("Error")
                            .font(.title2)
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else if importedWorkouts.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        Text("All Caught Up!")
                            .font(.title2)
                        Text("No new workouts to import")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        Section {
                            VStack(spacing: 12) {
                                Text("Found \(importedWorkouts.count) workout\(importedWorkouts.count == 1 ? "" : "s") from the last 60 days")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                if importedWorkouts.count > 1 {
                                    Button(action: importAllWorkouts) {
                                        Label("Import All (\(importedWorkouts.count))", systemImage: "square.and.arrow.down.on.square")
                                            .font(.headline)
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                            }
                            .padding(.vertical, 8)
                        }

                        ForEach(importedWorkouts, id: \.uuid) { workout in
                            Button(action: {
                                importWorkout(workout)
                            }) {
                                WorkoutRowView(workout: workout)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Import from HealthKit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadWorkouts()
            }
        }
    }

    private func loadWorkouts() {
        isImporting = true
        importError = nil

        Task {
            do {
                // Request authorization if not already granted
                if !healthKitService.isAuthorized {
                    print("⚠️ HealthKit not authorized, requesting permission...")
                    try await healthKitService.requestAuthorization()

                    if !healthKitService.isAuthorized {
                        throw HealthKitError.notAuthorized
                    }
                    print("✅ HealthKit authorization granted")
                }

                let endDate = Date()
                let startDate = Calendar.current.date(byAdding: .day, value: -60, to: endDate)!

                let workouts = try await healthKitService.fetchCyclingWorkouts(from: startDate, to: endDate)

                // Filter out already imported workouts
                let existingDates = Set(rideHistory.rides.map {
                    Calendar.current.startOfDay(for: $0.date)
                })

                let newWorkouts = workouts.filter { workout in
                    let workoutDay = Calendar.current.startOfDay(for: workout.startDate)
                    return !existingDates.contains(workoutDay)
                }

                await MainActor.run {
                    importedWorkouts = newWorkouts
                    isImporting = false

                    if newWorkouts.isEmpty && !workouts.isEmpty {
                        print("ℹ️ All \(workouts.count) workouts already imported")
                    }
                }
            } catch {
                await MainActor.run {
                    importError = error.localizedDescription
                    isImporting = false
                }
            }
        }
    }

    private func importAllWorkouts() {
        Task {
            var successCount = 0
            var failCount = 0

            for workout in importedWorkouts {
                do {
                    let ride = try await healthKitService.importWorkout(workout)

                    await MainActor.run {
                        rideHistory.saveRide(ride)

                        if let tss = ride.hrTSS {
                            trainingLoadManager.addTSS(date: ride.date, tss: tss)
                        }
                    }

                    successCount += 1
                    print("✅ Imported \(successCount)/\(importedWorkouts.count): \(ride.distance) mi")
                } catch {
                    failCount += 1
                    print("❌ Failed to import workout: \(error.localizedDescription)")
                }
            }

            await MainActor.run {
                dismiss()
                print("🎉 Bulk import complete: \(successCount) succeeded, \(failCount) failed")
            }
        }
    }

    private func importWorkout(_ workout: HKWorkout) {
        Task {
            do {
                let ride = try await healthKitService.importWorkout(workout)

                await MainActor.run {
                    rideHistory.saveRide(ride)

                    if let tss = ride.hrTSS {
                        trainingLoadManager.addTSS(date: ride.date, tss: tss)
                    }

                    // Remove from list
                    importedWorkouts.removeAll { $0.uuid == workout.uuid }

                    print("✅ Imported ride: \(ride.distance) mi")
                }
            } catch {
                print("❌ Failed to import: \(error.localizedDescription)")
            }
        }
    }
}

struct WorkoutRowView: View {
    let workout: HKWorkout

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.startDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.headline)
                HStack {
                    if let distance = workout.totalDistance {
                        Text("\(distance.doubleValue(for: .mile()), specifier: "%.2f") mi")
                    }

                    if #available(iOS 18.0, *) {
                        if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
                           let stat = workout.statistics(for: energyType),
                           let calories = stat.sumQuantity()?.doubleValue(for: .kilocalorie()) {
                            Text("• \(calories, specifier: "%.0f") cal")
                        }
                    } else {
                        if let calories = workout.totalEnergyBurned {
                            Text("• \(calories.doubleValue(for: .kilocalorie()), specifier: "%.0f") cal")
                        }
                    }

                    Text("• \(formatDuration(workout.duration))")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - HealthKit Fix Sheet

struct HealthKitFixSheet: View {
    @Binding var selectedDate: Date
    let onFix: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Select Date to Fix")
                    .font(.headline)

                DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()

                VStack(spacing: 12) {
                    Text("This will recalculate calories for rides on the selected date using the correct formula and update them in Apple Health.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()

                    Button(action: {
                        onFix()
                    }) {
                        Text("Fix Calories")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Fix Calorie Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: { dismiss() })
                }
            }
        }
    }
}

// MARK: - Sensor Settings Sheet

struct SensorSettingsSheet: View {
    @EnvironmentObject var bluetoothService: BluetoothService
    @EnvironmentObject var bikeStable: BikeStable
    @Environment(\.dismiss) var dismiss
    @State private var assigningSensor: (SensorType, SensorInfo)?
    @State private var renamingSensor: (SensorType, String)? = nil
    @State private var showingRenameSheet = false

    var body: some View {
        NavigationView {
            List {
                // Bluetooth Status
                Section(header: Text("Bluetooth Status")) {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(bluetoothStateText)
                            .foregroundColor(bluetoothStateColor)
                    }
                }

                // Assigned Sensors
                Section(header: Text("Assigned Sensors")) {
                    ForEach(SensorType.allCases, id: \.self) { sensorType in
                        if let savedSensor = bikeStable.getSensor(for: sensorType) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(savedSensor.displayName)
                                            .font(.headline)
                                        Text(sensorType.rawValue)
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }

                                    Spacer()

                                    Text(sensorType.isProfileSensor ? "Profile" : bikeStable.selectedBike?.name ?? "Bike")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.1))
                                        .clipShape(Capsule())

                                    Button(action: {
                                        renamingSensor = (sensorType, savedSensor.customName ?? savedSensor.deviceName)
                                        showingRenameSheet = true
                                    }) {
                                        Image(systemName: "pencil.circle")
                                            .foregroundColor(.blue)
                                    }
                                }

                                HStack {
                                    if bluetoothService.connectedSensors[sensorType] != nil {
                                        HStack(spacing: 8) {
                                            Text("✓ Connected")
                                                .font(.caption)
                                                .foregroundColor(.green)

                                            if let battery = bluetoothService.getBatteryLevel(for: sensorType) {
                                                HStack(spacing: 2) {
                                                    Image(systemName: batteryIcon(for: battery))
                                                        .foregroundColor(batteryColor(for: battery))
                                                    Text("\(battery)%")
                                                        .font(.caption2)
                                                        .foregroundColor(.gray)
                                                }
                                            }
                                        }
                                    } else {
                                        Text("Disconnected")
                                            .font(.caption)
                                            .foregroundColor(.gray)

                                        Button("Reconnect") {
                                            bluetoothService.connectToPeripheral(withId: savedSensor.id, type: sensorType)
                                        }
                                        .buttonStyle(.bordered)
                                        .font(.caption)
                                    }
                                }
                            }
                        }
                    }
                }

                // Discovered Sensors
                Section(header: Text("Discovered Sensors")) {
                    if bluetoothService.discoveredSensors.isEmpty {
                        Text("No sensors found")
                            .foregroundColor(.gray)
                    } else {
                        ForEach(bluetoothService.discoveredSensors) { sensor in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(sensor.name)
                                        .font(.headline)
                                    HStack(spacing: 8) {
                                        Text(sensor.type.rawValue)
                                            .font(.caption)
                                            .foregroundColor(.gray)

                                        if let battery = sensor.batteryLevel {
                                            HStack(spacing: 2) {
                                                Image(systemName: batteryIcon(for: battery))
                                                    .font(.caption)
                                                    .foregroundColor(batteryColor(for: battery))
                                                Text("\(battery)%")
                                                    .font(.caption2)
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                    }
                                }

                                Spacer()

                                if sensor.isConnected {
                                    Button("Assign") {
                                        assigningSensor = (sensor.type, sensor)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .font(.caption)
                                } else {
                                    Button("Connect") {
                                        bluetoothService.connect(to: sensor)
                                    }
                                    .buttonStyle(.bordered)
                                    .font(.caption)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Bluetooth Sensors")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        if bluetoothService.isScanning {
                            bluetoothService.stopScanning()
                        } else {
                            bluetoothService.startScanning()
                        }
                    }) {
                        Text(bluetoothService.isScanning ? "Stop" : "Scan")
                    }
                }
            }
            .alert("Assign Sensor", isPresented: .constant(assigningSensor != nil), presenting: assigningSensor) { sensorTuple in
                Button("Assign to Profile") {
                    if let savedSensor = bluetoothService.createSavedSensor(for: sensorTuple.0) {
                        bikeStable.assignProfileSensor(savedSensor, type: sensorTuple.0)
                    }
                    assigningSensor = nil
                }
                Button("Assign to \(bikeStable.selectedBike?.name ?? "Current Bike")") {
                    if let savedSensor = bluetoothService.createSavedSensor(for: sensorTuple.0) {
                        bikeStable.assignSensorToBike(savedSensor, type: sensorTuple.0)
                    }
                    assigningSensor = nil
                }
                Button("Cancel", role: .cancel) {
                    assigningSensor = nil
                }
            } message: { sensorTuple in
                Text("\(sensorTuple.0.rawValue) will auto-connect to the selected bike or profile.")
            }
            .sheet(isPresented: $showingRenameSheet) {
                if let (sensorType, initialName) = renamingSensor {
                    SensorRenameView(sensorType: sensorType, initialName: initialName)
                        .environmentObject(bikeStable)
                }
            }
        }
    }

    private var bluetoothStateText: String {
        switch bluetoothService.bluetoothState {
        case .poweredOn: return "On"
        case .poweredOff: return "Off"
        case .unauthorized: return "Unauthorized"
        case .unsupported: return "Unsupported"
        default: return "Unknown"
        }
    }

    private var bluetoothStateColor: Color {
        switch bluetoothService.bluetoothState {
        case .poweredOn: return .green
        default: return .red
        }
    }

    private func batteryIcon(for level: Int) -> String {
        switch level {
        case 76...100: return "battery.100"
        case 51...75: return "battery.75"
        case 26...50: return "battery.50"
        case 11...25: return "battery.25"
        default: return "battery.0"
        }
    }

    private func batteryColor(for level: Int) -> Color {
        switch level {
        case 26...100: return .green
        case 11...25: return .orange
        default: return .red
        }
    }
}
