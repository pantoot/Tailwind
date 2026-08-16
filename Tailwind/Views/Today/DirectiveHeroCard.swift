import SwiftUI

/// The Today tab's hero: form state, TSB, today's prescription with a target
/// TSS range, and the "why" sentence that explains the number.
struct DirectiveHeroCard: View {
    let tsb: Double
    let rampRate: Double
    let directive: TrainingDirectiveService.Directive

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Circle()
                    .fill(directive.status.color)
                    .frame(width: 16, height: 16)

                Text(directive.status.rawValue)
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Text(String(format: "%+.0f", tsb))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(tsb >= 0 ? .green : .orange)
            }

            HStack(alignment: .firstTextBaseline) {
                Image(systemName: prescriptionIcon)
                    .foregroundStyle(directive.isRampCapped ? .red : directive.status.color)
                Text(directive.prescription)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(directive.why)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if abs(rampRate) >= 1 {
                Divider()
                HStack {
                    Circle()
                        .fill(directive.isRampCapped ? Color.red : Color.green)
                        .frame(width: 10, height: 10)
                    Text("Ramp Rate")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text(String(format: "%+.1f CTL/wk", rampRate))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(directive.isRampCapped ? .red : .primary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    private var prescriptionIcon: String {
        if directive.isRampCapped {
            return "exclamationmark.triangle.fill"
        }
        switch directive.status {
        case .fresh, .rested:
            return "bolt.fill"
        case .optimal:
            return "checkmark.circle.fill"
        case .productive:
            return "exclamationmark.triangle.fill"
        case .overreaching:
            return "bed.double.fill"
        }
    }
}
