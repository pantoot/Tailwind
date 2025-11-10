import SwiftUI

struct BikeManagementView: View {
    @EnvironmentObject var bikeStable: BikeStable
    @Environment(\.dismiss) var dismiss
    @State private var showingAddBike = false
    @State private var editingBike: Bike?

    var body: some View {
        NavigationView {
            List {
                ForEach(bikeStable.bikes) { bike in
                    Button(action: {
                        editingBike = bike
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(bike.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text(bike.type.rawValue)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }

                            Spacer()

                            if bikeStable.selectedBikeId == bike.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
                .onDelete(perform: bikeStable.deleteBikes)
            }
            .navigationTitle("Bike Stable")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddBike = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddBike) {
                BikeEditView(bike: nil)
                    .environmentObject(bikeStable)
            }
            .sheet(item: $editingBike) { bike in
                BikeEditView(bike: bike)
                    .environmentObject(bikeStable)
            }
        }
    }
}

struct BikeEditView: View {
    @EnvironmentObject var bikeStable: BikeStable
    @Environment(\.dismiss) var dismiss
    @State private var name: String
    @State private var type: Bike.BikeType

    let bike: Bike?

    init(bike: Bike?) {
        self.bike = bike
        _name = State(initialValue: bike?.name ?? "")
        _type = State(initialValue: bike?.type ?? .road)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Bike Details")) {
                    TextField("Name", text: $name)
                    Picker("Type", selection: $type) {
                        ForEach(Bike.BikeType.allCases, id: \.self) { bikeType in
                            Text(bikeType.rawValue).tag(bikeType)
                        }
                    }
                }

                if let existingBike = bike {
                    Section(header: Text("Maintenance Schedule")) {
                        Button(action: {
                            bikeStable.loadMaintenanceSchedule(for: existingBike.id, bikeName: existingBike.name)
                        }) {
                            HStack {
                                Image(systemName: existingBike.maintenanceItems.isEmpty ? "wrench.and.screwdriver" : "arrow.clockwise")
                                    .foregroundColor(existingBike.maintenanceItems.isEmpty ? .blue : .orange)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(existingBike.maintenanceItems.isEmpty ? "Load Bike-Specific Schedule" : "Reload Schedule")
                                        .font(.body)
                                    if existingBike.maintenanceItems.isEmpty {
                                        Text("Auto-detect maintenance items for this bike")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    } else {
                                        let currentCount = existingBike.maintenanceItems.count
                                        let newCount = getScheduleCount(for: existingBike.name)
                                        Text("Update: \(currentCount) items → \(newCount) items")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                            }
                        }
                    }
                }

                if bike != nil {
                    Section {
                        Button(action: {
                            if let existingBike = bike {
                                bikeStable.deleteBike(existingBike)
                                dismiss()
                            }
                        }) {
                            HStack {
                                Spacer()
                                Text("Delete Bike")
                                    .foregroundColor(.red)
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(bike == nil ? "Add Bike" : "Edit Bike")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveBike()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }

    private func saveBike() {
        if let existingBike = bike {
            // Update existing - preserve maintenance items and total miles
            let updated = Bike(
                id: existingBike.id,
                name: name,
                type: type,
                totalMiles: existingBike.totalMiles,
                maintenanceItems: existingBike.maintenanceItems,
                assignedSensors: existingBike.assignedSensors
            )
            bikeStable.updateBike(updated)
        } else {
            // Add new
            let newBike = Bike(name: name, type: type)
            bikeStable.addBike(newBike)
        }
        dismiss()
    }

    private func getScheduleCount(for bikeName: String) -> Int {
        let lowercaseName = bikeName.lowercased()
        if lowercaseName.contains("951") || lowercaseName.contains("intense") {
            return MaintenanceSchedule.intense951Gravel().count
        } else if lowercaseName.contains("pivot") || lowercaseName.contains("trail") || lowercaseName.contains("429") {
            return MaintenanceSchedule.pivotTrail429EnduroProX0().count
        } else {
            return MaintenanceSchedule.basic().count
        }
    }
}

// Bike selector popup
struct BikeSelectorView: View {
    @EnvironmentObject var bikeStable: BikeStable
    @Environment(\.dismiss) var dismiss
    @State private var showingMaintenance = false
    @State private var showingBikeManagement = false

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Select Bike")) {
                    ForEach(bikeStable.bikes) { bike in
                        Button(action: {
                            bikeStable.selectBike(bike)
                            dismiss()
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(bike.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text(bike.type.rawValue)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }

                                Spacer()

                                if bikeStable.selectedBikeId == bike.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                }

                Section {
                    Button(action: {
                        showingMaintenance = true
                    }) {
                        Label("Maintenance", systemImage: "gearshape.2")
                    }

                    Button(action: {
                        showingBikeManagement = true
                    }) {
                        Label("Manage Bikes", systemImage: "wrench.and.screwdriver")
                    }
                }
            }
            .navigationTitle("Bikes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingMaintenance) {
                if let bike = bikeStable.selectedBike {
                    MaintenanceView(bike: bike)
                        .environmentObject(bikeStable)
                }
            }
            .sheet(isPresented: $showingBikeManagement) {
                BikeManagementView()
                    .environmentObject(bikeStable)
            }
        }
    }
}
