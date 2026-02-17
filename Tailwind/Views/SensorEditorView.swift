import SwiftUI

struct SensorEditorView: View {
    @EnvironmentObject var bluetoothService: BluetoothService
    @EnvironmentObject var bikeStable: BikeStable
    @Environment(\.dismiss) var dismiss

    let sensorId: UUID
    let currentType: SensorType
    let isProfileSensor: Bool

    @State private var customName: String = ""
    @State private var selectedType: SensorType
    @State private var showingDeleteConfirmation = false

    init(sensorId: UUID, currentType: SensorType, customName: String?, isProfileSensor: Bool) {
        self.sensorId = sensorId
        self.currentType = currentType
        self.isProfileSensor = isProfileSensor
        self._selectedType = State(initialValue: currentType)
        self._customName = State(initialValue: customName ?? "")
    }

    var body: some View {
        NavigationView {
            List {
                // Sensor Info
                Section(header: Text("Sensor Information")) {
                    HStack {
                        Text("Device ID")
                            .foregroundColor(.gray)
                        Spacer()
                        Text(sensorId.uuidString.prefix(8) + "...")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    if let sensorInfo = bluetoothService.connectedSensors[sensorId] {
                        // Sensor is currently connected - show live info
                        HStack {
                            Text("Device Name")
                                .foregroundColor(.gray)
                            Spacer()
                            Text(sensorInfo.name)
                        }

                        HStack {
                            Text("Connection")
                                .foregroundColor(.gray)
                            Spacer()
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                                Text("Connected")
                                    .foregroundColor(.green)
                            }
                        }

                        if let battery = sensorInfo.batteryLevel {
                            HStack {
                                Text("Battery")
                                    .foregroundColor(.gray)
                                Spacer()
                                Text("\(battery)%")
                                    .foregroundColor(batteryColor(for: battery))
                            }
                        }
                    } else {
                        // Sensor not currently connected
                        HStack {
                            Text("Connection")
                                .foregroundColor(.gray)
                            Spacer()
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 8, height: 8)
                                Text("Not Connected")
                                    .foregroundColor(.orange)
                            }
                        }

                        Text("Turn on the sensor to see live data and battery level")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.top, 4)
                    }
                }

                // Custom Name
                Section(header: Text("Custom Name")) {
                    TextField("Enter custom name (optional)", text: $customName)
                }

                // Sensor Type Override
                Section(header: Text("Sensor Type"), footer: Text("Change this if the sensor was incorrectly detected. For CSC sensors, choose Speed or Cadence based on which data it provides.")) {
                    Picker("Type", selection: $selectedType) {
                        ForEach(SensorType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.inline)
                }

                // Live Data
                Section(header: Text("Live Data")) {
                    liveDataView
                }

                // Assignment Info
                Section(header: Text("Assignment")) {
                    HStack {
                        Text("Assigned To")
                            .foregroundColor(.gray)
                        Spacer()
                        Text(isProfileSensor ? "Profile" : (bikeStable.selectedBike?.name ?? "Unknown Bike"))
                            .foregroundColor(.blue)
                    }
                }

                // Delete
                Section {
                    Button(action: {
                        showingDeleteConfirmation = true
                    }) {
                        HStack {
                            Spacer()
                            Text("Forget Sensor")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Edit Sensor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSensor()
                        dismiss()
                    }
                }
            }
            .alert("Forget Sensor", isPresented: $showingDeleteConfirmation) {
                Button("Forget", role: .destructive) {
                    forgetSensor()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove the sensor assignment. You can reassign it later.")
            }
        }
    }

    private var liveDataView: some View {
        Group {
            if let sensorInfo = bluetoothService.connectedSensors[sensorId], sensorInfo.isConnected {
                // Show live data based on sensor type
                switch selectedType {
                case .speed:
                    MetricRow(label: "Speed", value: String(format: "%.1f mph", bluetoothService.lastSpeedValue ?? 0))
                case .cadence:
                    MetricRow(label: "Cadence", value: "\(bluetoothService.lastCadenceValue ?? 0) rpm")
                case .heartRate:
                    MetricRow(label: "Heart Rate", value: "\(bluetoothService.lastHeartRateValue ?? 0) bpm")
                case .power:
                    MetricRow(label: "Power", value: "\(bluetoothService.lastPowerValue ?? 0) watts")
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("No live data available")
                        .foregroundColor(.gray)
                        .font(.caption)
                    Text("Connect the sensor to see real-time readings")
                        .foregroundColor(.gray)
                        .font(.caption2)
                }
            }
        }
    }

    private func saveSensor() {
        // Update the saved sensor with new name and type
        if isProfileSensor {
            if var savedSensor = bikeStable.profileSensors[currentType.rawValue] {
                // Remove old assignment
                bikeStable.profileSensors.removeValue(forKey: currentType.rawValue)

                // Update sensor
                savedSensor.customName = customName.isEmpty ? nil : customName

                // Create new SavedSensor with new type
                let updatedSensor = SavedSensor(
                    id: savedSensor.id,
                    customName: savedSensor.customName,
                    type: selectedType,
                    deviceName: savedSensor.deviceName
                )

                // Assign with new type
                bikeStable.assignProfileSensor(updatedSensor, type: selectedType)
            }
        } else {
            // Bike sensor
            if let bike = bikeStable.selectedBike,
               let savedSensor = bike.assignedSensors[currentType.rawValue] {

                var updatedBike = bike
                // Remove old assignment
                updatedBike.removeSensor(for: currentType)

                // Update sensor
                let updatedSensor = SavedSensor(
                    id: savedSensor.id,
                    customName: customName.isEmpty ? nil : customName,
                    type: selectedType,
                    deviceName: savedSensor.deviceName
                )

                // Assign with new type
                updatedBike.assignSensor(updatedSensor, for: selectedType)
                bikeStable.updateBike(updatedBike)
            }
        }
    }

    private func forgetSensor() {
        bikeStable.removeSensor(for: currentType)
    }

    private func batteryColor(for level: Int) -> Color {
        switch level {
        case 75...100:
            return .green
        case 25..<75:
            return .yellow
        default:
            return .red
        }
    }
}

struct MetricRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.primary)
        }
    }
}
