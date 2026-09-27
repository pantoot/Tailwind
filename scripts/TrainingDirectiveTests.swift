import Foundation

// Minimal assertion harness — exits non-zero on any failure.
final class TestRun {
    private(set) var passed = 0
    private(set) var failed = 0

    func expect(_ condition: Bool, _ label: String) {
        if condition {
            passed += 1
        } else {
            failed += 1
            print("❌ FAIL: \(label)")
        }
    }

    func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ label: String) {
        expect(actual == expected, "\(label) — expected \(expected), got \(actual)")
    }

    func finish() -> Never {
        print(failed == 0
            ? "✅ \(passed) assertions passed"
            : "❌ \(failed) failed, \(passed) passed")
        exit(failed == 0 ? 0 : 1)
    }
}

// MARK: - Characterization: FormStatus TSB bands (locked before refactor)

func testFormStatusBands(_ t: TestRun) {
    func status(_ tsb: Double) -> PerformanceMetrics.FormStatus {
        PerformanceMetrics(ctl: 50, atl: 50 - tsb, tsb: tsb).formStatus
    }

    t.expectEqual(status(25), .fresh, "TSB 25 is Very Fresh")
    t.expectEqual(status(24.9), .rested, "TSB 24.9 is Rested")
    t.expectEqual(status(5), .rested, "TSB 5 is Rested")
    t.expectEqual(status(4.9), .optimal, "TSB 4.9 is Optimal")
    t.expectEqual(status(-10), .optimal, "TSB -10 is Optimal")
    t.expectEqual(status(-10.1), .productive, "TSB -10.1 is Productive")
    t.expectEqual(status(-30), .productive, "TSB -30 is Productive")
    t.expectEqual(status(-30.1), .overreaching, "TSB -30.1 is Deep Fatigue")
    t.expectEqual(status(0), .optimal, "TSB 0 is Optimal")
    t.expectEqual(status(100), .fresh, "TSB 100 is Very Fresh")
    t.expectEqual(status(-100), .overreaching, "TSB -100 is Deep Fatigue")
}

// MARK: - TrainingDirectiveService

private let calendar = Calendar.current
private let today = calendar.startOfDay(for: Date())

private func daysAgo(_ days: Int) -> Date {
    calendar.date(byAdding: .day, value: -days, to: today)!
}

private func directive(
    ctl: Double, tsb: Double, ramp: Double = 0,
    rides: [TrainingDirectiveService.RecentRide] = []
) -> TrainingDirectiveService.Directive {
    TrainingDirectiveService.directive(
        metrics: PerformanceMetrics(ctl: ctl, atl: ctl - tsb, tsb: tsb),
        rampRate: ramp,
        recentRides: rides,
        today: today,
        calendar: calendar
    )
}

func testTargetRangePerBand(_ t: TestRun) {
    // CTL 60, multipliers of CTL: fresh 1.2–1.8, rested 1.0–1.5,
    // optimal 0.8–1.2, productive 0.5–0.9, overreaching 0–0.4.
    t.expectEqual(directive(ctl: 60, tsb: 30).targetTSSRange, 72...108, "Very Fresh range")
    t.expectEqual(directive(ctl: 60, tsb: 10).targetTSSRange, 60...90, "Rested range")
    t.expectEqual(directive(ctl: 60, tsb: 0).targetTSSRange, 48...72, "Optimal range")
    t.expectEqual(directive(ctl: 60, tsb: -20).targetTSSRange, 30...54, "Productive range")
    t.expectEqual(directive(ctl: 60, tsb: -35).targetTSSRange, 0...24, "Deep Fatigue range")
}

func testRampCap(_ t: TestRun) {
    // Ramp > 5 caps both bounds to at most 0–0.6 × CTL — it can only lower.
    let capped = directive(ctl: 60, tsb: 10, ramp: 6)
    t.expectEqual(capped.targetTSSRange, 0...36, "Rested capped to 0–0.6 CTL when ramping")
    t.expect(capped.isRampCapped, "isRampCapped set when ramp > 5")

    // Already-lower band is NOT raised by the cap.
    let deepFatigue = directive(ctl: 60, tsb: -35, ramp: 6)
    t.expectEqual(deepFatigue.targetTSSRange, 0...24, "Cap never raises Deep Fatigue range")

    // At the threshold exactly, no cap (mirrors existing > 5 warning).
    let atThreshold = directive(ctl: 60, tsb: 10, ramp: 5)
    t.expect(!atThreshold.isRampCapped, "ramp == 5 is not capped")
    t.expectEqual(atThreshold.targetTSSRange, 60...90, "ramp == 5 keeps band range")

    // Capped prescription tells the rider to back off.
    t.expect(capped.prescription.lowercased().contains("back off"),
             "capped prescription says back off")
}

func testInsufficientHistory(_ t: TestRun) {
    let d = directive(ctl: 5, tsb: 2)
    t.expectEqual(d.targetTSSRange, nil, "CTL < 10 gives no target range")
    t.expect(d.prescription.lowercased().contains("history"),
             "insufficient-history prescription mentions history")
    t.expect(!d.why.isEmpty, "insufficient-history why is non-empty")
}

func testWhySentence(_ t: TestRun) {
    // Empty rides → non-empty CTL-only sentence, no crash.
    let noRides = directive(ctl: 60, tsb: 0)
    t.expect(!noRides.why.isEmpty, "empty rides still yields a why sentence")
    t.expect(noRides.why.contains("60"), "CTL-only why cites CTL value")

    // All-nil TSS rides → falls back to CTL-only sentence.
    let nilTSS = directive(ctl: 60, tsb: 0, rides: [
        .init(date: daysAgo(1), tss: nil),
        .init(date: daysAgo(2), tss: nil),
    ])
    t.expect(nilTSS.why.contains("60"), "all-nil TSS falls back to CTL-only why")

    // Ride today is phrased as today, not a weekday.
    let todayRide = directive(ctl: 60, tsb: 0, rides: [.init(date: today, tss: 92)])
    t.expect(todayRide.why.lowercased().contains("today"), "today's ride phrased as today")
    t.expect(todayRide.why.contains("92"), "why cites the ride's TSS")

    // Ride 4 days ago is phrased with its weekday name.
    let weekdayFormatter = DateFormatter()
    weekdayFormatter.locale = Locale(identifier: "en_US_POSIX")
    weekdayFormatter.dateFormat = "EEEE"
    let expectedDay = weekdayFormatter.string(from: daysAgo(4))
    let pastRide = directive(ctl: 60, tsb: 0, rides: [.init(date: daysAgo(4), tss: 88)])
    t.expect(pastRide.why.contains(expectedDay), "past ride phrased with weekday \(expectedDay)")

    // Yesterday is phrased as yesterday.
    let yesterdayRide = directive(ctl: 60, tsb: 0, rides: [.init(date: daysAgo(1), tss: 75)])
    t.expect(yesterdayRide.why.lowercased().contains("yesterday"), "yesterday's ride phrased as yesterday")

    // Out-of-order input still picks the most recent ride with TSS.
    let outOfOrder = directive(ctl: 60, tsb: 0, rides: [
        .init(date: daysAgo(6), tss: 40),
        .init(date: daysAgo(1), tss: 75),
        .init(date: daysAgo(3), tss: 55),
    ])
    t.expect(outOfOrder.why.contains("75"), "most recent ride wins regardless of order")

    // Most recent ride has nil TSS → next one with TSS is used.
    let mixedNil = directive(ctl: 60, tsb: 0, rides: [
        .init(date: daysAgo(1), tss: nil),
        .init(date: daysAgo(2), tss: 66),
    ])
    t.expect(mixedNil.why.contains("66"), "nil-TSS ride skipped for the why sentence")
}

func testRangeSanity(_ t: TestRun) {
    // Tiny CTL just over the floor never produces lower > upper.
    for ctl in [10.0, 10.4, 11.0, 15.0] {
        for tsb in [30.0, 10.0, 0.0, -20.0, -35.0] {
            let d = directive(ctl: ctl, tsb: tsb)
            if let range = d.targetTSSRange {
                t.expect(range.lowerBound <= range.upperBound,
                         "range valid for ctl \(ctl) tsb \(tsb)")
            } else {
                t.expect(false, "ctl \(ctl) should produce a range")
            }
        }
    }
    // Prescription always non-empty and cites the range when one exists.
    let d = directive(ctl: 60, tsb: 0)
    t.expect(d.prescription.contains("48") && d.prescription.contains("72"),
             "prescription cites the target range")
}

// MARK: - Four-week typical load

func testFourWeekTypical(_ t: TestRun) {
    let manager = TrainingLoadManager()

    manager.dailyLoads = []
    t.expectEqual(manager.getFourWeekTypicalWeekTSS(), 0, "empty history gives 0 typical")

    // 8 rides of 100 TSS inside the last 28 days → 800 / 4 = 200 per week.
    // dailyLoads has no zero rows for rest days, so the divisor must be a
    // fixed 4 weeks — dividing by entry count would overstate load.
    manager.dailyLoads = (1...8).map { DailyTrainingLoad(date: daysAgo($0 * 3), tss: 100) }
    t.expectEqual(manager.getFourWeekTypicalWeekTSS(), 200, "divides by 4 weeks, not entry count")

    // Rides older than the 28-day window are excluded.
    manager.dailyLoads.append(DailyTrainingLoad(date: daysAgo(29), tss: 500))
    t.expectEqual(manager.getFourWeekTypicalWeekTSS(), 200, "29-day-old ride excluded")
}

// MARK: - Entry point

@main
struct TestRunner {
    static func main() {
        let t = TestRun()
        testFormStatusBands(t)
        testTargetRangePerBand(t)
        testRampCap(t)
        testInsufficientHistory(t)
        testWhySentence(t)
        testRangeSanity(t)
        testFourWeekTypical(t)
        runMaxHREstimationTests(t)
        runRideClassificationTests(t)
        runRideListTests(t)
        runAerobicDecouplingTests(t)
        t.finish()
    }
}
