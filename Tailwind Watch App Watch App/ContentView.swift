import SwiftUI
import WatchKit

struct ContentView: View {
    @EnvironmentObject var connectivity: WatchConnectivityManager
    @EnvironmentObject var healthKit: WatchHealthKitService
    @State private var isRecording = false

    // Dynamic speed color based on value
    private var speedColor: Color {
        let speed = connectivity.currentSpeed
        switch speed {
        case 0..<5: return .gray
        case 5..<10: return .yellow
        case 10..<15: return .green
        case 15..<20: return .cyan
        default: return .mint // Super fast!
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                // Speed - Hero display with glow effect
                ZStack {
                    // Subtle glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [speedColor.opacity(0.4), Color.clear],
                                center: .center,
                                startRadius: 5,
                                endRadius: 60
                            )
                        )
                        .frame(width: 120, height: 120)
                        .blur(radius: 20)

                    VStack(spacing: 3) {
                        Text(String(format: "%.1f", connectivity.currentSpeed))
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [speedColor, speedColor.opacity(0.7)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        Text("MPH")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white.opacity(0.5))
                            .tracking(2)
                    }
                }
                .padding(.bottom, 6)

                // Distance and Duration - Modern glassmorphism cards
                HStack(spacing: 8) {
                    WatchMetricCard(
                        value: String(format: "%.2f", connectivity.distance),
                        label: "MI",
                        color: .blue
                    )

                    WatchMetricCard(
                        value: formatDuration(connectivity.duration),
                        label: "TIME",
                        color: .orange
                    )
                }

                // Heart Rate (if available) - Modern card
                if connectivity.heartRate > 0 {
                    WatchMetricCard(
                        value: "\(connectivity.heartRate)",
                        label: "BPM",
                        color: .red,
                        icon: "heart.fill"
                    )
                }

                // Segment indicator (if active) - Glassmorphism style
                if let segmentName = connectivity.activeSegmentName {
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "flag.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text(segmentName)
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(.purple)

                        if let delta = connectivity.segmentDelta {
                            Text(formatDelta(delta))
                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                                .foregroundColor(delta < 0 ? .green : .red)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(.ultraThinMaterial)

                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.purple.opacity(0.3))
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.purple.opacity(0.5), lineWidth: 1)
                    )
                }

                // Start/Stop button - Modern glassmorphism
                Button(action: {
                    // Send command to iPhone - don't change local state yet
                    // State will update when iPhone confirms via connectivity.isRecording
                    if isRecording {
                        connectivity.sendStopRide()
                    } else {
                        connectivity.sendStartRide()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: isRecording ? "stop.fill" : "play.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text(isRecording ? "Stop" : "Start")
                            .font(.system(size: 17, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)

                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: isRecording ?
                                            [Color.red.opacity(0.8), Color.red.opacity(0.6)] :
                                            [Color.green.opacity(0.8), Color.green.opacity(0.6)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                    )
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
            .padding()
        }
        .onAppear {
            connectivity.activateSession()

            // Request HealthKit authorization
            Task {
                try? await healthKit.requestAuthorization()
            }
        }
        .onChange(of: connectivity.isRecording) { oldValue, newValue in
            isRecording = newValue

            // Start/stop heart rate streaming based on recording state
            if newValue {
                healthKit.startHeartRateStreaming()
            } else {
                healthKit.stopHeartRateStreaming()
            }
        }
        .onChange(of: healthKit.currentHeartRate) { oldValue, newValue in
            // Send watch HR to iPhone whenever it updates
            if newValue > 0 {
                connectivity.sendHeartRate(newValue)
            }
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

// MARK: - Watch Metric Card (Glassmorphism)
struct WatchMetricCard: View {
    let value: String
    let label: String
    let color: Color
    var icon: String? = nil

    var body: some View {
        VStack(spacing: 6) {
            // Icon if provided
            if let icon = icon {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.3))
                        .frame(width: 20, height: 20)
                        .blur(radius: 4)

                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(color)
                }
            }

            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [color, color.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white.opacity(0.5))
                .tracking(1)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background(
            ZStack {
                // Glassmorphism base
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)

                // Gradient overlay
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.15),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        colors: [color.opacity(0.6), color.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchConnectivityManager())
        .environmentObject(WatchHealthKitService())
}
