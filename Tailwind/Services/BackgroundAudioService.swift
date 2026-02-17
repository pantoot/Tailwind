import Foundation
import AVFoundation
import Combine

class BackgroundAudioService: ObservableObject {
    private var audioPlayer: AVAudioPlayer?
    private var isPlaying = false
    private var hasSetupSession = false

    init() {
        setupNotificationObservers()
    }

    private func setupAudioSession() {
        guard !hasSetupSession else { return }

        do {
            let audioSession = AVAudioSession.sharedInstance()
            // Use .mixWithOthers to play silent audio without affecting other apps' volume
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
            hasSetupSession = true
            print("🔊 Background Audio: Session configured with mixWithOthers (no ducking)")
        } catch {
            print("❌ Background Audio: Failed to setup audio session: \(error.localizedDescription)")
        }
    }

    private func setupNotificationObservers() {
        // Observe interruptions (calls, Siri, etc.)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )

        // Observe route changes (headphones connect/disconnect)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            print("🔇 Background Audio: Interruption began")
            // Audio has been paused automatically

        case .ended:
            print("🔊 Background Audio: Interruption ended")
            // Resume playback
            if isPlaying {
                do {
                    try AVAudioSession.sharedInstance().setActive(true)
                    audioPlayer?.play()
                    print("▶️ Background Audio: Resumed playback after interruption")
                } catch {
                    print("❌ Background Audio: Failed to resume: \(error.localizedDescription)")
                }
            }

        @unknown default:
            break
        }
    }

    @objc private func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        print("🎧 Background Audio: Route change - \(reason.rawValue)")

        // Resume playback if needed after route change
        if isPlaying && audioPlayer?.isPlaying == false {
            audioPlayer?.play()
            print("▶️ Background Audio: Resumed after route change")
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func startBackgroundAudio() {
        // Set up audio session first (only once)
        setupAudioSession()

        // Create a silent audio file in memory
        let silenceURL = createSilentAudioFile()

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: silenceURL)
            audioPlayer?.numberOfLoops = -1 // Loop indefinitely
            audioPlayer?.volume = 0.0 // Silent
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            isPlaying = true
            print("▶️ Background Audio: Started silent audio to keep app alive")
        } catch {
            print("❌ Background Audio: Failed to start audio player: \(error.localizedDescription)")
        }
    }

    func stopBackgroundAudio() {
        isPlaying = false
        audioPlayer?.stop()
        audioPlayer = nil

        // Deactivate the audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            hasSetupSession = false // Allow re-setup for next ride
            print("⏹️ Background Audio: Stopped silent audio and deactivated session")
        } catch {
            print("❌ Background Audio: Failed to deactivate session: \(error.localizedDescription)")
        }
    }

    private func createSilentAudioFile() -> URL {
        // Create a 1-second silent audio file
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let frameCount = AVAudioFrameCount(format.sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        // Write silent audio to temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("silence.m4a")

        // If file already exists, just return it
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }

        do {
            let audioFile = try AVAudioFile(forWriting: fileURL, settings: format.settings)
            try audioFile.write(from: buffer)
            return fileURL
        } catch {
            print("Background Audio: Failed to create silent audio file: \(error.localizedDescription)")
            // Return a dummy URL - the app will still work without background audio
            return tempDir.appendingPathComponent("silence.m4a")
        }
    }
}
