import SwiftUI

@main
struct TailwindWatchApp: App {
    @StateObject private var connectivity = WatchConnectivityManager()
    @StateObject private var healthKit = WatchHealthKitService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connectivity)
                .environmentObject(healthKit)
                .onAppear {
                    connectivity.activateSession()
                }
        }
    }
}
