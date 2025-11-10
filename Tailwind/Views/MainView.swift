import SwiftUI
import CoreBluetooth
import MapKit

struct MainView: View {
    @EnvironmentObject var bluetoothService: BluetoothService
    @EnvironmentObject var sensorDataService: SensorDataService
    @EnvironmentObject var gpsService: GPSService
    @EnvironmentObject var rideHistory: RideHistory
    @EnvironmentObject var bikeStable: BikeStable
    @EnvironmentObject var trainingLoadManager: TrainingLoadManager
    @EnvironmentObject var healthKitService: HealthKitService
    @EnvironmentObject var backgroundAudioService: BackgroundAudioService
    @EnvironmentObject var routeMatchingService: RouteMatchingService
    @EnvironmentObject var segmentManager: SegmentManager
    @EnvironmentObject var audioCueService: AudioCueService
    @EnvironmentObject var phoneConnectivity: PhoneConnectivityManager
    @State private var showingSensorSettings = false
    @State private var showingUserProfile = false
    @State private var showingRideHistory = false
    @State private var showingBikeSelector = false
    @State private var showingBikeManagement = false
    @State private var showingMaintenance = false
    @State private var showSpeedHeatmap = false
    @State private var landscapeViewIndex = 0 // 0 = simple metrics, 1 = detailed metrics
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 33.4484, longitude: -112.0740), // Phoenix default
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
    )
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass

    var isLandscape: Bool {
        verticalSizeClass == .compact
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea(edges: isLandscape ? .all : .bottom)

                if isLandscape {
                    landscapeLayout
                } else {
                    portraitLayout
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(isLandscape ? .hidden : .visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 12) {
                        Button(action: {
                            showingUserProfile = true
                        }) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }

                        // Bike selector button
                        Button(action: {
                            showingBikeSelector = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "bicycle")
                                    .font(.system(size: 14))
                                Text(bikeStable.selectedBike?.name ?? "Select Bike")
                                    .font(.system(size: 14, weight: .semibold))
                                    .lineLimit(1)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Capsule())
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingSensorSettings = true
                    }) {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                }
            }
            .sheet(isPresented: $showingSensorSettings) {
                SensorSettingsView()
                    .environmentObject(bluetoothService)
                    .environmentObject(trainingLoadManager)
                    .environmentObject(routeMatchingService)
                    .environmentObject(bikeStable)
                    .environmentObject(segmentManager)
                    .environmentObject(gpsService)
                    .environmentObject(rideHistory)
            }
            .sheet(isPresented: $showingUserProfile) {
                UserProfileView()
                    .environmentObject(sensorDataService)
            }
            .sheet(isPresented: $showingRideHistory) {
                RideHistoryView()
                    .environmentObject(rideHistory)
            }
            .sheet(isPresented: $showingBikeSelector) {
                BikeSelectorView()
                    .environmentObject(bikeStable)
            }
            .sheet(isPresented: $showingBikeManagement) {
                BikeManagementView()
                    .environmentObject(bikeStable)
            }
            .sheet(isPresented: $showingMaintenance) {
                if let bike = bikeStable.selectedBike {
                    MaintenanceView(bike: bike)
                        .environmentObject(bikeStable)
                }
            }
            .onChange(of: gpsService.currentLocation) { oldValue, newValue in
                if let location = newValue {
                    // Update camera to follow user location
                    cameraPosition = .region(
                        MKCoordinateRegion(
                            center: location.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        )
                    )
                }
            }
            .onChange(of: sensorDataService.sensorData.distance) { oldValue, newValue in
                // Check for 5-mile splits
                if sensorDataService.isRecording && !sensorDataService.isPaused {
                    audioCueService.checkForMileSplit(
                        currentDistance: newValue,
                        currentSpeed: sensorDataService.sensorData.speed
                    )
                }
            }
            .onAppear {
                // Request GPS permission on startup, but don't start tracking yet
                // GPS will only track during active rides (started in handleStartStop)
                if gpsService.locationPermission == .notDetermined {
                    gpsService.requestPermission()
                }

                // Start timer to send updates to Apple Watch
                Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                    sendWatchUpdate()
                }
            }
        }
    }

    // MARK: - Landscape Layout
    var landscapeLayout: some View {
        Group {
            if landscapeViewIndex == 0 {
                landscapeSimpleMetrics
            } else {
                landscapeDetailedMetrics
            }
        }
    }

    // MARK: - Landscape Simple Metrics (Default)
    var landscapeSimpleMetrics: some View {
        HStack(spacing: 0) {
            // Left: Map (50% width)
            landscapeMapView
                .frame(maxWidth: .infinity)

            // Right: Metrics (50% width)
            VStack(spacing: 0) {
                Spacer()

                // Large Speed Display with dynamic color
                VStack(spacing: 4) {
                    Text(sensorDataService.sensorData.formattedSpeed)
                        .font(.system(size: 120, weight: .bold, design: .rounded))
                        .foregroundStyle(speedColor)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text("MPH")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.gray)
                        .tracking(2)
                }
                .padding(.bottom, 20)

                // Four Key Metrics
                VStack(spacing: 12) {
                    // Row 1: Time and Distance
                    HStack(spacing: 12) {
                        SimpleLandscapeMetric(
                            value: sensorDataService.sensorData.formattedDuration,
                            label: "TIME",
                            color: .cyan
                        )
                        SimpleLandscapeMetric(
                            value: sensorDataService.sensorData.formattedDistance,
                            label: "MILES",
                            color: .blue
                        )
                    }

                    // Row 2: Calories and Heart Rate
                    HStack(spacing: 12) {
                        SimpleLandscapeMetric(
                            value: String(format: "%.0f", sensorDataService.sensorData.calories),
                            label: "CALORIES",
                            color: .orange
                        )
                        SimpleLandscapeMetric(
                            value: "\(sensorDataService.sensorData.heartRate)",
                            label: "BPM",
                            color: .red
                        )
                    }
                }
                .padding(.horizontal, 16)

                Spacer()

                // Buttons
                landscapeButtons
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity)
        }
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    if value.translation.width < 0 {
                        // Swipe left - next view
                        landscapeViewIndex = 1
                    } else if value.translation.width > 0 && landscapeViewIndex > 0 {
                        // Swipe right - previous view
                        landscapeViewIndex = 0
                    }
                }
        )
    }

    // MARK: - Landscape Detailed Metrics (Original)
    var landscapeDetailedMetrics: some View {
        HStack(spacing: 0) {
            // Left: Map (50% width)
            landscapeMapView
                .frame(maxWidth: .infinity)

            // Right: Metrics (50% width)
            VStack(spacing: 8) {
                Spacer()

                // Speed
                VStack(spacing: 0) {
                    Text(sensorDataService.sensorData.formattedSpeed)
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(colors: [.green, .cyan], startPoint: .leading, endPoint: .trailing)
                        )
                    Text("MPH")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.gray)
                        .tracking(1)
                }

                // Metrics
                VStack(spacing: 5) {
                    HStack(spacing: 5) {
                        LandscapeMetricCard(icon: "heart.fill", value: "\(sensorDataService.sensorData.heartRate)", unit: "bpm", color: .red)
                        LandscapeMetricCard(icon: "flame.fill", value: String(format: "%.0f", sensorDataService.sensorData.calories), unit: "cal", color: .orange)
                    }
                    HStack(spacing: 5) {
                        LandscapeMetricCard(icon: "map.fill", value: sensorDataService.sensorData.formattedDistance, unit: "mi", color: .blue)
                        LandscapeMetricCard(icon: "clock.fill", value: sensorDataService.sensorData.formattedDuration, unit: "", color: .purple)
                    }
                    HStack(spacing: 5) {
                        LandscapeMetricCard(icon: "mountain.2.fill", value: String(format: "%.0f", gpsService.currentAltitude), unit: "ft", color: .teal)
                        LandscapeMetricCard(icon: "arrow.up.forward", value: String(format: "%.0f", gpsService.totalElevationGain), unit: "ft", color: .green)
                    }
                }
                .padding(.horizontal, 8)

                Spacer()

                // Buttons
                landscapeButtons
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity)
        }
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    if value.translation.width > 0 {
                        // Swipe right - previous view
                        landscapeViewIndex = 0
                    } else if value.translation.width < 0 && landscapeViewIndex < 1 {
                        // Swipe left - next view (but we only have 2 views)
                        landscapeViewIndex = 1
                    }
                }
        )
    }

    // MARK: - Portrait Layout
    var portraitLayout: some View {
        VStack(spacing: 0) {
            // Map
            ZStack(alignment: .top) {
                Map(position: $cameraPosition) {
                    UserAnnotation()

                    // Show route polyline if tracking
                    if !gpsService.routeCoordinates.isEmpty {
                        if showSpeedHeatmap {
                            // Speed-based heatmap
                            ForEach(Array(getSpeedSegments().enumerated()), id: \.offset) { index, segment in
                                MapPolyline(coordinates: segment.coordinates)
                                    .stroke(segment.color, lineWidth: 5)
                            }
                        } else {
                            // Standard gradient
                            MapPolyline(coordinates: gpsService.routeCoordinates)
                                .stroke(
                                    LinearGradient(
                                        colors: [.green, .cyan, .blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    lineWidth: 5
                                )
                        }

                        // Start marker
                        if let firstCoord = gpsService.routeCoordinates.first {
                            Annotation("Start", coordinate: firstCoord) {
                                ZStack {
                                    Circle()
                                        .fill(.green)
                                        .frame(width: 24, height: 24)
                                        .shadow(radius: 3)
                                    Image(systemName: "figure.outdoor.cycle")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                        }

                        // Mile markers
                        ForEach(gpsService.getMileMarkers(), id: \.mile) { marker in
                            Annotation("\(marker.mile) mi", coordinate: marker.coordinate) {
                                ZStack {
                                    Circle()
                                        .fill(.white)
                                        .frame(width: 22, height: 22)
                                        .shadow(radius: 2)
                                    Circle()
                                        .stroke(.blue, lineWidth: 2)
                                        .frame(width: 22, height: 22)
                                    Text("\(marker.mile)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                }
                .frame(minWidth: 100, minHeight: 350, maxHeight: 350)

                // Route detection and performance indicator
                VStack(spacing: 8) {
                    // GPS badge
                    HStack(spacing: 6) {
                        Circle()
                            .fill(gpsService.isTracking ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(gpsService.isTracking ? "GPS Active" : "GPS Off")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)

                    // Pause indicator
                    if sensorDataService.isPaused {
                        HStack(spacing: 6) {
                            Image(systemName: "pause.fill")
                                .font(.system(size: 12))
                            Text("AUTO-PAUSED")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    }

                    // Heatmap toggle
                    if !gpsService.routeCoordinates.isEmpty {
                        Button(action: { showSpeedHeatmap.toggle() }) {
                            HStack(spacing: 6) {
                                Image(systemName: showSpeedHeatmap ? "chart.bar.fill" : "chart.bar")
                                    .font(.system(size: 12))
                                Text(showSpeedHeatmap ? "Speed Heatmap" : "Show Heatmap")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(showSpeedHeatmap ? Color.purple : Color.gray.opacity(0.6))
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                        }
                    }

                    // Segment indicator (takes priority over route matching)
                    if let effort = segmentManager.activeEffort,
                       let segment = segmentManager.detectedSegment {
                        VStack(spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: "flag.fill")
                                    .font(.system(size: 13, weight: .bold))
                                Text(segment.name)
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundColor(.white)

                            // Elapsed time
                            Text(formatSegmentTime(Date().timeIntervalSince(effort.startTime)))
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(.yellow)

                            // PR comparison
                            if let bestTime = segment.bestTime {
                                let currentTime = Date().timeIntervalSince(effort.startTime)
                                let delta = currentTime - bestTime
                                HStack(spacing: 4) {
                                    Image(systemName: delta < 0 ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                                        .font(.system(size: 12))
                                    Text(formatTimeDelta(delta) + " vs PR")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .foregroundColor(delta < 0 ? .green : .red)
                            } else {
                                Text("First Attempt!")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.cyan)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.purple.opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    // Route detected indicator
                    else if let detectedRoute = routeMatchingService.detectedRoute,
                       let progress = routeMatchingService.currentProgress {
                        VStack(spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: "map.fill")
                                    .font(.system(size: 12))
                                Text(detectedRoute.name)
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundColor(.white)

                            if progress.percentComplete > 0 {
                                Text("\(Int(progress.percentComplete))% complete")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.8))
                            }

                            // Performance comparison
                            if let bestTime = detectedRoute.bestTime,
                               sensorDataService.isRecording {
                                let currentTime = sensorDataService.sensorData.duration
                                let expectedTime = bestTime * (progress.percentComplete / 100)
                                let delta = currentTime - expectedTime

                                HStack(spacing: 4) {
                                    Image(systemName: delta < 0 ? "hare.fill" : "tortoise.fill")
                                        .font(.system(size: 10))
                                    Text(formatTimeDelta(delta))
                                        .font(.system(size: 12, weight: .bold))
                                }
                                .foregroundColor(delta < 0 ? .green : .orange)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                }
                .padding(12)
            }

            Spacer()

            // Speed
            VStack(spacing: 2) {
                Text(sensorDataService.sensorData.formattedSpeed)
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.green, .cyan], startPoint: .leading, endPoint: .trailing)
                    )
                Text("mph")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                    .textCase(.uppercase)
                    .tracking(2)
            }
            .padding(.top, 8)

            // Metrics
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    ModernMetricCard(icon: "heart.fill", title: "HR", value: "\(sensorDataService.sensorData.heartRate)", unit: "bpm", color: .red)
                    ModernMetricCard(icon: "flame.fill", title: "CAL", value: String(format: "%.0f", sensorDataService.sensorData.calories), unit: "", color: .orange)
                    ModernMetricCard(icon: "map.fill", title: "DIST", value: sensorDataService.sensorData.formattedDistance, unit: "", color: .blue)
                    ModernMetricCard(icon: "clock.fill", title: "TIME", value: sensorDataService.sensorData.formattedDuration, unit: "", color: .purple)
                }
                HStack(spacing: 8) {
                    ModernMetricCard(icon: "mountain.2.fill", title: "ELEV", value: String(format: "%.0f", gpsService.currentAltitude), unit: "ft", color: .teal)
                    ModernMetricCard(icon: "arrow.up.forward", title: "CLIMB", value: String(format: "%.0f", gpsService.totalElevationGain), unit: "ft", color: .green)

                    // Heart Rate Zone Display
                    if let zone = sensorDataService.getCurrentZone(),
                       let lthr = sensorDataService.userProfile.lactateThresholdHR {
                        ZoneCard(zone: zone, currentHR: sensorDataService.sensorData.heartRate, lthr: lthr)
                    } else {
                        Color.clear.frame(maxWidth: .infinity)
                    }

                    Color.clear.frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 12)

            Spacer()

            // Buttons
            HStack(spacing: 12) {
                Button(action: handleStartStop) {
                    HStack(spacing: 8) {
                        Image(systemName: sensorDataService.isRecording ? "stop.fill" : "play.fill")
                            .font(.system(size: 18, weight: .semibold))
                        Text(sensorDataService.isRecording ? "Stop" : "Start")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: sensorDataService.isRecording ? [.red, .red.opacity(0.8)] : [.green, .green.opacity(0.8)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: sensorDataService.isRecording ? .red.opacity(0.3) : .green.opacity(0.3), radius: 8, x: 0, y: 4)
                }

                Button(action: { sensorDataService.resetData() }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 56, height: 56)
                        .background(Color.gray.opacity(0.3))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                Button(action: { showingRideHistory = true }) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 56, height: 56)
                        .background(Color.blue.opacity(0.3))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Shared Landscape Components

    // Dynamic speed color based on comparison to average
    private var speedColor: Color {
        let currentSpeed = sensorDataService.sensorData.speed
        let averageSpeed = sensorDataService.sensorData.averageSpeed

        // If no average yet (early in ride), use neutral color
        guard averageSpeed > 0 && currentSpeed > 0 else {
            return .white
        }

        // Calculate percentage difference from average
        let percentDiff = (currentSpeed - averageSpeed) / averageSpeed

        // Color gradient:
        // Much slower (-30%+): Red
        // Slower (-15%): Orange
        // Near average (±10%): Yellow/Green
        // Faster (+15%): Bright Green
        // Much faster (+30%+): Cyan

        switch percentDiff {
        case ..<(-0.3):
            return .red
        case -0.3..<(-0.15):
            return .orange
        case -0.15..<0:
            return Color(red: 1.0, green: 0.8, blue: 0.0) // Yellow-orange
        case 0..<0.1:
            return Color(red: 0.6, green: 1.0, blue: 0.0) // Yellow-green
        case 0.1..<0.2:
            return .green
        case 0.2..<0.35:
            return Color(red: 0.0, green: 1.0, blue: 0.5) // Bright green
        default:
            return .cyan // Super fast!
        }
    }

    // Map view for landscape (shared between views)
    private var landscapeMapView: some View {
        ZStack(alignment: .topTrailing) {
            Map(position: $cameraPosition) {
                UserAnnotation()

                // Show route polyline if tracking
                if !gpsService.routeCoordinates.isEmpty {
                    if showSpeedHeatmap {
                        // Speed-based heatmap
                        ForEach(Array(getSpeedSegments().enumerated()), id: \.offset) { index, segment in
                            MapPolyline(coordinates: segment.coordinates)
                                .stroke(segment.color, lineWidth: 4)
                        }
                    } else {
                        // Standard gradient
                        MapPolyline(coordinates: gpsService.routeCoordinates)
                            .stroke(
                                LinearGradient(
                                    colors: [.green, .cyan, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 4
                            )
                    }

                    // Start marker
                    if let firstCoord = gpsService.routeCoordinates.first {
                        Annotation("Start", coordinate: firstCoord) {
                            ZStack {
                                Circle()
                                    .fill(.green)
                                    .frame(width: 20, height: 20)
                                Image(systemName: "figure.outdoor.cycle")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white)
                            }
                        }
                    }

                    // Mile markers
                    ForEach(gpsService.getMileMarkers(), id: \.mile) { marker in
                        Annotation("\(marker.mile)", coordinate: marker.coordinate) {
                            ZStack {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 18, height: 18)
                                Circle()
                                    .stroke(.blue, lineWidth: 2)
                                    .frame(width: 18, height: 18)
                                Text("\(marker.mile)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
            .frame(minWidth: 100, minHeight: 100)

            // GPS, Pause, and View Toggle badges
            VStack(spacing: 6) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(gpsService.isTracking ? Color.green : Color.red)
                        .frame(width: 6, height: 6)
                    Text(gpsService.isTracking ? "GPS" : "OFF")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())

                // Pause indicator
                if sensorDataService.isPaused {
                    HStack(spacing: 4) {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 10))
                        Text("PAUSED")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange)
                    .clipShape(Capsule())
                }

                // View toggle indicator
                HStack(spacing: 4) {
                    Image(systemName: landscapeViewIndex == 0 ? "gauge.with.dots.needle.33percent" : "chart.bar.xaxis")
                        .font(.system(size: 10))
                    Text(landscapeViewIndex == 0 ? "SIMPLE" : "DETAIL")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.purple.opacity(0.7))
                .clipShape(Capsule())

                // Heatmap toggle
                if !gpsService.routeCoordinates.isEmpty {
                    Button(action: { showSpeedHeatmap.toggle() }) {
                        HStack(spacing: 4) {
                            Image(systemName: showSpeedHeatmap ? "chart.bar.fill" : "chart.bar")
                                .font(.system(size: 10))
                            Text(showSpeedHeatmap ? "HEAT" : "TRAIL")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(showSpeedHeatmap ? Color.purple : Color.gray.opacity(0.6))
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(8)
        }
    }

    // Buttons for landscape (shared between views)
    private var landscapeButtons: some View {
        HStack(spacing: 6) {
            Button(action: handleStartStop) {
                Image(systemName: sensorDataService.isRecording ? "stop.fill" : "play.fill")
                    .font(.system(size: 15, weight: .bold))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(sensorDataService.isRecording ? Color.red : Color.green)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .frame(height: 40)

            Button(action: { sensorDataService.resetData() }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 40, height: 40)
                    .background(Color.gray.opacity(0.3))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Button(action: { showingRideHistory = true }) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 40, height: 40)
                    .background(Color.blue.opacity(0.3))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // MARK: - Helpers
    private func formatTimeDelta(_ delta: TimeInterval) -> String {
        let absDelta = abs(delta)
        let minutes = Int(absDelta) / 60
        let seconds = Int(absDelta) % 60

        let sign = delta < 0 ? "-" : "+"
        if minutes > 0 {
            return "\(sign)\(minutes)m \(seconds)s"
        } else {
            return "\(sign)\(seconds)s"
        }
    }

    private func formatSegmentTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    // Get color for speed (heatmap)
    private func colorForSpeed(_ speed: Double) -> Color {
        // Speed ranges:
        // 0-8 mph: red (slow)
        // 8-15 mph: yellow/orange (moderate)
        // 15+ mph: green (fast)
        switch speed {
        case 0..<8:
            return .red
        case 8..<12:
            return .orange
        case 12..<15:
            return .yellow
        case 15..<18:
            return .green
        default:
            return .cyan // super fast!
        }
    }

    // Get speed segments for heatmap
    private func getSpeedSegments() -> [(coordinates: [CLLocationCoordinate2D], color: Color)] {
        let speedData = gpsService.getSpeedData()
        guard speedData.count > 1 else { return [] }

        var segments: [(coordinates: [CLLocationCoordinate2D], color: Color)] = []
        var currentSegment: [CLLocationCoordinate2D] = [speedData[0].coordinate]
        var currentColor = colorForSpeed(speedData[0].speed)

        for i in 1..<speedData.count {
            let newColor = colorForSpeed(speedData[i].speed)

            if newColor == currentColor {
                // Continue current segment
                currentSegment.append(speedData[i].coordinate)
            } else {
                // Finish current segment and start new one
                if currentSegment.count >= 2 {
                    segments.append((coordinates: currentSegment, color: currentColor))
                }
                currentSegment = [speedData[i - 1].coordinate, speedData[i].coordinate]
                currentColor = newColor
            }
        }

        // Add final segment
        if currentSegment.count >= 2 {
            segments.append((coordinates: currentSegment, color: currentColor))
        }

        return segments
    }

    // MARK: - Actions
    private func handleStartStop() {
        if sensorDataService.isRecording {
            // Stop background audio to allow app to sleep
            backgroundAudioService.stopBackgroundAudio()

            gpsService.stopTracking()
            let gpsRoute = gpsService.getRoute().map { Ride.Coordinate(from: $0) }
            let elevationGain = gpsService.totalElevationGain

            // Include bike info in ride
            let bikeName = bikeStable.selectedBike?.name
            let bikeType = bikeStable.selectedBike?.type.rawValue

            var ride = sensorDataService.stopRecording(
                gpsRoute: gpsRoute.isEmpty ? nil : gpsRoute,
                elevationGain: elevationGain > 0 ? elevationGain : nil
            )

            // Create new ride with bike info
            if let existingRide = ride {
                ride = Ride(
                    id: existingRide.id,
                    date: existingRide.date,
                    duration: existingRide.duration,
                    distance: existingRide.distance,
                    averageSpeed: existingRide.averageSpeed,
                    maxSpeed: existingRide.maxSpeed,
                    averageHeartRate: existingRide.averageHeartRate,
                    maxHeartRate: existingRide.maxHeartRate,
                    calories: existingRide.calories,
                    elevationGain: existingRide.elevationGain,
                    routeCoordinates: existingRide.routeCoordinates,
                    notes: existingRide.notes,
                    bikeName: bikeName,
                    bikeType: bikeType
                )
            }

            if let ride = ride {
                // Announce ride complete
                audioCueService.announceRideComplete(
                    distance: ride.distance,
                    duration: ride.duration,
                    averageSpeed: ride.averageSpeed
                )

                rideHistory.saveRide(ride)

                // Add miles to bike
                if let bikeId = bikeStable.selectedBikeId {
                    bikeStable.addMiles(to: bikeId, miles: ride.distance)
                }

                // Add TSS to training load manager
                if let tss = ride.hrTSS {
                    trainingLoadManager.addTSS(date: ride.date, tss: tss)
                }

                // Save to HealthKit
                Task {
                    do {
                        try await healthKitService.saveRide(ride)
                    } catch {
                        print("Failed to save to HealthKit: \(error.localizedDescription)")
                    }
                }

                // Save to route matching service
                if let coordinates = ride.routeCoordinates {
                    let clCoordinates = coordinates.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
                    routeMatchingService.endRide(ride, coordinates: clCoordinates)
                }
            }
            gpsService.clearRoute()
        } else {
            // Start background audio to keep app alive when locked
            backgroundAudioService.startBackgroundAudio()

            // Start route tracking
            routeMatchingService.startRide()

            // Start audio cues
            audioCueService.startRide()
            audioCueService.announceRideStart()

            sensorDataService.startRecording()
            gpsService.startTracking()
        }
    }

    private func sendWatchUpdate() {
        // Get segment info if active
        var segmentName: String? = nil
        var segmentDelta: TimeInterval? = nil

        if let effort = segmentManager.activeEffort,
           let segment = segmentManager.detectedSegment {
            segmentName = segment.name

            if let bestTime = segment.bestTime {
                let currentTime = Date().timeIntervalSince(effort.startTime)
                segmentDelta = currentTime - bestTime
            }
        }

        // Send real-time update to watch
        phoneConnectivity.sendUpdate(
            speed: sensorDataService.sensorData.speed,
            distance: sensorDataService.sensorData.distance,
            duration: sensorDataService.sensorData.duration,
            heartRate: sensorDataService.sensorData.heartRate,
            isRecording: sensorDataService.isRecording,
            segmentName: segmentName,
            segmentDelta: segmentDelta
        )
    }
}

// MARK: - Landscape Metric Card
struct LandscapeMetricCard: View {
    let icon: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(color)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 8))
                        .foregroundColor(.gray)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Simple Landscape Metric (Large Format)
struct SimpleLandscapeMetric: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            // Large value
            Text(value)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            // Label
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
                .tracking(1.5)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.4), lineWidth: 2)
        )
    }
}

// MARK: - Portrait Metric Card
struct ModernMetricCard: View {
    let icon: String
    let title: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.gray)
                .textCase(.uppercase)
                .tracking(0.5)

            if !unit.isEmpty {
                Text(unit)
                    .font(.system(size: 8))
                    .foregroundColor(.gray.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Heart Rate Zone Card
struct ZoneCard: View {
    let zone: HeartRateZones.Zone
    let currentHR: Int
    let lthr: Int

    var body: some View {
        VStack(spacing: 4) {
            Text("Z\(zone.rawValue)")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundColor(zone.color)

            Text(zone.name.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
                .tracking(0.5)

            Text("\(Int((Double(currentHR) / Double(lthr)) * 100))%")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(zone.color.opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(zone.color, lineWidth: 2)
        )
    }
}

// MARK: - Sensor Settings View
struct SensorSettingsView: View {
    @EnvironmentObject var bluetoothService: BluetoothService
    @EnvironmentObject var trainingLoadManager: TrainingLoadManager
    @EnvironmentObject var routeMatchingService: RouteMatchingService
    @EnvironmentObject var bikeStable: BikeStable
    @EnvironmentObject var segmentManager: SegmentManager
    @EnvironmentObject var gpsService: GPSService
    @EnvironmentObject var rideHistory: RideHistory
    @Environment(\.dismiss) var dismiss
    @State private var showingFitness = false
    @State private var showingRoutes = false
    @State private var showingSegments = false
    @State private var assigningSensor: (SensorType, SensorInfo)?
    @State private var renamingSensor: (SensorType, String)? = nil
    @State private var showingRenameSheet = false

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Quick Actions")) {
                    Button(action: {
                        showingFitness = true
                    }) {
                        Label("Training Load & Fitness", systemImage: "chart.line.uptrend.xyaxis")
                    }

                    Button(action: {
                        showingRoutes = true
                    }) {
                        HStack {
                            Label("My Routes", systemImage: "map")
                            Spacer()
                            if routeMatchingService.savedRoutes.count > 0 {
                                Text("\(routeMatchingService.savedRoutes.count)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }

                    Button(action: {
                        showingSegments = true
                    }) {
                        HStack {
                            Label("My Segments", systemImage: "flag.fill")
                            Spacer()
                            if segmentManager.segments.count > 0 {
                                Text("\(segmentManager.segments.count)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }

                // Show assigned sensors
                Section(header: Text("Assigned Sensors")) {
                    ForEach(SensorType.allCases, id: \.self) { sensorType in
                        if let savedSensor = bikeStable.getSensor(for: sensorType) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(savedSensor.displayName)
                                            .font(.headline)
                                        Text(sensorType.rawValue)
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }

                                    Spacer()

                                    // Show assignment type
                                    Text(sensorType.isProfileSensor ? "Profile" : bikeStable.selectedBike?.name ?? "Bike")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.1))
                                        .clipShape(Capsule())

                                    // Rename button
                                    Button(action: {
                                        renamingSensor = (sensorType, savedSensor.customName ?? savedSensor.deviceName)
                                        showingRenameSheet = true
                                    }) {
                                        Image(systemName: "pencil.circle")
                                            .foregroundColor(.blue)
                                    }
                                }

                                // Connection status, battery, and reconnect button
                                HStack {
                                    if bluetoothService.connectedSensors[sensorType] != nil {
                                        HStack(spacing: 8) {
                                            Text("✓ Connected")
                                                .font(.caption)
                                                .foregroundColor(.green)

                                            // Battery indicator
                                            if let battery = bluetoothService.getBatteryLevel(for: sensorType) {
                                                HStack(spacing: 2) {
                                                    Image(systemName: batteryIcon(for: battery))
                                                        .foregroundColor(batteryColor(for: battery))
                                                    Text("\(battery)%")
                                                        .font(.caption2)
                                                        .foregroundColor(.gray)
                                                }
                                            }
                                        }
                                    } else {
                                        Text("Disconnected")
                                            .font(.caption)
                                            .foregroundColor(.gray)

                                        Button("Reconnect") {
                                            bluetoothService.connectToPeripheral(withId: savedSensor.id, type: sensorType)
                                        }
                                        .buttonStyle(.bordered)
                                        .font(.caption)
                                    }
                                }
                            }
                        }
                    }
                }

                Section(header: Text("Bluetooth Status")) {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(bluetoothStateText)
                            .foregroundColor(bluetoothStateColor)
                    }
                }

                Section(header: Text("Discovered Sensors")) {
                    if bluetoothService.discoveredSensors.isEmpty {
                        Text("No sensors found")
                            .foregroundColor(.gray)
                    } else {
                        ForEach(bluetoothService.discoveredSensors) { sensor in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(sensor.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    HStack(spacing: 8) {
                                        Text(sensor.type.rawValue)
                                            .font(.caption)
                                            .foregroundColor(.gray)

                                        // Battery indicator
                                        if let battery = sensor.batteryLevel {
                                            HStack(spacing: 2) {
                                                Image(systemName: batteryIcon(for: battery))
                                                    .font(.caption)
                                                    .foregroundColor(batteryColor(for: battery))
                                                Text("\(battery)%")
                                                    .font(.caption2)
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                    }
                                }

                                Spacer()

                                if sensor.isConnected {
                                    // Show assign button if connected
                                    Button("Assign") {
                                        assigningSensor = (sensor.type, sensor)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .font(.caption)
                                } else {
                                    Button("Connect") {
                                        bluetoothService.connect(to: sensor)
                                    }
                                    .buttonStyle(.bordered)
                                    .font(.caption)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Sensors")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        if bluetoothService.isScanning {
                            bluetoothService.stopScanning()
                        } else {
                            bluetoothService.startScanning()
                        }
                    }) {
                        Text(bluetoothService.isScanning ? "Stop" : "Scan")
                    }
                }
            }
            .sheet(isPresented: $showingFitness) {
                FitnessView()
                    .environmentObject(trainingLoadManager)
            }
            .sheet(isPresented: $showingRoutes) {
                RoutesView()
                    .environmentObject(routeMatchingService)
            }
            .sheet(isPresented: $showingSegments) {
                SegmentsView()
                    .environmentObject(segmentManager)
                    .environmentObject(gpsService)
                    .environmentObject(rideHistory)
            }
            .alert("Assign Sensor", isPresented: .constant(assigningSensor != nil), presenting: assigningSensor) { sensorTuple in
                Button("Assign to Profile") {
                    if let savedSensor = bluetoothService.createSavedSensor(for: sensorTuple.0) {
                        bikeStable.assignProfileSensor(savedSensor, type: sensorTuple.0)
                    }
                    assigningSensor = nil
                }
                Button("Assign to \(bikeStable.selectedBike?.name ?? "Current Bike")") {
                    if let savedSensor = bluetoothService.createSavedSensor(for: sensorTuple.0) {
                        bikeStable.assignSensorToBike(savedSensor, type: sensorTuple.0)
                    }
                    assigningSensor = nil
                }
                Button("Cancel", role: .cancel) {
                    assigningSensor = nil
                }
            } message: { sensorTuple in
                Text("\(sensorTuple.0.rawValue) will auto-connect to the selected bike or profile.")
            }
            .sheet(isPresented: $showingRenameSheet) {
                if let (sensorType, initialName) = renamingSensor {
                    SensorRenameView(sensorType: sensorType, initialName: initialName)
                        .environmentObject(bikeStable)
                }
            }
        }
    }

    private var bluetoothStateText: String {
        switch bluetoothService.bluetoothState {
        case .poweredOn: return "On"
        case .poweredOff: return "Off"
        case .unauthorized: return "Unauthorized"
        case .unsupported: return "Unsupported"
        default: return "Unknown"
        }
    }

    private var bluetoothStateColor: Color {
        switch bluetoothService.bluetoothState {
        case .poweredOn: return .green
        default: return .red
        }
    }

    // Battery icon based on level
    private func batteryIcon(for level: Int) -> String {
        switch level {
        case 76...100: return "battery.100"
        case 51...75: return "battery.75"
        case 26...50: return "battery.50"
        case 11...25: return "battery.25"
        default: return "battery.0"
        }
    }

    // Battery color based on level
    private func batteryColor(for level: Int) -> Color {
        switch level {
        case 26...100: return .green
        case 11...25: return .orange
        default: return .red
        }
    }
}
