import SwiftUI
import WatchKit

struct ContentView: View {
    @EnvironmentObject var connectivity: WatchConnectivityManager
    @State private var isRecording = false

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Speed - Primary metric (large)
                VStack(spacing: 2) {
                    Text(String(format: "%.1f", connectivity.currentSpeed))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.cyan)
                    Text("MPH")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.gray)
                }
                .padding(.bottom, 8)

                // Distance and Duration (medium)
                HStack(spacing: 12) {
                    VStack(spacing: 2) {
                        Text(String(format: "%.2f", connectivity.distance))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.green)
                        Text("MILES")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.gray)
                    }

                    VStack(spacing: 2) {
                        Text(formatDuration(connectivity.duration))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.orange)
                        Text("TIME")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                }

                // Heart Rate (if available)
                if connectivity.heartRate > 0 {
                    VStack(spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.red)
                            Text("\(connectivity.heartRate)")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.red)
                        }
                        Text("BPM")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 4)
                }

                // Segment indicator (if active)
                if let segmentName = connectivity.activeSegmentName {
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "flag.fill")
                                .font(.system(size: 10))
                            Text(segmentName)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.purple)

                        if let delta = connectivity.segmentDelta {
                            Text(formatDelta(delta))
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(delta < 0 ? .green : .red)
                        }
                    }
                    .padding(8)
                    .background(Color.purple.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.top, 4)
                }

                // Start/Stop button
                Button(action: {
                    if isRecording {
                        connectivity.sendStopRide()
                        isRecording = false
                    } else {
                        connectivity.sendStartRide()
                        isRecording = true
                    }
                }) {
                    HStack {
                        Image(systemName: isRecording ? "stop.fill" : "play.fill")
                        Text(isRecording ? "Stop" : "Start")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(isRecording ? Color.red : Color.green)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
            .padding()
        }
        .onAppear {
            connectivity.activateSession()
        }
        .onChange(of: connectivity.isRecording) { oldValue, newValue in
            isRecording = newValue
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    private func formatDelta(_ delta: TimeInterval) -> String {
        let sign = delta < 0 ? "-" : "+"
        let absDelta = abs(delta)
        let minutes = Int(absDelta) / 60
        let seconds = Int(absDelta) % 60

        if minutes > 0 {
            return "\(sign)\(minutes):\(String(format: "%02d", seconds))"
        } else {
            return "\(sign)\(seconds)s"
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchConnectivityManager())
}
