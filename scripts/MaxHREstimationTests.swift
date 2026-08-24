import Foundation

// MARK: - MaxHREstimationService

private typealias HRS = MaxHREstimationService.HRSample

/// 1Hz samples from an array of bpm values.
private func oneHz(_ bpm: [Double]) -> [HRS] {
    bpm.enumerated().map { HRS(offset: TimeInterval($0.offset), bpm: $0.element) }
}

func runMaxHREstimationTests(_ t: TestRun) {
    testInsufficientData(t)
    testCleanSignal(t)
    testSpikeRejection(t)
    testStartOfRecordingSpike(t)
    testGenuinePlateauSurvives(t)
    testShortPlateauDiluted(t)
    testSparseWatchSampling(t)
    testUnsortedInput(t)
    testRecordingGap(t)
    testGapSampleCannotDominateWindow(t)
}

private func testGapSampleCannotDominateWindow(_ t: TestRun) {
    // A brief 180 surge whose last sample sits before a 10s strap dropout:
    // that one sample's time weight must be capped well below the window
    // length, or it alone drags a "sustained" window to near-surge values.
    var samples = (0...17).map { HRS(offset: TimeInterval($0), bpm: 150) }
    samples += (18...20).map { HRS(offset: TimeInterval($0), bpm: 180) }
    samples += (30...50).map { HRS(offset: TimeInterval($0), bpm: 150) }
    guard let r = MaxHREstimationService.bestSustained(samples: samples) else {
        t.expect(false, "gap-adjacent surge produces a result"); return
    }
    t.expect(r.bestSustainedHR < 165,
             "3s surge before a dropout cannot dominate the window, got \(r.bestSustainedHR)")
}

private func testInsufficientData(_ t: TestRun) {
    t.expect(MaxHREstimationService.bestSustained(samples: []) == nil, "empty samples give nil")
    t.expect(MaxHREstimationService.bestSustained(samples: oneHz([150, 150, 150])) == nil,
             "3 samples give nil")
    // Enough samples but the recording is shorter than a valid window.
    t.expect(MaxHREstimationService.bestSustained(samples: oneHz(Array(repeating: 150, count: 6))) == nil,
             "6-second recording has no full window")
}

private func testCleanSignal(_ t: TestRun) {
    guard let r = MaxHREstimationService.bestSustained(samples: oneHz(Array(repeating: 150, count: 60))) else {
        t.expect(false, "constant signal produces a result"); return
    }
    t.expectEqual(r.bestSustainedHR.rounded(), 150, "constant 150 sustains at 150")
    t.expectEqual(r.rawMaxHR, 150, "raw max matches on clean data")
    t.expectEqual(r.suspectSampleCount, 0, "no suspects on clean data")
}

private func testSpikeRejection(_ t: TestRun) {
    // A single-sample strap spike to 195 in an otherwise steady 150 ride —
    // exactly the artifact that makes the Health app report a 195 max.
    var bpm = [Double](repeating: 150, count: 60)
    bpm[30] = 195
    guard let r = MaxHREstimationService.bestSustained(samples: oneHz(bpm)) else {
        t.expect(false, "spiked signal produces a result"); return
    }
    t.expectEqual(r.bestSustainedHR.rounded(), 150, "single-sample spike is filtered out")
    t.expectEqual(r.rawMaxHR, 195, "raw max still reports the spike")
    t.expect(r.suspectSampleCount >= 1, "spike counted as suspect")

    // Two adjacent spike samples also die to the median filter.
    bpm[31] = 195
    guard let r2 = MaxHREstimationService.bestSustained(samples: oneHz(bpm)) else {
        t.expect(false, "double-spiked signal produces a result"); return
    }
    t.expectEqual(r2.bestSustainedHR.rounded(), 150, "two-sample spike is filtered out")
}

private func testStartOfRecordingSpike(_ t: TestRun) {
    // Dry-strap static at the very first sample must not poison the rest.
    var bpm = [Double](repeating: 140, count: 40)
    bpm[0] = 195
    guard let r = MaxHREstimationService.bestSustained(samples: oneHz(bpm)) else {
        t.expect(false, "start-spiked signal produces a result"); return
    }
    t.expectEqual(r.bestSustainedHR.rounded(), 140, "leading spike is filtered out")
}

private func testGenuinePlateauSurvives(_ t: TestRun) {
    // A real max effort: plausible ramp 140 -> 168 over a minute, then 20s
    // held at 168. The sustained value must report the plateau, not discount it.
    var bpm: [Double] = (0..<60).map { 140 + Double($0) * 28.0 / 59.0 }
    bpm += [Double](repeating: 168, count: 20)
    guard let r = MaxHREstimationService.bestSustained(samples: oneHz(bpm)) else {
        t.expect(false, "ramp-and-hold produces a result"); return
    }
    t.expect(r.bestSustainedHR > 167.5 && r.bestSustainedHR <= 168,
             "20s genuine plateau sustains at plateau value, got \(r.bestSustainedHR)")
    t.expectEqual(r.suspectSampleCount, 0, "smooth ramp has no suspects")
}

private func testShortPlateauDiluted(_ t: TestRun) {
    // 168 held for only 5s: real signal (survives the median filter, so it is
    // not a suspect) but too brief to define the sustained max — the window
    // average dilutes it toward the surrounding 150s.
    var bpm = [Double](repeating: 150, count: 45)
    for i in 20..<25 { bpm[i] = 168 }
    guard let r = MaxHREstimationService.bestSustained(samples: oneHz(bpm)) else {
        t.expect(false, "short plateau produces a result"); return
    }
    t.expect(r.bestSustainedHR > 150 && r.bestSustainedHR < 160,
             "5s plateau dilutes into the window, got \(r.bestSustainedHR)")
    t.expectEqual(r.rawMaxHR, 168, "raw max reports the brief peak")
}

private func testSparseWatchSampling(_ t: TestRun) {
    // Apple Watch style ~5s sampling: constant 160 must still produce a valid
    // window via time weighting (4 samples cover 15s).
    let sparse = (0..<20).map { HRS(offset: TimeInterval($0 * 5), bpm: 160) }
    guard let r = MaxHREstimationService.bestSustained(samples: sparse) else {
        t.expect(false, "sparse constant signal produces a result"); return
    }
    t.expectEqual(r.bestSustainedHR.rounded(), 160, "sparse sampling sustains correctly")

    // A genuine 20s / 4-sample plateau at 170 in sparse data survives.
    var plateau = [Double](repeating: 150, count: 20)
    for i in 10..<14 { plateau[i] = 170 }
    let sparsePlateau = plateau.enumerated().map { HRS(offset: TimeInterval($0.offset * 5), bpm: $0.element) }
    guard let r2 = MaxHREstimationService.bestSustained(samples: sparsePlateau) else {
        t.expect(false, "sparse plateau produces a result"); return
    }
    t.expectEqual(r2.bestSustainedHR.rounded(), 170, "sparse 20s plateau sustains at plateau value")
}

private func testUnsortedInput(_ t: TestRun) {
    // HealthKit sorts for us, but the service must not depend on it.
    let shuffled = oneHz(Array(repeating: 150, count: 30)).shuffled()
    guard let r = MaxHREstimationService.bestSustained(samples: shuffled) else {
        t.expect(false, "unsorted input produces a result"); return
    }
    t.expectEqual(r.bestSustainedHR.rounded(), 150, "unsorted input handled")
}

private func testRecordingGap(_ t: TestRun) {
    // Two short clusters separated by a 5-minute dropout: neither cluster can
    // fill a window, and the gap must not be bridged into a fake one.
    let a = (0...10).map { HRS(offset: TimeInterval($0), bpm: 165) }
    let b = (0...10).map { HRS(offset: TimeInterval(310 + $0), bpm: 165) }
    t.expect(MaxHREstimationService.bestSustained(samples: a + b) == nil,
             "gap-separated clusters yield no valid window")
}
