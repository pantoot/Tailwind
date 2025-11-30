import SwiftUI
import UniformTypeIdentifiers

/// Main view for FIT file import - the core of the pivoted app
struct ImportView: View {
    @EnvironmentObject var fitImportService: FITImportService
    @EnvironmentObject var rideHistory: RideHistory
    @EnvironmentObject var healthKitService: HealthKitService

    @State private var showingFilePicker = false
    @State private var showingImportSuccess = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isDropTargeted = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Import area
                    importSection

                    // Recent imports
                    if !rideHistory.rides.isEmpty {
                        recentImportsSection
                    }

                    // Stats summary
                    if !rideHistory.rides.isEmpty {
                        statsSection
                    }

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .navigationTitle("Tailwind")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gear")
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [UTType(filenameExtension: "fit") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .alert("Import Successful", isPresented: $showingImportSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            if let ride = fitImportService.lastImportedRide {
                Text("\(ride.formattedDistance) ride saved to Apple Health with \(ride.maxHeartRate > 0 ? "heart rate data" : "workout data")")
            }
        }
        .alert("Import Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onOpenURL { url in
            // Handle FIT files opened via Share Extension
            if url.pathExtension.lowercased() == "fit" {
                Task {
                    await importFile(from: url)
                }
            }
        }
    }

    // MARK: - Import Section

    private var importSection: some View {
        VStack(spacing: 16) {
            // Drop zone / import button
            Button(action: { showingFilePicker = true }) {
                VStack(spacing: 16) {
                    if fitImportService.isImporting {
                        ProgressView()
                            .scaleEffect(1.5)
                            .frame(width: 60, height: 60)
                    } else {
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.blue)
                    }

                    VStack(spacing: 4) {
                        Text(fitImportService.isImporting ? "Importing..." : "Import FIT File")
                            .font(.headline)

                        Text("From Magene or other cycling computers")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isDropTargeted ? Color.blue.opacity(0.1) : Color(.systemGray6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(
                                    style: StrokeStyle(lineWidth: 2, dash: [8])
                                )
                                .foregroundStyle(isDropTargeted ? .blue : .gray.opacity(0.3))
                        )
                )
            }
            .buttonStyle(.plain)
            .disabled(fitImportService.isImporting)
            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                handleDrop(providers: providers)
            }

            // Quick tip
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                Text("Tip: Share FIT files directly from Magene app")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Recent Imports Section

    private var recentImportsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Rides")
                    .font(.headline)
                Spacer()
                NavigationLink("See All") {
                    RideHistoryView()
                }
                .font(.subheadline)
            }

            VStack(spacing: 8) {
                ForEach(rideHistory.rides.prefix(3)) { ride in
                    NavigationLink(destination: RideDetailView(ride: ride)) {
                        RideRowView(ride: ride)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All Time")
                .font(.headline)

            HStack(spacing: 16) {
                StatCard(
                    title: "Rides",
                    value: "\(rideHistory.totalRides)",
                    icon: "bicycle"
                )

                StatCard(
                    title: "Miles",
                    value: String(format: "%.0f", rideHistory.totalDistance),
                    icon: "road.lanes"
                )

                StatCard(
                    title: "Calories",
                    value: formatCalories(rideHistory.totalCalories),
                    icon: "flame.fill"
                )
            }
        }
    }

    // MARK: - Helpers

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task {
                await importFile(from: url)
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
            if let data = item as? Data,
               let url = URL(dataRepresentation: data, relativeTo: nil) {
                Task {
                    await importFile(from: url)
                }
            }
        }
        return true
    }

    private func importFile(from url: URL) async {
        do {
            _ = try await fitImportService.importFITFile(from: url)
            await MainActor.run {
                showingImportSuccess = true
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }

    private func formatCalories(_ calories: Double) -> String {
        if calories >= 1000 {
            return String(format: "%.1fk", calories / 1000)
        }
        return String(format: "%.0f", calories)
    }
}

// MARK: - Supporting Views

struct RideRowView: View {
    let ride: Ride

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(ride.formattedDate)
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 12) {
                    Label(ride.formattedDistance, systemImage: "road.lanes")
                    Label(ride.formattedDuration, systemImage: "clock")
                    if ride.averageHeartRate > 0 {
                        Label("\(Int(ride.averageHeartRate))", systemImage: "heart.fill")
                            .foregroundStyle(.red)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Simplified Settings View

struct SettingsView: View {
    @EnvironmentObject var healthKitService: HealthKitService

    var body: some View {
        List {
            Section("Health") {
                HStack {
                    Label("Apple Health", systemImage: "heart.fill")
                    Spacer()
                    if healthKitService.isAuthorized {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button("Connect") {
                            Task {
                                try? await healthKitService.requestAuthorization()
                            }
                        }
                    }
                }
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("2.0")
                        .foregroundStyle(.secondary)
                }

                Link(destination: URL(string: "https://github.com/pantoot/Tailwind")!) {
                    HStack {
                        Text("GitHub")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Text("Tailwind imports FIT files from Magene and other cycling computers directly into Apple Health, preserving all heart rate data.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    ImportView()
        .environmentObject(FITImportService(
            healthKitService: HealthKitService(),
            rideHistory: RideHistory()
        ))
        .environmentObject(RideHistory())
        .environmentObject(HealthKitService())
}
