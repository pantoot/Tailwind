import SwiftUI
import Charts

/// 30-day training-load chart: CTL line, ATL dashed line, TSB area, drawn
/// over shaded form-zone bands (intervals.icu style). Rendered on the Today
/// tab. Band boundaries come from the FormStatus band table so the chart can
/// never disagree with the hero card.
struct FormChart: View {
    let data: [(date: Date, ctl: Double, atl: Double, tsb: Double)]

    private static let bandOpacity = 0.08

    /// Explicit y-domain: bands need finite edges to draw against, and pinning
    /// the floor/ceiling keeps the axis from jumping as data shifts.
    private var yDomain: ClosedRange<Double> {
        let values = data.flatMap { [$0.ctl, $0.atl, $0.tsb] }
        let low = min(values.min() ?? 0, -35) - 5
        let high = max(values.max() ?? 0, 30) + 5
        return low...high
    }

    var body: some View {
        Chart {
            // Form-zone bands, declared first so every mark draws above them.
            ForEach(PerformanceMetrics.FormStatus.allCases, id: \.self) { status in
                let bounds = status.tsbBounds
                RectangleMark(
                    yStart: .value("Band start", max(bounds.lower, yDomain.lowerBound)),
                    yEnd: .value("Band end", min(bounds.upper ?? yDomain.upperBound, yDomain.upperBound))
                )
                .foregroundStyle(status.color.opacity(Self.bandOpacity))
            }

            // TSB area (form)
            ForEach(data, id: \.date) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("TSB", point.tsb)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [point.tsb >= 0 ? .green.opacity(0.3) : .red.opacity(0.3), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }

            // CTL line (fitness)
            ForEach(data, id: \.date) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("CTL", point.ctl)
                )
                .foregroundStyle(.blue)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }

            // ATL line (fatigue)
            ForEach(data, id: \.date) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("ATL", point.atl)
                )
                .foregroundStyle(.orange)
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
            }

            // Zero line for TSB
            RuleMark(y: .value("Zero", 0))
                .foregroundStyle(.gray.opacity(0.3))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }
        .chartYScale(domain: yDomain)
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 7)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
            }
        }
        .chartLegend(position: .bottom, spacing: 20) {
            HStack(spacing: 16) {
                Label("Fitness", systemImage: "line.diagonal")
                    .foregroundStyle(.blue)
                Label("Fatigue", systemImage: "line.diagonal")
                    .foregroundStyle(.orange)
                Label("Form", systemImage: "square.fill")
                    .foregroundStyle(.green)
            }
            .font(.caption)
        }
    }
}
