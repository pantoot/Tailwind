import SwiftUI

/// Renders the current import job. Pinned above the segment content so it
/// survives History↔Power switches.
struct ImportStatusBanner: View {
    @EnvironmentObject var statusCenter: ImportStatusCenter

    var body: some View {
        VStack(spacing: 6) {
            // Undismissed failures sit above the active job, so starting a new
            // import never hides one the user hasn't seen.
            ForEach(statusCenter.failures) { failure in
                row(failure) { statusCenter.dismissFailure(id: failure.id) }
            }

            if let status = statusCenter.current {
                row(status) { statusCenter.dismiss() }
            }
        }
        .padding(.bottom, statusCenter.current == nil && statusCenter.failures.isEmpty ? 0 : 8)
    }

    private func row(_ status: ImportStatusCenter.Status, dismiss: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            icon(for: status.phase)

            VStack(alignment: .leading, spacing: 2) {
                Text(status.title)
                    .font(.caption)
                    .fontWeight(.medium)
                if !status.detail.isEmpty {
                    Text(status.detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(background(for: status.phase))
        .cornerRadius(10)
        .padding(.horizontal)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    @ViewBuilder
    private func icon(for phase: ImportStatusCenter.Phase) -> some View {
        switch phase {
        case .running:
            ProgressView()
        case .success:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failure:
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
        }
    }

    private func background(for phase: ImportStatusCenter.Phase) -> Color {
        switch phase {
        case .running: return Color(.secondarySystemBackground)
        case .success: return Color.green.opacity(0.12)
        case .failure: return Color.red.opacity(0.12)
        }
    }
}
