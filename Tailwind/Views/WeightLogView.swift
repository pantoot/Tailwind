import SwiftUI

struct WeightLogView: View {
    @ObservedObject var weightLogManager: WeightLogManager

    @State private var weightText = ""
    @State private var selectedDate = Date()

    var body: some View {
        Form {
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

            Section("History") {
                if weightLogManager.entries.isEmpty {
                    Text("No weight entries yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(weightLogManager.entries) { entry in
                        HStack {
                            Text(entry.formattedDate)
                            Spacer()
                            Text(String(format: "%.1f lbs", entry.weightLbs))
                                .fontWeight(.medium)
                            Text(String(format: "(%.1f kg)", entry.weightKg))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
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
}
