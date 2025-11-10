import SwiftUI

@main
struct TailwindWatchApp: App {
    @StateObject private var connectivity = WatchConnectivityManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connectivity)
                .onAppear {
                    connectivity.activateSession()
                }
        }
    }
}
