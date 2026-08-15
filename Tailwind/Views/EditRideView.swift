import SwiftUI

struct EditRideView: View {
    let ride: Ride
    let onSave: (Ride) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var distance: String
    @State private var avgSpeed: String
    @State private var maxSpeed: String
    @State private var calories: String
    @State private var avgHeartRate: String
    @State private var maxHeartRate: String
    @State private var notes: String

    init(ride: Ride, onSave: @escaping (Ride) -> Void) {
        self.ride = ride
        self.onSave = onSave
        _distance = State(initialValue: String(format: "%.2f", ride.distance))
        _avgSpeed = State(initialValue: String(format: "%.1f", ride.averageSpeed))
        _maxSpeed = State(initialValue: String(format: "%.1f", ride.maxSpeed))
        _calories = State(initialValue: String(format: "%.0f", ride.calories))
        _avgHeartRate = State(initialValue: ride.averageHeartRate > 0 ? String(format: "%.0f", ride.averageHeartRate) : "")
        _maxHeartRate = State(initialValue: ride.maxHeartRate > 0 ? "\(ride.maxHeartRate)" : "")
        _notes = State(initialValue: ride.notes ?? "")
    }

    /// Whether the user actually edited the average HR field this session.
    private var hrChanged: Bool {
        let original = ride.averageHeartRate > 0 ? String(format: "%.0f", ride.averageHeartRate) : ""
        return avgHeartRate != original
    }

    private var computedTSS: Double? {
        // Keep the stored score (which may be NP/power-based) unless HR was actually
        // edited — recomputing from HR here would silently switch methodology on
        // every unrelated edit.
        guard hrChanged else { return ride.hrTSS }

        let profile = UserProfile.load()
        let dur = ride.duration
        guard dur > 0 else { return nil }

        // HR-based TSS
        if let hr = Double(avgHeartRate), hr > 0,
           let lthr = profile.lactateThresholdHR, lthr > 0 {
            let hrIntensity = hr / Double(lthr)
            let hours = dur / 3600
            return hours * hrIntensity * hrIntensity * 100
        }

        return ride.hrTSS
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Ride Metrics") {
                    fieldRow("Distance", value: $distance, unit: "mi", keyboard: .decimalPad)
                    fieldRow("Avg Speed", value: $avgSpeed, unit: "mph", keyboard: .decimalPad)
                    fieldRow("Max Speed", value: $maxSpeed, unit: "mph", keyboard: .decimalPad)
                    fieldRow("Calories", value: $calories, unit: "kcal", keyboard: .numberPad)
                }

                Section("Heart Rate") {
                    fieldRow("Avg HR", value: $avgHeartRate, unit: "bpm", keyboard: .numberPad)
                    fieldRow("Max HR", value: $maxHeartRate, unit: "bpm", keyboard: .numberPad)
                }

                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                if let tss = computedTSS {
                    Section {
                        HStack {
                            Text("Estimated TSS")
                            Spacer()
                            Text(String(format: "%.0f", tss))
                                .fontWeight(.bold)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            .navigationTitle("Edit Ride")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func fieldRow(_ label: String, value: Binding<String>, unit: String, keyboard: UIKeyboardType) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: value)
                .keyboardType(keyboard)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
            Text(unit)
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .leading)
        }
    }

    private func save() {
        let updatedRide = Ride(
            id: ride.id,
            date: ride.date,
            duration: ride.duration,
            distance: Double(distance) ?? ride.distance,
            averageSpeed: Double(avgSpeed) ?? ride.averageSpeed,
            maxSpeed: Double(maxSpeed) ?? ride.maxSpeed,
            averageHeartRate: Double(avgHeartRate) ?? ride.averageHeartRate,
            maxHeartRate: Int(maxHeartRate) ?? ride.maxHeartRate,
            calories: Double(calories) ?? ride.calories,
            averagePower: ride.averagePower,
            averageCadence: ride.averageCadence,
            elevationGain: ride.elevationGain,
            averageTemperatureCelsius: ride.averageTemperatureCelsius,
            routeCoordinates: ride.routeCoordinates,
            routePointCount: ride.routePointCount,
            notes: notes.isEmpty ? ride.notes : notes,
            bikeName: ride.bikeName,
            bikeType: ride.bikeType,
            timeInZone: ride.timeInZone,
            hrTSS: computedTSS ?? ride.hrTSS,
            creatineMetrics: ride.creatineMetrics
        )
        onSave(updatedRide)
        dismiss()
    }
}
