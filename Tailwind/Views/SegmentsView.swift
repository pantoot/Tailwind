import SwiftUI
import MapKit

struct SegmentsView: View {
    @EnvironmentObject var segmentManager: SegmentManager
    @EnvironmentObject var gpsService: GPSService
    @EnvironmentObject var rideHistory: RideHistory
    @Environment(\.dismiss) var dismiss
    @State private var showingCreateSegment = false
    @State private var selectedRide: Ride?

    var body: some View {
        NavigationView {
            List {
                if segmentManager.segments.isEmpty {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "flag.slash")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)
                            Text("No Segments Yet")
                                .font(.headline)
                            Text("Create segments from your saved rides to track your best efforts!")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                    }
                } else {
                    Section(header: Text("Your Segments")) {
                        ForEach(segmentManager.segments) { segment in
                            SegmentRow(segment: segment)
                        }
                        .onDelete { indexSet in
                            indexSet.forEach { index in
                                let segment = segmentManager.segments[index]
                                segmentManager.deleteSegment(segment)
                            }
                        }
                    }
                }

                Section(header: Text("Create Segment")) {
                    Button(action: {
                        showingCreateSegment = true
                    }) {
                        Label("Create from Saved Ride", systemImage: "plus.circle.fill")
                    }
                }
            }
            .navigationTitle("Segments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingCreateSegment) {
                CreateSegmentView()
                    .environmentObject(rideHistory)
                    .environmentObject(segmentManager)
            }
        }
    }
}

struct SegmentRow: View {
    let segment: Segment

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "flag.fill")
                    .foregroundColor(.purple)
                Text(segment.name)
                    .font(.headline)
                Spacer()
                Text(String(format: "%.2f mi", segment.distance))
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            if let bestTime = segment.bestTime {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Best Time")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text(formatTime(bestTime))
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                            .foregroundColor(.green)
                    }

                    if let bestSpeed = segment.bestSpeed {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Avg Speed")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            Text(String(format: "%.1f mph", bestSpeed))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.blue)
                        }
                    }

                    if let bestDate = segment.bestDate {
                        Spacer()
                        Text(bestDate, style: .date)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            } else {
                Text("No attempts yet")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

struct CreateSegmentView: View {
    @EnvironmentObject var rideHistory: RideHistory
    @EnvironmentObject var segmentManager: SegmentManager
    @Environment(\.dismiss) var dismiss

    @State private var selectedRide: Ride?
    @State private var segmentName = ""
    @State private var startIndex = 0
    @State private var endIndex = 0
    @State private var showingSegmentEditor = false

    var body: some View {
        NavigationView {
            VStack {
                if selectedRide == nil {
                    // Ride selection
                    List {
                        Section(header: Text("Select a Ride")) {
                            ForEach(ridesWithRoutes) { ride in
                                Button(action: {
                                    selectedRide = ride
                                    showingSegmentEditor = true
                                }) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(ride.formattedDate)
                                            .font(.headline)
                                        HStack {
                                            Text(ride.formattedDistance)
                                            Text("•")
                                            Text(ride.formattedDuration)
                                            Text("•")
                                            Text(ride.formattedAvgSpeed)
                                        }
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    // Segment editor (simplified - just name for now)
                    VStack(spacing: 20) {
                        Text("Create a segment from your ride")
                            .font(.headline)
                            .padding(.top)

                        Text("For now, segments will be detected automatically based on repeating routes. Give your segment a memorable name!")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        TextField("Segment Name (e.g., 'Hill Climb', 'Sprint Section')", text: $segmentName)
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal)

                        if let ride = selectedRide, let coords = ride.routeCoordinates {
                            // Use first 10% and last 10% as segment
                            let segmentStart = 0
                            let segmentEnd = min(coords.count / 10, coords.count - 1)

                            Button("Create Segment") {
                                createSegment(ride: ride, startIdx: segmentStart, endIdx: segmentEnd)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(segmentName.isEmpty)
                        }

                        Spacer()
                    }
                }
            }
            .navigationTitle("Create Segment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var ridesWithRoutes: [Ride] {
        rideHistory.rides.filter { $0.routeCoordinates != nil && !$0.routeCoordinates!.isEmpty }
    }

    private func createSegment(ride: Ride, startIdx: Int, endIdx: Int) {
        guard let coords = ride.routeCoordinates else { return }

        let clCoords = coords.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        segmentManager.createSegment(name: segmentName, startIndex: startIdx, endIndex: endIdx, routeCoordinates: clCoords)

        dismiss()
    }
}
