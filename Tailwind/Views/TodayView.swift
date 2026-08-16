import SwiftUI
import Charts

/// The daily 10-second check: form state, today's directive, and the
/// training-load picture at a glance.
struct TodayView: View {
    @EnvironmentObject var rideHistory: RideHistory
    @EnvironmentObject var trainingLoadManager: TrainingLoadManager

    /// Everything the screen shows, computed once per render. The EMA walks
    /// behind these numbers are not free — referencing manager methods
    /// directly from each subview used to re-run them ~10× per render.
    private struct TodaySnapshot {
        let metrics: PerformanceMetrics
        let rampRate: Double
        let weekTSS: Double
        let typicalWeekTSS: Double
        let history: [(date: Date, ctl: Double, atl: Double, tsb: Double)]
        let lastRide: Ride?
        let directive: TrainingDirectiveService.Directive
    }

    var body: some View {
        let snapshot = makeSnapshot()
        return NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    DirectiveHeroCard(
                        tsb: snapshot.metrics.tsb,
                        rampRate: snapshot.rampRate,
                        directive: snapshot.directive
                    )

                    GlanceTileGrid(
                        metrics: snapshot.metrics,
                        rampRate: snapshot.rampRate,
                        weekTSS: snapshot.weekTSS,
                        typicalWeekTSS: snapshot.typicalWeekTSS,
                        lastRide: snapshot.lastRide
                    )

                    if !snapshot.history.isEmpty {
                        formChartSection(history: snapshot.history)
                    }

                    if !rideHistory.rides.isEmpty {
                        recentRidesSection
                    }

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Today")
        }
    }

    private func makeSnapshot() -> TodaySnapshot {
        let metrics = trainingLoadManager.calculateCurrentMetrics()
        let rampRate = trainingLoadManager.getRampRate()
        let weekly = trainingLoadManager.getWeeklySummary()
        let history = trainingLoadManager.dailyLoads.isEmpty
            ? []
            : trainingLoadManager.getHistoricalMetrics(days: 30)
        // Defensive max: rides are usually stored most-recent-first, but
        // nothing enforces it.
        let lastRide = rideHistory.rides.max(by: { $0.date < $1.date })
        let directive = TrainingDirectiveService.directive(
            metrics: metrics,
            rampRate: rampRate,
            recentRides: rideHistory.rides.map { .init(date: $0.date, tss: $0.hrTSS) },
            today: Date()
        )

        return TodaySnapshot(
            metrics: metrics,
            rampRate: rampRate,
            weekTSS: weekly.weekTSS,
            typicalWeekTSS: trainingLoadManager.getFourWeekTypicalWeekTSS(),
            history: history,
            lastRide: lastRide,
            directive: directive
        )
    }

    // MARK: - Form Chart Section

    private func formChartSection(history: [(date: Date, ctl: Double, atl: Double, tsb: Double)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Training Load")
                .font(.headline)

            FormChart(data: history)
                .frame(height: 180)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    // MARK: - Recent Rides Section

    private var recentRidesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Rides")
                    .font(.headline)
                Spacer()
                NavigationLink("See All") {
                    RideHistoryView()
                }
                .font(.subheadline)
            }

            VStack(spacing: 8) {
                ForEach(rideHistory.rides.prefix(3)) { ride in
                    NavigationLink(destination: RideDetailView(ride: ride)) {
                        RideRow(ride: ride)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

#Preview {
    TodayView()
        .environmentObject(RideHistory())
        .environmentObject(TrainingLoadManager())
}
