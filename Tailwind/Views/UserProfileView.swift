import SwiftUI

struct UserProfileView: View {
    @EnvironmentObject var sensorDataService: SensorDataService
    @EnvironmentObject var healthKitService: HealthKitService
    @EnvironmentObject var rideHistory: RideHistory
    @Environment(\.dismiss) var dismiss
    @State private var birthday: Date
    @State private var weight: Double
    @State private var gender: UserProfile.Gender
    @State private var lactateThresholdHR: String
    @State private var maxHeartRate: String
    @State private var showingSaveConfirmation = false
    @State private var showingMaxHRAlert = false

    init() {
        let profile = UserProfile.load()
        _birthday = State(initialValue: profile.birthday)
        _weight = State(initialValue: profile.weight)
        _gender = State(initialValue: profile.gender)
        _lactateThresholdHR = State(initialValue: profile.lactateThresholdHR.map { String($0) } ?? "")
        _maxHeartRate = State(initialValue: profile.maxHeartRate.map { String($0) } ?? "")
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Personal Information")) {
                    DatePicker("Birthday", selection: $birthday, displayedComponents: .date)
                        .datePickerStyle(.compact)

                    HStack {
                        Text("Current Age")
                        Spacer()
                        Text("\(calculatedAge) years")
                            .foregroundColor(.gray)
                    }

                    HStack {
                        Text("Weight")
                        Spacer()
                        TextField("Weight", value: $weight, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("lbs")
                            .foregroundColor(.gray)
                    }

                    Picker("Gender", selection: $gender) {
                        ForEach(UserProfile.Gender.allCases, id: \.self) { gender in
                            Text(gender.rawValue).tag(gender)
                        }
                    }
                }

                Section(header: Text("Training Zones")) {
                    HStack {
                        Text("LTHR (Threshold)")
                        Spacer()
                        TextField("LTHR", text: $lactateThresholdHR)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("bpm")
                            .foregroundColor(.gray)
                    }

                    HStack {
                        Text("Max Heart Rate")
                        Spacer()
                        TextField("Max HR", text: $maxHeartRate)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("bpm")
                            .foregroundColor(.gray)
                    }

                    HStack {
                        Text("Estimated Max HR")
                        Spacer()
                        Text("\(220 - calculatedAge) bpm")
                            .foregroundColor(.gray)
                    }

                    // Recorded max HR from ride history
                    if let recordedMax = recordedMaxHR {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Recorded Max HR")
                                Text("Highest seen across all rides")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("\(recordedMax) bpm")
                                .foregroundColor(recordedMax > (Int(maxHeartRate) ?? 0) ? .orange : .green)
                                .fontWeight(.semibold)
                            if recordedMax > (Int(maxHeartRate) ?? 0) {
                                Button("Use") {
                                    maxHeartRate = "\(recordedMax)"
                                    showingMaxHRAlert = true
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                .tint(.orange)
                            }
                        }
                        .alert("Max HR Updated", isPresented: $showingMaxHRAlert) {
                            Button("OK") {}
                        } message: {
                            Text("Max HR set to \(recordedMax) bpm based on your ride history. Save your profile to apply this change.")
                        }
                    }
                }

                Section(header: Text("About Training Zones")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("LTHR (Lactate Threshold Heart Rate)")
                            .font(.headline)
                        Text("Your LTHR is used to calculate your training zones for power zone training. To find it, do a 30-min time trial, then use your average HR for the last 20 minutes.")
                            .font(.caption)
                            .foregroundColor(.gray)

                        Text("Max Heart Rate")
                            .font(.headline)
                            .padding(.top, 8)
                        Text("Optional. If not provided, we'll estimate using the 220-age formula. Your actual max may vary. Tailwind will show your highest recorded HR from rides and let you update your profile directly.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                }

                Section(header: Text("Apple Health")) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Sync with Apple Health")
                                .font(.headline)
                            if healthKitService.isAuthorized {
                                Text("Authorized ✓")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            } else {
                                Text("Not Authorized")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        if !healthKitService.isAuthorized {
                            Button("Enable") {
                                Task {
                                    try? await healthKitService.requestAuthorization()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }

                    Text("Sync your rides to Apple Health to close your Activity rings and track workouts on your Apple Watch.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section(header: Text("Why We Need This")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Calorie Calculation")
                            .font(.headline)
                        Text("Your birthday, weight, and gender are used with your heart rate to accurately calculate calories burned during rides. Your age is automatically calculated from your birthday.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    Button(action: saveProfile) {
                        HStack {
                            Spacer()
                            Text("Save Profile")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("User Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Profile Saved", isPresented: $showingSaveConfirmation) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your profile has been updated. Calorie calculations will now use your information.")
            }
        }
    }

    /// Highest max heart rate recorded across all rides in history
    private var recordedMaxHR: Int? {
        let maxes = rideHistory.rides.map { $0.maxHeartRate }.filter { $0 > 100 }
        return maxes.max()
    }

    private var calculatedAge: Int {
        let calendar = Calendar.current
        let now = Date()
        let ageComponents = calendar.dateComponents([.year], from: birthday, to: now)
        return ageComponents.year ?? 0
    }

    private func saveProfile() {
        let profile = UserProfile(
            birthday: birthday,
            weight: weight,
            gender: gender,
            heightInches: nil,
            lactateThresholdHR: Int(lactateThresholdHR),
            maxHeartRate: Int(maxHeartRate)
        )
        profile.save()
        sensorDataService.userProfile = profile
        showingSaveConfirmation = true
    }
}
