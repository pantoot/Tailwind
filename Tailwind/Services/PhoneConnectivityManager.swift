import Foundation
import WatchConnectivity
import Combine

class PhoneConnectivityManager: NSObject, ObservableObject {
    private var session: WCSession?
    private var updateTimer: Timer?
    @Published var isWatchConnected: Bool = false

    // Callbacks to control iPhone app
    var onStartRide: (() -> Void)?
    var onStopRide: (() -> Void)?
    var onToggleAudio: (() -> Void)?

    override init() {
        super.init()

        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
        }
    }

    func activateSession() {
        session?.activate()
        print("📱 iPhone: WCSession activated")
    }

    private var isWatchAvailable: Bool {
        guard let session = session else { return false }
        // Only check availability after activation completes
        guard session.activationState == .activated else { return false }
        return session.isPaired && session.isWatchAppInstalled && session.isReachable
    }

    // Send real-time updates to watch
    func sendUpdate(
        speed: Double,
        distance: Double,
        duration: TimeInterval,
        heartRate: Int,
        isRecording: Bool,
        segmentName: String? = nil,
        segmentDelta: TimeInterval? = nil
    ) {
        // Silently skip if watch not available
        guard isWatchAvailable else { return }

        var message: [String: Any] = [
            "speed": speed,
            "distance": distance,
            "duration": duration,
            "heartRate": heartRate,
            "isRecording": isRecording
        ]

        if let segmentName = segmentName {
            message["segmentName"] = segmentName
        } else {
            message["segmentName"] = NSNull()
        }

        if let delta = segmentDelta {
            message["segmentDelta"] = delta
        }

        guard let session = session else { return }

        session.sendMessage(message, replyHandler: nil) { error in
            // Only log errors that aren't "not reachable"
            if (error as NSError).code != 7012 { // WCErrorCodeSessionNotReachable
                print("📱 iPhone: Error sending update: \(error.localizedDescription)")
            }
        }
    }

    // Send less frequent context updates (persists even when app isn't running)
    func updateApplicationContext(
        speed: Double,
        distance: Double,
        duration: TimeInterval,
        isRecording: Bool
    ) {
        guard let session = session else { return }

        let context: [String: Any] = [
            "speed": speed,
            "distance": distance,
            "duration": duration,
            "isRecording": isRecording
        ]

        do {
            try session.updateApplicationContext(context)
            print("📱 iPhone: Updated application context")
        } catch {
            print("📱 iPhone: Error updating context: \(error.localizedDescription)")
        }
    }

    // Send haptic feedback for segment events
    func sendSegmentStartHaptic(segmentName: String) {
        guard isWatchAvailable, let session = session else { return }

        let message: [String: Any] = [
            "haptic": "segmentStart",
            "segmentName": segmentName
        ]

        session.sendMessage(message, replyHandler: nil) { error in
            print("📱 iPhone: Error sending haptic: \(error.localizedDescription)")
        }

        print("📱 iPhone: Sent segment start haptic for: \(segmentName)")
    }

    func sendSegmentEndHaptic(isPR: Bool) {
        guard isWatchAvailable, let session = session else { return }

        let message: [String: Any] = [
            "haptic": isPR ? "segmentPR" : "segmentEnd"
        ]

        session.sendMessage(message, replyHandler: nil) { error in
            print("📱 iPhone: Error sending haptic: \(error.localizedDescription)")
        }

        print("📱 iPhone: Sent segment end haptic (PR: \(isPR))")
    }
}

// MARK: - WCSessionDelegate
extension PhoneConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("📱 iPhone: Activation failed: \(error.localizedDescription)")
        } else {
            print("📱 iPhone: Activation completed with state: \(activationState.rawValue)")
            updateConnectionState()
        }
    }

    private func updateConnectionState() {
        DispatchQueue.main.async {
            self.isWatchConnected = self.isWatchAvailable
            if self.isWatchConnected {
                print("📱 iPhone: ✓ Apple Watch connected and ready")
            }
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        print("📱 iPhone: Session became inactive")
        updateConnectionState()
    }

    func sessionDidDeactivate(_ session: WCSession) {
        print("📱 iPhone: Session deactivated")
        updateConnectionState()
        // Reactivate session for new watch
        session.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        updateConnectionState()
        if session.isReachable {
            print("📱 iPhone: ✓ Watch became reachable")
        } else {
            print("📱 iPhone: Watch not reachable")
        }
    }

    // Receive commands from watch
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            if let action = message["action"] as? String {
                print("📱 iPhone: Received action: \(action)")

                switch action {
                case "startRide":
                    self.onStartRide?()
                case "stopRide":
                    self.onStopRide?()
                case "toggleAudio":
                    self.onToggleAudio?()
                default:
                    break
                }
            }
        }
    }
}
