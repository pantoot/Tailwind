import Foundation
import SwiftUI
import Combine

/// Cross-screen navigation state.
///
/// Tab selection used to be `@State` on the app struct, mutated from three
/// import handlers via bare integer tags. Naming the tabs means adding one
/// (the planned Trends tab) doesn't renumber the others, and it lets the
/// Today tab hand the user to the Rides list instead of pushing a second
/// copy of it.
@MainActor
final class AppRouter: ObservableObject {
    enum Tab: Hashable {
        case today, rides, settings
    }

    enum RidesSegment: String, CaseIterable {
        case history = "History"
        case power = "Power"
    }

    @Published var selectedTab: Tab = .today
    /// Which Rides segment to land on. Without this, jumping to Rides shows
    /// whichever segment was last used — landing on power charts when the
    /// user asked to see all their rides.
    @Published var ridesSegment: RidesSegment = .history

    /// Show the full ride list, from anywhere.
    func showAllRides() {
        ridesSegment = .history
        selectedTab = .rides
    }
}
