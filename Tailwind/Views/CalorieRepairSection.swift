import SwiftUI

/// Recalculates a day's ride calories with the correct formula and rewrites
/// them to Apple Health.
///
/// Self-contained so it can move again: this lived behind an unlabelled
/// wrench icon inside the old ride-history screen, which put a data-repair
/// tool five taps deep in a browse flow. It belongs with the other repair
/// tools in Settings, and Phase 4's Data Maintenance subscreen can relocate
/// this view wholesale rather than re-extracting the logic.
struct CalorieRepairSection: View {
    @EnvironmentObject var rideHistory: RideHistory
    @EnvironmentObject var healthKitService: HealthKitService

    @State private var showingDatePicker = false
    @State private var showingFixAlert = false
    @State private var showingResultAlert = false
    @State private var selectedDate = Date()
    @State private var isFixing = false
    @State private var resultMessage = ""

    var body: some View {
        Button {
            showingDatePicker = true
        } label: {
            HStack {
                Text("Fix Calories for a Date")
                Spacer()
                if isFixing {
                    ProgressView()
                }
            }
        }
        .disabled(isFixing)
        .sheet(isPresented: $showingDatePicker) {
            DatePickerSheet(
                selectedDate: $selectedDate,
                onContinue: {
                    showingDatePicker = false
                    showingFixAlert = true
                },
                onCancel: { showingDatePicker = false }
            )
        }
        .alert("Fix Calories?", isPresented: $showingFixAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Fix Now") { fixCalories() }
        } message: {
            Text(alertMessage)
        }
        .alert("Calorie Fix Results", isPresented: $showingResultAlert) {
            Button("OK") { }
        } message: {
            Text(resultMessage)
        }
    }

    private var alertMessage: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "This will recalculate calories for rides on \(formatter.string(from: selectedDate)) using the correct formula and update them in Apple Health."
    }

    private func fixCalories() {
        isFixing = true
        Task {
            let userProfile = UserProfile.load()
            let message = await rideHistory.fixCalories(
                for: selectedDate,
                userProfile: userProfile,
                healthKitService: healthKitService
            )
            await MainActor.run {
                resultMessage = message
                isFixing = false
                showingResultAlert = true
            }
        }
    }
}

/// Date chooser for the calorie repair flow.
struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    let onContinue: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Select Date to Fix")
                    .font(.headline)

                DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()

                Button(action: onContinue) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding()
            .navigationTitle("Fix Calories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
    }
}
