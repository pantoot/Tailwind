import Foundation

typealias ADS = AerobicDecouplingService

// Synthetic 1Hz streams. `seconds` long; power/HR given per-half so a test can
// dial in an exact drift and check the reported percentage against arithmetic.
private func steady(_ value: Double, seconds: Int) -> [Double] {
    [Double](repeating: value, count: seconds)
}

private func halves(first: Double, second: Double, seconds: Int) -> [Double] {
    let half = seconds / 2
    return steady(first, seconds: half) + steady(second, seconds: seconds - half)
}

private let hour = 3600

// MARK: - Gating

func testDecouplingGating(_ t: TestRun) {
    let short = ADS.minimumRideSeconds - 1
    t.expect(ADS.decoupling(densePower: steady(200, seconds: short), denseHR: steady(140, seconds: short)) == nil,
             "ride under the minimum yields nil")
    t.expect(ADS.decoupling(densePower: steady(200, seconds: hour), denseHR: steady(0, seconds: hour)) == nil,
             "all-zero HR (no strap) yields nil")
    t.expect(ADS.decoupling(densePower: steady(200, seconds: hour), denseHR: []) == nil,
             "empty HR yields nil")
    t.expect(ADS.decoupling(densePower: steady(0, seconds: hour), denseHR: steady(140, seconds: hour)) == nil,
             "all-zero power yields nil rather than a divide-by-zero")
    t.expect(ADS.decoupling(densePower: steady(200, seconds: ADS.minimumRideSeconds),
                            denseHR: steady(140, seconds: ADS.minimumRideSeconds)) != nil,
             "ride exactly at the minimum is analyzed")
}

// MARK: - Arithmetic

func testDecouplingArithmetic(_ t: TestRun) {
    // Perfectly steady ride: identical halves, zero drift.
    let flat = ADS.decoupling(densePower: steady(200, seconds: hour), denseHR: steady(140, seconds: hour))!
    t.expect(abs(flat.percent) < 0.01, "steady power and HR decouple 0%, got \(flat.percent)")
    t.expect(abs(flat.firstHalfEfficiency - 200.0 / 140.0) < 0.001, "EF is NP over avg HR")
    t.expect(abs(flat.secondHalfEfficiency - flat.firstHalfEfficiency) < 0.001, "halves match")

    // HR climbs 10% at constant power: EF2 = EF1 / 1.1 → (1 - 1/1.1) = 9.09%.
    let drift = ADS.decoupling(densePower: steady(200, seconds: hour),
                               denseHR: halves(first: 140, second: 154, seconds: hour))!
    t.expect(abs(drift.percent - 9.09) < 0.05, "10% HR rise reads 9.09%, got \(drift.percent)")

    // Power falls 10% at constant HR is the same physiological story and must
    // read the same sign — decoupling is about the ratio, not which side moved.
    let fade = ADS.decoupling(densePower: halves(first: 200, second: 180, seconds: hour),
                              denseHR: steady(140, seconds: hour))!
    t.expect(abs(fade.percent - 10.0) < 0.05, "10% power fade reads 10%, got \(fade.percent)")

    // HR settling lower in the second half is negative, not clamped to zero.
    let settle = ADS.decoupling(densePower: steady(200, seconds: hour),
                                denseHR: halves(first: 150, second: 140, seconds: hour))!
    t.expect(settle.percent < -6.0, "HR falling reads negative, got \(settle.percent)")
}

// MARK: - Warm-up / cool-down trimming

func testDecouplingTrimsEdges(_ t: TestRun) {
    // HR lags power for the first minutes of a cold start. Left in, that low-HR
    // lead-in inflates first-half efficiency and manufactures drift on a ride
    // that was actually steady. The lead-in sits inside the trim window.
    let trim = ADS.trimSeconds
    var hr = steady(140, seconds: hour)
    for i in 0..<trim { hr[i] = 100 }
    let coldStart = ADS.decoupling(densePower: steady(200, seconds: hour), denseHR: hr)!
    t.expect(abs(coldStart.percent) < 0.01, "cold-start lag inside the trim window is ignored, got \(coldStart.percent)")

    // Peloton classes end with a soft-pedal cool-down while HR is still high.
    var power = steady(200, seconds: hour)
    for i in (hour - trim)..<hour { power[i] = 60 }
    let coolDown = ADS.decoupling(densePower: power, denseHR: steady(140, seconds: hour))!
    t.expect(abs(coolDown.percent) < 0.01, "cool-down inside the trim window is ignored, got \(coolDown.percent)")

    // But lag that outlasts the trim window is real signal and must count.
    var longLag = steady(140, seconds: hour)
    for i in 0..<(trim * 3) { longLag[i] = 100 }
    let counted = ADS.decoupling(densePower: steady(200, seconds: hour), denseHR: longLag)!
    // Low HR early means relatively high HR late: that is positive drift,
    // and from the data alone it is indistinguishable from the real thing.
    t.expect(counted.percent > 5.0, "HR depressed well past the trim counts as positive drift, got \(counted.percent)")
}

// MARK: - Rating bands

func testDecouplingRating(_ t: TestRun) {
    t.expectEqual(AerobicDecoupling.rating(forPercent: 0), .coupled, "0% is coupled")
    t.expectEqual(AerobicDecoupling.rating(forPercent: -8), .coupled, "negative is coupled")
    t.expectEqual(AerobicDecoupling.rating(forPercent: 4.99), .coupled, "just under 5% is coupled")
    t.expectEqual(AerobicDecoupling.rating(forPercent: 5.0), .moderate, "5% is moderate")
    t.expectEqual(AerobicDecoupling.rating(forPercent: 9.99), .moderate, "just under 10% is moderate")
    t.expectEqual(AerobicDecoupling.rating(forPercent: 10.0), .high, "10% is high")
    t.expectEqual(AerobicDecoupling.rating(forPercent: 25), .high, "25% is high")
}

func runAerobicDecouplingTests(_ t: TestRun) {
    testDecouplingGating(t)
    testDecouplingArithmetic(t)
    testDecouplingTrimsEdges(t)
    testDecouplingRating(t)
}
