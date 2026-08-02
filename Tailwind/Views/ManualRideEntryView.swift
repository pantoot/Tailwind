import SwiftUI

struct ManualRideEntryView: View {
    @EnvironmentObject var healthKitService: HealthKitService
    @EnvironmentObject var rideHistory: RideHistory
    @EnvironmentObject var trainingLoadManager: TrainingLoadManager
    @Environment(\.dismiss) private var dismiss

    // Ride data fields
    @State private var rideDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
    @State private var rideTime = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var durationMinutes = ""
    @State private var calories = ""
    @State private var distance = ""
    @State private var averagePower = ""
    @State private var averageHR = ""
    @State private var maxHR = ""
    @State private var averageCadence = ""
    @State private var averageSpeed = ""
    @State private var maxSpeed = ""
    @State private var notes = "Peloton (manual entry)"

    @State private var isSaving = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingSuccess = false

    var body: some View {
        NavigationStack {
            Form {
                Section("When") {
                    DatePicker("Date", selection: $rideDate, displayedComponents: .date)
                    DatePicker("Start Time", selection: $rideTime, displayedComponents: .hourAndMinute)
                }

                Section("Workout Data") {
                    numberField("Duration (minutes)", text: $durationMinutes)
                    numberField("Calories (kcal)", text: $calories)
                    numberField("Distance (miles)", text: $distance)
                    numberField("Avg Speed (mph)", text: $averageSpeed)
                    numberField("Max Speed (mph)", text: $maxSpeed)
                }

                Section("Power & HR") {
                    numberField("Avg Power (watts)", text: $averagePower)
                    numberField("Avg Cadence (rpm)", text: $averageCadence)
                    numberField("Avg Heart Rate (bpm)", text: $averageHR)
                    numberField("Max Heart Rate (bpm)", text: $maxHR)
                }

                Section("Notes") {
                    TextField("Notes", text: $notes)
                }

                Section {
                    Button(action: saveRide) {
                        HStack {
                            if isSaving {
                                ProgressView()
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                            }
                            Text(isSaving ? "Saving..." : "Save Ride & Write to Apple Health")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(isSaving || !isValid)
                } footer: {
                    Text("Creates a cycling workout in Apple Health with Active Energy for Move ring credit.")
                        .font(.caption)
                }
            }
            .navigationTitle("Manual Ride")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("Ride Saved", isPresented: $showingSuccess) {
                Button("Done") { dismiss() }
            } message: {
                Text("Ride added to Tailwind and written to Apple Health. Your Move ring should update shortly.")
            }
        }
    }

    private var isValid: Bool {
        guard let dur = Double(durationMinutes), dur > 0 else { return false }
        guard let cal = Double(calories), cal > 0 else { return false }
        return true
    }

    private func numberField(_ label: String, text: Binding<String>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 100)
        }
    }

    private func saveRide() {
        guard let dur = Double(durationMinutes), dur > 0,
              let cal = Double(calories), cal > 0 else { return }

        isSaving = true

        // Combine date and time
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: rideDate)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: rideTime)
        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute
        let startDate = calendar.date(from: combined) ?? rideDate

        Task {
            do {
                let ride = try await healthKitService.createManualWorkout(
                    startDate: startDate,
                    duration: dur * 60, // convert minutes to seconds
                    calories: cal,
                    distance: Double(distance) ?? 0,
                    averagePower: Double(averagePower),
                    averageHeartRate: Double(averageHR),
                    maxHeartRate: Int(maxHR),
                    averageCadence: Double(averageCadence),
                    averageSpeed: Double(averageSpeed),
                    maxSpeed: Double(maxSpeed),
                    notes: notes.isEmpty ? nil : notes
                )

                await MainActor.run {
                    rideHistory.saveRide(ride)

                    if let tss = ride.hrTSS {
                        trainingLoadManager.addTSS(date: ride.date, tss: tss)
                    }

                    rideHistory.sortByDate()
                    isSaving = false
                    showingSuccess = true
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}
