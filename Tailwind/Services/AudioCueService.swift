import Foundation
import AVFoundation
import Combine

class AudioCueService: NSObject, ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()

    @Published var audioEnabled = true
    private var lastMileCalled: Int = 0
    private var splitStartTime: Date?
    private var splitStartDistance: Double = 0.0

    override init() {
        super.init()
        synthesizer.delegate = self

        // Configure audio session for background audio and mixing with music
        configureAudioSession()
    }

    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            // Use playback category with mixWithOthers option to not interrupt music
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.mixWithOthers, .duckOthers])
            try audioSession.setActive(true)
            print("🔊 Audio session configured for voice cues")
        } catch {
            print("❌ Failed to configure audio session: \(error)")
        }
    }

    func startRide() {
        lastMileCalled = 0
        splitStartTime = Date()
        splitStartDistance = 0.0
    }

    func checkForMileSplit(currentDistance: Double, currentSpeed: Double) {
        guard audioEnabled else { return }

        let currentMile = Int(currentDistance)

        // Check if we've completed a new 5-mile split
        if currentMile > lastMileCalled && currentMile > 0 && currentMile % 5 == 0 {
            // Calculate split time (time since last split)
            let splitTime: TimeInterval
            if let lastSplitTime = splitStartTime {
                splitTime = Date().timeIntervalSince(lastSplitTime)
            } else {
                splitTime = 0
            }

            // Calculate split speed (average speed for this mile)
            let splitDistance = currentDistance - splitStartDistance
            let splitSpeed = splitDistance / (splitTime / 3600.0) // miles per hour

            // Announce the split
            announceSplit(splitNumber: currentMile, splitTime: splitTime, splitSpeed: splitSpeed)

            // Update for next split
            lastMileCalled = currentMile
            splitStartTime = Date()
            splitStartDistance = currentDistance
        }
    }

    private func announceSplit(splitNumber: Int, splitTime: TimeInterval, splitSpeed: Double) {
        let minutes = Int(splitTime) / 60
        let seconds = Int(splitTime) % 60

        let announcement: String
        if minutes > 0 {
            announcement = "Split \(splitNumber). Split time \(minutes) minutes \(seconds) seconds. Split speed \(Int(splitSpeed)) miles per hour."
        } else {
            announcement = "Split \(splitNumber). Split time \(seconds) seconds. Split speed \(Int(splitSpeed)) miles per hour."
        }

        speak(announcement)
    }

    func announceSegmentStart(_ segmentName: String) {
        guard audioEnabled else { return }
        speak("Segment start: \(segmentName)")
    }

    func announceSegmentEnd(_ segmentName: String, time: TimeInterval, isPR: Bool) {
        guard audioEnabled else { return }

        let minutes = Int(time) / 60
        let seconds = Int(time) % 60

        var announcement = "Segment complete: \(segmentName). Time: \(minutes) minutes \(seconds) seconds."
        if isPR {
            announcement += " New personal record!"
        }

        speak(announcement)
    }

    func announceRideStart() {
        guard audioEnabled else { return }
        speak("Ride started")
    }

    func announceRidePaused() {
        guard audioEnabled else { return }
        speak("Ride paused")
    }

    func announceRideResumed() {
        guard audioEnabled else { return }
        speak("Ride resumed")
    }

    func announceRideComplete(distance: Double, duration: TimeInterval, averageSpeed: Double) {
        guard audioEnabled else { return }

        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60

        let announcement = "Ride complete. Distance: \(String(format: "%.1f", distance)) miles. Time: \(minutes) minutes \(seconds) seconds. Average speed: \(Int(averageSpeed)) miles per hour."

        speak(announcement)
    }

    private func speak(_ text: String) {
        print("🔊 Speaking: \(text)")

        let utterance = AVSpeechUtterance(string: text)

        // Use Australian English female voice (Karen is the default female voice for en-AU)
        // If not available, falls back to en-US
        if let australianVoice = AVSpeechSynthesisVoice(language: "en-AU") {
            utterance.voice = australianVoice
            print("🔊 Using Australian voice: \(australianVoice.name)")
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            print("⚠️ Australian voice not available, using en-US")
        }

        utterance.rate = 0.52 // Slightly faster than default for natural speech
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        synthesizer.speak(utterance)
    }

    func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate
extension AudioCueService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        print("🔊 Started speaking - audio ducking active")

        // Audio session should automatically duck other audio
        // duckOthers option in audio session handles this
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        print("🔊 Finished speaking - restoring background audio volume")

        // Explicitly deactivate and reactivate audio session to ensure volume restoration
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            try audioSession.setActive(true)
            print("🔊 Audio session reset - background volume should be restored")
        } catch {
            print("⚠️ Failed to reset audio session: \(error)")
        }
    }
}
