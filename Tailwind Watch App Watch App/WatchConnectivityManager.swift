import Foundation
import WatchConnectivity
import Combine

class WatchConnectivityManager: NSObject, ObservableObject {
    @Published var currentSpeed: Double = 0.0
    @Published var distance: Double = 0.0
    @Published var duration: TimeInterval = 0.0
    @Published var heartRate: Int = 0
    @Published var isRecording: Bool = false

    // Segment tracking
    @Published var activeSegmentName: String?
    @Published var segmentDelta: TimeInterval?

    private var session: WCSession?

    override init() {
        super.init()

        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
        }
    }

    func activateSession() {
        session?.activate()
        print("⌚ Watch: WCSession activated")
    }

    func sendStartRide() {
        guard let session = session, session.isReachable else {
            print("⌚ Watch: iPhone not reachable")
            return
        }

        session.sendMessage(["action": "startRide"], replyHandler: nil) { error in
            print("⌚ Watch: Error sending start ride: \(error.localizedDescription)")
        }

        print("⌚ Watch: Sent start ride command")
    }

    func sendStopRide() {
        guard let session = session, session.isReachable else {
            print("⌚ Watch: iPhone not reachable")
            return
        }

        session.sendMessage(["action": "stopRide"], replyHandler: nil) { error in
            print("⌚ Watch: Error sending stop ride: \(error.localizedDescription)")
        }

        print("⌚ Watch: Sent stop ride command")
    }

    func sendToggleAudioCues() {
        guard let session = session, session.isReachable else {
            print("⌚ Watch: iPhone not reachable")
            return
        }

        session.sendMessage(["action": "toggleAudio"], replyHandler: nil) { error in
            print("⌚ Watch: Error toggling audio: \(error.localizedDescription)")
        }

        print("⌚ Watch: Sent toggle audio command")
    }
}

// MARK: - WCSessionDelegate
extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("⌚ Watch: Activation failed: \(error.localizedDescription)")
        } else {
            print("⌚ Watch: Activation completed with state: \(activationState.rawValue)")
        }
    }

    // Receive real-time updates from iPhone
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            if let speed = message["speed"] as? Double {
                self.currentSpeed = speed
            }

            if let distance = message["distance"] as? Double {
                self.distance = distance
            }

            if let duration = message["duration"] as? TimeInterval {
                self.duration = duration
            }

            if let heartRate = message["heartRate"] as? Int {
                self.heartRate = heartRate
            }

            if let recording = message["isRecording"] as? Bool {
                self.isRecording = recording
            }

            // Segment updates
            if let segmentName = message["segmentName"] as? String {
                self.activeSegmentName = segmentName
            } else if message["segmentName"] is NSNull {
                self.activeSegmentName = nil
                self.segmentDelta = nil
            }

            if let delta = message["segmentDelta"] as? TimeInterval {
                self.segmentDelta = delta
            }

            print("⌚ Watch: Updated - Speed: \(String(format: "%.1f", self.currentSpeed)), Distance: \(String(format: "%.2f", self.distance))")
        }
    }

    // Receive application context updates (for less frequent updates)
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        DispatchQueue.main.async {
            if let speed = applicationContext["speed"] as? Double {
                self.currentSpeed = speed
            }

            if let distance = applicationContext["distance"] as? Double {
                self.distance = distance
            }

            if let duration = applicationContext["duration"] as? TimeInterval {
                self.duration = duration
            }

            if let recording = applicationContext["isRecording"] as? Bool {
                self.isRecording = recording
            }

            print("⌚ Watch: Received context update")
        }
    }
}
