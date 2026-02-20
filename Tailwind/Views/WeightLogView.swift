import SwiftUI

struct WeightLogView: View {
    @ObservedObject var weightLogManager: WeightLogManager
    @EnvironmentObject var healthKitService: HealthKitService

    @State private var weightText = ""
    @State private var selectedDate = Date()
    @State private var isSyncing = false
    @State private var syncResult: String?

    var body: some View {
        Form {
            Section("Apple Health Sync") {
                Button {
                    Task { await syncFromHealthKit() }
                } label: {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.red)
                        Text("Import from Health")
                        Spacer()
                        if isSyncing {
                            ProgressView()
                        }
                    }
                }
                .disabled(isSyncing)

                if let result = syncResult {
                    Text(result)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Latest composition snapshot
            if let comp = weightLogManager.latestComposition() {
                Section("Latest Composition") {
                    HStack {
                        Text("Weight")
                        Spacer()
                        Text(String(format: "%.1f lbs", comp.weightLbs))
                            .fontWeight(.medium)
                    }
                    if let lean = comp.leanBodyMassLbs {
                        HStack {
                            Text("Lean Mass")
                            Spacer()
                            Text(String(format: "%.1f lbs", lean))
                                .fontWeight(.medium)
                                .foregroundStyle(.blue)
                        }
                    }
                    if let fat = comp.bodyFatPercentage {
                        HStack {
                            Text("Body Fat")
                            Spacer()
                            Text(String(format: "%.1f%%", fat))
                                .fontWeight(.medium)
                                .foregroundStyle(.orange)
                        }
                    }
                    if let fatMass = comp.fatMassLbs {
                        HStack {
                            Text("Fat Mass")
                            Spacer()
                            Text(String(format: "%.1f lbs", fatMass))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text(comp.formattedDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Log Weight") {
                DatePicker("Date", selection: $selectedDate, displayedComponents: .date)

                HStack {
                    TextField("Weight", text: $weightText)
                        .keyboardType(.decimalPad)
                    Text("lbs")
                        .foregroundStyle(.secondary)
                }

                Button("Save") {
                    if let weight = Double(weightText), weight > 0 {
                        weightLogManager.addEntry(
                            WeightEntry(date: selectedDate, weightLbs: weight)
                        )
                        weightText = ""
                    }
                }
                .disabled(Double(weightText) == nil)
            }

            Section("History (\(weightLogManager.entries.count) entries)") {
                if weightLogManager.entries.isEmpty {
                    Text("No weight entries yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(weightLogManager.entries) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(entry.formattedDate)
                                Spacer()
                                Text(String(format: "%.1f lbs", entry.weightLbs))
                                    .fontWeight(.medium)
                                Text(String(format: "(%.1f kg)", entry.weightKg))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if entry.bodyFatPercentage != nil || entry.leanBodyMassLbs != nil {
                                HStack(spacing: 12) {
                                    if let lean = entry.leanBodyMassLbs {
                                        Label(String(format: "%.1f lbs lean", lean), systemImage: "figure.strengthtraining.traditional")
                                            .font(.caption)
                                            .foregroundStyle(.blue)
                                    }
                                    if let fat = entry.bodyFatPercentage {
                                        Label(String(format: "%.1f%% fat", fat), systemImage: "drop.fill")
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete { offsets in
                        let entriesToDelete = offsets.map { weightLogManager.entries[$0] }
                        for entry in entriesToDelete {
                            weightLogManager.deleteEntry(entry)
                        }
                    }
                }
            }
        }
        .navigationTitle("Weight Log")
    }

    private func syncFromHealthKit() async {
        isSyncing = true
        syncResult = nil

        // Re-request auth to prompt for any new types (lean body mass, body fat)
        try? await healthKitService.requestAuthorization()

        async let weightTask = healthKitService.fetchWeightSamples(days: 365)
        async let leanTask = healthKitService.fetchLeanBodyMassSamples(days: 365)
        async let fatTask = healthKitService.fetchBodyFatSamples(days: 365)

        let weightSamples = await weightTask
        let leanSamples = await leanTask
        let fatSamples = await fatTask

        let added = weightLogManager.syncFromHealthKit(
            weightSamples: weightSamples,
            leanMassSamples: leanSamples,
            bodyFatSamples: fatSamples
        )

        await MainActor.run {
            if weightSamples.isEmpty {
                syncResult = "No weight data found in Apple Health"
            } else if added == 0 {
                syncResult = "Already up to date (\(weightSamples.count) samples checked)"
            } else {
                syncResult = "Imported \(added) entries (weight + composition)"
            }
            isSyncing = false
        }
    }
}
