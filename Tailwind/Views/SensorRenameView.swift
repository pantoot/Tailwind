import SwiftUI

struct SensorRenameView: View {
    @EnvironmentObject var bikeStable: BikeStable
    @Environment(\.dismiss) var dismiss
    let sensorType: SensorType
    let initialName: String
    @State private var newName: String

    init(sensorType: SensorType, initialName: String) {
        self.sensorType = sensorType
        self.initialName = initialName
        _newName = State(initialValue: initialName)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Sensor Name")) {
                    TextField("Name", text: $newName)
                        .textInputAutocapitalization(.words)
                }

                Section {
                    Text("This name will help you identify this sensor.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("Rename Sensor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveName()
                        dismiss()
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func saveName() {
        guard var savedSensor = bikeStable.getSensor(for: sensorType) else { return }

        savedSensor.customName = newName.trimmingCharacters(in: .whitespaces)

        if sensorType.isProfileSensor {
            bikeStable.assignProfileSensor(savedSensor, type: sensorType)
        } else {
            bikeStable.assignSensorToBike(savedSensor, type: sensorType)
        }
    }
}
