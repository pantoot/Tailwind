import SwiftUI

struct TabbedContentView: View {
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

    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Active Ride
            MainView()
                .tabItem {
                    Label("Ride", systemImage: "bicycle")
                }
                .tag(0)

            // Tab 2: History & Analytics
            HistoryTabView()
                .tabItem {
                    Label("History", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(1)

            // Tab 3: Settings
            SettingsTabView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(2)
        }
        .accentColor(.cyan)
    }
}
