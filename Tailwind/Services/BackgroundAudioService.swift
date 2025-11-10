import Foundation
import AVFoundation
import Combine

class BackgroundAudioService: ObservableObject {
    private var audioPlayer: AVAudioPlayer?

    init() {
        setupAudioSession()
    }

    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
            print("Background Audio: Session configured")
        } catch {
            print("Background Audio: Failed to setup audio session: \(error.localizedDescription)")
        }
    }

    func startBackgroundAudio() {
        // Create a silent audio file in memory
        let silenceURL = createSilentAudioFile()

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: silenceURL)
            audioPlayer?.numberOfLoops = -1 // Loop indefinitely
            audioPlayer?.volume = 0.0 // Silent
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            print("Background Audio: Started silent audio to keep app alive")
        } catch {
            print("Background Audio: Failed to start audio player: \(error.localizedDescription)")
        }
    }

    func stopBackgroundAudio() {
        audioPlayer?.stop()
        audioPlayer = nil
        print("Background Audio: Stopped silent audio")
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
