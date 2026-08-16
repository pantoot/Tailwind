import SwiftUI

/// 2×2 at-a-glance metrics under the hero: fitness with trend, fatigue,
/// 7-day load vs typical, and the last ride.
struct GlanceTileGrid: View {
    let metrics: PerformanceMetrics
    let rampRate: Double
    let weekTSS: Double
    let typicalWeekTSS: Double
    let lastRide: Ride?

    private static let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        LazyVGrid(columns: Self.columns, spacing: 12) {
            GlanceTile(
                title: "Fitness · CTL",
                value: String(format: "%.0f", metrics.ctl),
                detail: String(format: "%+.1f /wk", rampRate),
                detailColor: rampRate > TrainingDirectiveService.rampCapThreshold ? .red : .secondary
            )

            GlanceTile(
                title: "Fatigue · ATL",
                value: String(format: "%.0f", metrics.atl)
            )

            GlanceTile(
                title: "7-Day TSS",
                value: String(format: "%.0f", weekTSS),
                detail: typicalWeekTSS > 0 ? String(format: "typical %.0f", typicalWeekTSS) : nil
            )

            GlanceTile(
                title: "Last Ride",
                value: lastRideValue,
                detail: lastRideDetail
            )
        }
    }

    private var lastRideValue: String {
        guard let ride = lastRide else { return "—" }
        guard let tss = ride.hrTSS else { return "n/a" }
        return String(format: "%.0f TSS", tss)
    }

    private var lastRideDetail: String? {
        guard let ride = lastRide else { return "No rides yet" }
        return TrainingDirectiveService.relativeDayName(for: ride.date, today: Date())
    }
}

private struct GlanceTile: View {
    let title: String
    let value: String
    var detail: String? = nil
    var detailColor: Color = .secondary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            if let detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(detailColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}
