import SwiftUI

struct MaintenanceView: View {
    @EnvironmentObject var bikeStable: BikeStable
    @Environment(\.dismiss) var dismiss
    @State private var showingAddItem = false
    @State private var selectedItem: MaintenanceItem?

    var bike: Bike

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Total Mileage Card
                    totalMileageCard

                    // Items Due Now
                    if !bike.itemsNeedingService.isEmpty {
                        maintenanceSection(
                            title: "Due Now",
                            items: bike.itemsNeedingService,
                            color: .red,
                            icon: "exclamationmark.triangle.fill"
                        )
                    }

                    // Items Approaching Service
                    if !bike.itemsApproachingService.isEmpty {
                        maintenanceSection(
                            title: "Approaching Service",
                            items: bike.itemsApproachingService,
                            color: .orange,
                            icon: "clock.badge.exclamationmark.fill"
                        )
                    }

                    // All Other Items
                    let otherItems = bike.maintenanceItems.filter { item in
                        !bike.itemsNeedingService.contains(where: { $0.id == item.id }) &&
                        !bike.itemsApproachingService.contains(where: { $0.id == item.id })
                    }

                    if !otherItems.isEmpty {
                        maintenanceSection(
                            title: "Good Condition",
                            items: otherItems,
                            color: .green,
                            icon: "checkmark.circle.fill"
                        )
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Maintenance: \(bike.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddItem = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddItem) {
                MaintenanceItemEditView(bike: bike, item: nil)
                    .environmentObject(bikeStable)
            }
            .sheet(item: $selectedItem) { item in
                MaintenanceItemDetailView(bike: bike, item: item)
                    .environmentObject(bikeStable)
            }
        }
    }

    private var totalMileageCard: some View {
        VStack(spacing: 8) {
            Text("Total Mileage")
                .font(.headline)
                .foregroundColor(.secondary)

            Text(String(format: "%.1f mi", bike.totalMiles))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func maintenanceSection(title: String, items: [MaintenanceItem], color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 8) {
                ForEach(items) { item in
                    Button(action: {
                        selectedItem = item
                    }) {
                        MaintenanceItemRow(bike: bike, item: item, statusColor: color)
                    }
                }
            }
        }
    }
}

struct MaintenanceItemRow: View {
    let bike: Bike
    let item: MaintenanceItem
    let statusColor: Color

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    if item.intervalMiles != nil {
                        let remaining = item.milesUntilService(currentMiles: bike.totalMiles)
                        Text(remaining > 0 ? "\(Int(remaining)) mi until service" : "Service overdue")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if let intervalHours = item.intervalHours {
                        Text("Every \(Int(intervalHours)) hours")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Progress bar for mileage-based items
            if item.intervalMiles != nil {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))

                        Rectangle()
                            .fill(statusColor)
                            .frame(width: geometry.size.width * CGFloat(min(1.0, item.servicePercentage(currentMiles: bike.totalMiles) / 100)))
                    }
                }
                .frame(height: 6)
                .clipShape(Capsule())
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct MaintenanceItemDetailView: View {
    @EnvironmentObject var bikeStable: BikeStable
    @Environment(\.dismiss) var dismiss
    @State private var showingEditView = false
    @State private var showingDeleteAlert = false

    let bike: Bike
    let item: MaintenanceItem

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Details")) {
                    LabeledContent("Component", value: item.name)

                    if let intervalMiles = item.intervalMiles {
                        LabeledContent("Service Interval", value: "\(Int(intervalMiles)) miles")
                    }

                    if let intervalHours = item.intervalHours {
                        LabeledContent("Time Interval", value: "\(Int(intervalHours)) hours")
                    }

                    if !item.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(item.notes)
                                .font(.body)
                        }
                    }
                }

                Section(header: Text("Service Status")) {
                    if item.intervalMiles != nil {
                        let percentage = item.servicePercentage(currentMiles: bike.totalMiles)
                        let remaining = item.milesUntilService(currentMiles: bike.totalMiles)

                        LabeledContent("Progress", value: "\(Int(percentage))%")
                        LabeledContent("Miles Until Service", value: "\(Int(max(0, remaining))) mi")
                        LabeledContent("Last Service", value: "\(Int(item.lastServiceMiles)) mi")
                    }

                    LabeledContent("Last Service Date", value: item.lastServiceDate.formatted(date: .abbreviated, time: .omitted))
                }

                Section {
                    Button(action: {
                        bikeStable.markServiceComplete(bikeId: bike.id, maintenanceItemId: item.id)
                        dismiss()
                    }) {
                        HStack {
                            Spacer()
                            Label("Mark as Complete", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Spacer()
                        }
                    }
                }

                Section {
                    Button(action: {
                        showingEditView = true
                    }) {
                        HStack {
                            Spacer()
                            Text("Edit Item")
                            Spacer()
                        }
                    }

                    Button(role: .destructive, action: {
                        showingDeleteAlert = true
                    }) {
                        HStack {
                            Spacer()
                            Text("Delete Item")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle(item.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingEditView) {
                MaintenanceItemEditView(bike: bike, item: item)
                    .environmentObject(bikeStable)
            }
            .alert("Delete Item", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    bikeStable.deleteMaintenanceItem(from: bike.id, itemId: item.id)
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to delete this maintenance item?")
            }
        }
    }
}

struct MaintenanceItemEditView: View {
    @EnvironmentObject var bikeStable: BikeStable
    @Environment(\.dismiss) var dismiss

    let bike: Bike
    let item: MaintenanceItem?

    @State private var name: String
    @State private var intervalMiles: String
    @State private var intervalHours: String
    @State private var notes: String
    @State private var useMileInterval: Bool

    init(bike: Bike, item: MaintenanceItem?) {
        self.bike = bike
        self.item = item
        _name = State(initialValue: item?.name ?? "")
        _intervalMiles = State(initialValue: item?.intervalMiles.map { String(Int($0)) } ?? "")
        _intervalHours = State(initialValue: item?.intervalHours.map { String(Int($0)) } ?? "")
        _notes = State(initialValue: item?.notes ?? "")
        _useMileInterval = State(initialValue: item?.intervalMiles != nil)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Item Details")) {
                    TextField("Component Name", text: $name)

                    Picker("Interval Type", selection: $useMileInterval) {
                        Text("Miles").tag(true)
                        Text("Hours").tag(false)
                    }
                    .pickerStyle(.segmented)

                    if useMileInterval {
                        TextField("Service Interval (miles)", text: $intervalMiles)
                            .keyboardType(.numberPad)
                    } else {
                        TextField("Service Interval (hours)", text: $intervalHours)
                            .keyboardType(.numberPad)
                    }
                }

                Section(header: Text("Notes")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle(item == nil ? "Add Item" : "Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveItem()
                    }
                    .disabled(name.isEmpty || (useMileInterval ? intervalMiles.isEmpty : intervalHours.isEmpty))
                }
            }
        }
    }

    private func saveItem() {
        let miles = useMileInterval ? Double(intervalMiles) : nil
        let hours = !useMileInterval ? Double(intervalHours) : nil

        if let existingItem = item {
            // Update existing
            let updated = MaintenanceItem(
                id: existingItem.id,
                name: name,
                intervalMiles: miles,
                intervalHours: hours,
                lastServiceMiles: existingItem.lastServiceMiles,
                lastServiceDate: existingItem.lastServiceDate,
                notes: notes
            )
            bikeStable.updateMaintenanceItem(bikeId: bike.id, item: updated)
        } else {
            // Add new
            let newItem = MaintenanceItem(
                name: name,
                intervalMiles: miles,
                intervalHours: hours,
                notes: notes
            )
            bikeStable.addMaintenanceItem(to: bike.id, item: newItem)
        }

        dismiss()
    }
}
