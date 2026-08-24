import SwiftUI

/// Result sheet for the Settings > Estimate Max HR diagnostic. Mirrors
/// LTHRResultView: headline number, method explanation, best effort, top
/// candidates, and an apply button that writes the profile field.
struct MaxHRResultView: View {
    let estimate: HealthKitService.MaxHREstimate?
    let currentMaxHR: Int?
    let onApply: (Int) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let estimate {
                    resultContent(estimate)
                } else {
                    emptyState
                }
            }
            .navigationTitle("Max HR Estimate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func resultContent(_ estimate: HealthKitService.MaxHREstimate) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Main result
                VStack(spacing: 8) {
                    Text("Estimated Max HR")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("\(estimate.estimatedMaxHR)")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundStyle(.red)

                    Text("bpm")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    if let current = currentMaxHR, current > 0 {
                        let diff = estimate.estimatedMaxHR - current
                        Text("Current: \(current) bpm (\(diff >= 0 ? "+" : "")\(diff))")
                            .font(.subheadline)
                            .foregroundStyle(abs(diff) > 5 ? .orange : .green)
                    }
                }
                .padding(.top, 20)

                // Method explanation
                VStack(alignment: .leading, spacing: 8) {
                    Text("How this was calculated")
                        .font(.headline)

                    Text("Found the highest heart rate you held for a full 15 seconds across your cycling workouts, after filtering out sensor artifacts: single-sample spikes, and sustained bogus blocks the signal stepped into discontinuously (a chest strap doubling to 2\u{00d7} your real HR, an optical sensor locking onto cadence). Real HR climbs through the values below a peak \u{2014} readings that appear from nowhere are discarded and listed as rejected. Your true instantaneous max is typically 1\u{2013}3 bpm above the sustained value.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)

                // Best effort details
                VStack(alignment: .leading, spacing: 8) {
                    Text("Best Effort")
                        .font(.headline)

                    HStack {
                        Text("Date")
                        Spacer()
                        Text(estimate.workoutDate, style: .date)
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)

                    HStack {
                        Text("Best 15s Sustained HR")
                        Spacer()
                        Text(String(format: "%.0f bpm", estimate.bestSustainedHR))
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)

                    HStack {
                        Text("Raw Max That Day")
                        Spacer()
                        Text(String(format: "%.0f bpm", estimate.rawMaxHR))
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)

                    HStack {
                        Text("Ride Duration")
                        Spacer()
                        Text(formatDuration(estimate.workoutDuration))
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)

                // Top candidates
                if estimate.candidates.count > 1 {
                    candidateList(estimate.candidates)
                }

                if !estimate.implausible.isEmpty {
                    implausibleList(estimate.implausible, ceiling: estimate.plausibleCeiling)
                }

                // Apply button
                if currentMaxHR != estimate.estimatedMaxHR {
                    Button(action: {
                        onApply(estimate.estimatedMaxHR)
                        dismiss()
                    }) {
                        HStack {
                            Spacer()
                            Text("Use \(estimate.estimatedMaxHR) bpm as my Max HR")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .padding()
                        .background(Color.red)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                    }
                }

                Spacer(minLength: 40)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    private func candidateList(_ candidates: [HealthKitService.MaxHRCandidate]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Top Efforts")
                .font(.headline)

            ForEach(Array(candidates.prefix(5).enumerated()), id: \.offset) { index, candidate in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("#\(index + 1)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                            .frame(width: 24)

                        VStack(alignment: .leading) {
                            Text(candidate.date, style: .date)
                                .font(.caption)
                            Text("\(formatDuration(candidate.duration)) \u{00b7} \(candidate.sourceName)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }

                        Spacer()

                        if candidate.isSpiky {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .help("Raw max well above sustained — spiky data")
                        }

                        VStack(alignment: .trailing) {
                            Text(String(format: "%.0f", candidate.sustainedHR))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("15s held")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(width: 52)

                        VStack(alignment: .trailing) {
                            Text(String(format: "%.0f", candidate.rawMaxHR))
                                .font(.subheadline)
                            Text("raw max")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(width: 52)
                    }

                    if let rejected = candidate.rejectedPeakHR {
                        Text("Rejected a sustained \(Int(rejected.rounded())) bpm block \u{2014} signal stepped there discontinuously (sensor artifact)")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .padding(.leading, 24)
                    }
                }
                .padding(.vertical, 4)

                if index < min(4, candidates.count - 1) {
                    Divider()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    private func implausibleList(_ candidates: [HealthKitService.MaxHRCandidate],
                                 ceiling: Double?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Excluded — Not Physiologically Possible", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)

            if let ceiling {
                Text("Your threshold HR bounds your true max at ~\(Int(ceiling.rounded())) bpm (threshold is 85\u{2013}92% of max). Sustained readings above that are sensor faults \u{2014} typically a chest strap doubling your real HR. A cluster of them on nearby dates usually means the strap was failing that week.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(candidates.enumerated()), id: \.offset) { _, candidate in
                HStack {
                    VStack(alignment: .leading) {
                        Text(candidate.date, style: .date)
                            .font(.caption)
                        Text("\(formatDuration(candidate.duration)) \u{00b7} \(candidate.sourceName)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()

                    VStack(alignment: .trailing) {
                        Text(String(format: "%.0f", candidate.sustainedHR))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.orange)
                        Text("likely 2\u{00d7} of \(Int((candidate.sustainedHR / 2).rounded()))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Not Enough Data")
                .font(.title2)
                .fontWeight(.bold)

            Text("Need cycling workouts with heart rate data in the last 2 years.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
