import Foundation

typealias RCS = RideClassificationService

/// The real validation ride: 1 hour indoor, NP 192.2 / avg 187.8 (VI 1.023),
/// max 30s 237.9W, no matches, FTP 250. Steady tempo, and its 30s "peak" is
/// cruising power — not a burst.
private func steadyTempoHour(
    duration: TimeInterval = 3600,
    matchCount: Int = 0
) -> RCS.Input {
    RCS.Input(
        duration: duration,
        averagePower: 187.83,
        normalizedPower: 192.17,
        max30sPower: 237.87,
        matchCount: matchCount,
        averageHeartRate: 139.29,
        ftp: 250,
        lthr: 152
    )
}

private func input(
    duration: TimeInterval = 3600,
    avg: Double? = nil,
    np: Double? = nil,
    max30s: Double? = nil,
    matches: Int = 0,
    hr: Double? = nil,
    ftp: Int? = 250,
    lthr: Int? = nil
) -> RCS.Input {
    RCS.Input(duration: duration, averagePower: avg, normalizedPower: np,
              max30sPower: max30s, matchCount: matches, averageHeartRate: hr,
              ftp: ftp, lthr: lthr)
}

// MARK: - The fixture

func testFixtureRide(_ t: TestRun) {
    let c = RCS.classify(steadyTempoHour())
    t.expectEqual(c.structure, .steady, "fixture is steady (VI 1.023)")
    t.expectEqual(c.intensity, .tempo, "fixture is tempo (IF 0.769)")
    t.expectEqual(c.confidence, .high, "fixture has NP + FTP")
    t.expectEqual(c.label, "Steady tempo", "fixture label")
    t.expect(c.confidenceNote == nil, "high confidence carries no caveat")
    t.expect(!c.isBurstRepresentative,
             "fixture 30s peak is a floor artifact (237.9/187.8 = 1.27 < 1.5)")
    if let vi = c.variabilityIndex {
        t.expect(abs(vi - 1.023) < 0.01, "fixture VI ~1.023, got \(vi)")
    } else {
        t.expect(false, "fixture should have a VI")
    }
}

// MARK: - Intensity bands (zone-aligned %FTP)

func testIntensityBands(_ t: TestRun) {
    // IF is driven off NP; ftp 250 means NP = IF * 250.
    func band(_ ifValue: Double) -> RCS.Intensity {
        RCS.classify(input(avg: 200, np: ifValue * 250)).intensity
    }

    t.expectEqual(band(0.30), .recovery, "IF 0.30 is recovery")
    t.expectEqual(band(0.549), .recovery, "IF 0.549 is recovery")
    t.expectEqual(band(0.55), .endurance, "IF 0.55 is endurance")
    t.expectEqual(band(0.759), .endurance, "IF 0.759 is endurance")
    t.expectEqual(band(0.76), .tempo, "IF 0.76 is tempo")
    t.expectEqual(band(0.899), .tempo, "IF 0.899 is tempo")
    t.expectEqual(band(0.90), .threshold, "IF 0.90 is threshold")
    t.expectEqual(band(1.049), .threshold, "IF 1.049 is threshold")
    t.expectEqual(band(1.05), .hard, "IF 1.05 is hard")
    t.expectEqual(band(1.40), .hard, "IF 1.40 is hard")
}

// MARK: - Degradation ladder

func testIntensityDegradation(_ t: TestRun) {
    // NP wins over average power when both exist.
    let both = RCS.classify(input(avg: 250, np: 190))
    t.expectEqual(both.intensity, .tempo, "NP (0.76) beats avg power (1.00)")
    t.expectEqual(both.confidence, .high, "NP + FTP is high confidence")

    // Average power only -> medium confidence, with a caveat.
    let avgOnly = RCS.classify(input(avg: 190, np: nil))
    t.expectEqual(avgOnly.intensity, .tempo, "avg power scores IF when NP absent")
    t.expectEqual(avgOnly.confidence, .medium, "avg-power-only is medium confidence")
    t.expect(avgOnly.confidenceNote != nil, "medium confidence explains itself")

    // Power present AND heart rate present -> HR must be ignored entirely.
    // avgHR 139 / LTHR 152 = 0.915 would read "threshold"; NP says tempo.
    let powerWins = RCS.classify(steadyTempoHour())
    t.expectEqual(powerWins.intensity, .tempo, "HR never overrides power")
    t.expect(powerWins.confidenceNote == nil, "no HR caveat when power decided it")

    // No FTP but HR + LTHR -> HR fallback, low confidence, always caveated.
    let hrOnly = RCS.classify(input(avg: nil, np: nil, hr: 139, ftp: nil, lthr: 152))
    t.expectEqual(hrOnly.intensity, .threshold, "HR 139/152 = 0.915 -> threshold")
    t.expectEqual(hrOnly.confidence, .low, "HR-derived is low confidence")
    t.expect(hrOnly.confidenceNote != nil, "HR-derived always carries the cadence caveat")
    t.expectEqual(hrOnly.structure, .unknown, "HR never determines structure")

    // FTP of zero is the same as unset.
    let zeroFTP = RCS.classify(input(avg: 190, np: 195, hr: 139, ftp: 0, lthr: 152))
    t.expectEqual(zeroFTP.confidence, .low, "ftp 0 falls through to HR")

    // Nothing to go on.
    let nothing = RCS.classify(input(avg: nil, np: nil, ftp: nil, lthr: nil))
    t.expectEqual(nothing.intensity, .unknown, "no power, no HR -> unknown")
    t.expectEqual(nothing.confidence, .none, "no inputs -> no confidence")
    t.expectEqual(nothing.label, "Unclassified", "nothing known reads Unclassified")

    // Too short to classify at all.
    let short = RCS.classify(steadyTempoHour(duration: 14 * 60))
    t.expectEqual(short.intensity, .unknown, "14-minute ride is unclassified")
    t.expectEqual(short.structure, .unknown, "14-minute ride has no structure")
    t.expectEqual(short.confidence, .none, "14-minute ride has no confidence")
    t.expect(!short.isBurstRepresentative, "14-minute ride is never burst-representative")

    // Exactly at the 15-minute floor is classifiable.
    let atFloor = RCS.classify(steadyTempoHour(duration: 15 * 60))
    t.expectEqual(atFloor.intensity, .tempo, "15 minutes exactly is classifiable")
}

// MARK: - Structure

func testStructureBands(_ t: TestRun) {
    func structure(vi: Double, matches: Int = 0) -> RCS.Structure {
        RCS.classify(input(avg: 200, np: 200 * vi, matches: matches)).structure
    }

    t.expectEqual(structure(vi: 1.00), .steady, "VI 1.00 is steady")
    t.expectEqual(structure(vi: 1.049), .steady, "VI 1.049 is steady")
    t.expectEqual(structure(vi: 1.05), .mixed, "VI 1.05 is mixed")
    t.expectEqual(structure(vi: 1.149), .mixed, "VI 1.149 is mixed")
    t.expectEqual(structure(vi: 1.15), .intervals, "VI 1.15 is intervals")
    t.expectEqual(structure(vi: 1.40), .intervals, "VI 1.40 is intervals")

    // Matches escalate a mixed ride, but never override a steady VI.
    t.expectEqual(structure(vi: 1.08, matches: 2), .intervals,
                  "2 matches escalate mixed to intervals")
    t.expectEqual(structure(vi: 1.08, matches: 1), .mixed,
                  "1 match is not enough to escalate")
    t.expectEqual(structure(vi: 1.02, matches: 5), .steady,
                  "VI wins below 1.05 regardless of match count")

    // No NP -> no VI. Matches are the only remaining signal.
    t.expectEqual(RCS.classify(input(avg: 200, np: nil, matches: 2)).structure, .intervals,
                  "no VI but 2 matches -> intervals")
    t.expectEqual(RCS.classify(input(avg: 200, np: nil, matches: 0)).structure, .unknown,
                  "no VI and no matches -> unknown structure")
    t.expect(RCS.classify(input(avg: 200, np: nil)).variabilityIndex == nil,
             "VI is nil without NP")
}

// MARK: - Burst representativeness

func testBurstRepresentative(_ t: TestRun) {
    // The headline case: steady endurance 30s peak is not a burst.
    t.expect(!RCS.classify(steadyTempoHour()).isBurstRepresentative,
             "steady hour: 30s peak is cruising power")

    // Exactly at the ratio threshold counts.
    t.expect(RCS.classify(input(avg: 200, np: 210, max30s: 300)).isBurstRepresentative,
             "max30s exactly 1.5x average is a real burst")
    t.expect(!RCS.classify(input(avg: 200, np: 210, max30s: 299)).isBurstRepresentative,
             "just under 1.5x is not")

    // A single match qualifies even at a low ratio (it cleared 120% FTP).
    t.expect(RCS.classify(input(avg: 200, np: 210, max30s: 240, matches: 1)).isBurstRepresentative,
             "one match qualifies regardless of ratio")

    // Missing data never qualifies.
    t.expect(!RCS.classify(input(avg: nil, max30s: 300)).isBurstRepresentative,
             "no average power -> not representative")
    t.expect(!RCS.classify(input(avg: 200, max30s: nil)).isBurstRepresentative,
             "no 30s peak -> not representative")
    t.expect(!RCS.classify(input(avg: 200, max30s: 0)).isBurstRepresentative,
             "zero 30s peak -> not representative")
}

// MARK: - Labels

func testLabels(_ t: TestRun) {
    t.expectEqual(RCS.classify(steadyTempoHour()).label, "Steady tempo", "both axes known")
    t.expectEqual(RCS.classify(input(avg: 200, np: 300)).label, "Interval hard",
                  "interval + hard")
    // Structure known, intensity unknown (no FTP, no HR).
    t.expectEqual(RCS.classify(input(avg: 200, np: 200, ftp: nil)).label, "Steady",
                  "structure only")
    // Intensity known, structure unknown (no NP).
    t.expectEqual(RCS.classify(input(avg: 190, np: nil)).label, "Tempo",
                  "intensity only")
    t.expectEqual(RCS.classify(input(avg: nil, ftp: nil)).label, "Unclassified",
                  "neither axis")
}

// MARK: - Import summary copy

func testSummaryCopy(_ t: TestRun) {
    // The headline fix: a 3-hour Z2 ride at 150 TSS is a big day, not a hard one.
    let longZ2 = RCS.classify(input(duration: 3 * 3600, avg: 160, np: 163))
    t.expectEqual(longZ2.intensity, .endurance, "3h at IF 0.652 is endurance")
    let z2Copy = RCS.summaryCopy(for: longZ2, tss: 150)
    t.expectEqual(z2Copy.label, "Endurance", "long Z2 labelled Endurance, not Very Hard")
    t.expectEqual(z2Copy.tone, .easy, "long Z2 does not paint red")
    t.expect(z2Copy.interpretation.contains("150 TSS"), "volume still reported")
    t.expect(z2Copy.interpretation.contains("big day"), "volume acknowledged without calling it hard")
    t.expect(!z2Copy.interpretation.lowercased().contains("very hard"),
             "long endurance is never 'very hard'")

    // Ring tracks intensity, not volume, when IF is known.
    t.expect(abs(z2Copy.ringProgress - min(0.652 / 1.05, 1.0)) < 0.01,
             "ring follows IF when known")

    // Fixture reads as a tempo hour.
    let fixture = RCS.summaryCopy(for: RCS.classify(steadyTempoHour()), tss: 59)
    t.expectEqual(fixture.label, "Tempo", "fixture ring word")
    t.expectEqual(fixture.tone, .moderate, "tempo is moderate tone")
    t.expect(fixture.interpretation.contains("Steady tempo"), "fixture interpretation names structure")

    // A genuinely hard ride still reads hard.
    let hard = RCS.summaryCopy(for: RCS.classify(input(avg: 260, np: 275)), tss: 120)
    t.expectEqual(hard.label, "Hard", "IF 1.10 is hard")
    t.expectEqual(hard.tone, .veryHard, "hard intensity paints red")

    // Characterization: unclassifiable rides keep exactly the old copy.
    let none = RCS.classify(input(avg: nil, ftp: nil))
    t.expectEqual(RCS.summaryCopy(for: none, tss: 30).label, "Easy", "legacy <50 label")
    t.expectEqual(RCS.summaryCopy(for: none, tss: 30).interpretation,
                  "Recovery ride - low stress", "legacy <50 interpretation")
    t.expectEqual(RCS.summaryCopy(for: none, tss: 75).label, "Moderate", "legacy <100 label")
    t.expectEqual(RCS.summaryCopy(for: none, tss: 75).interpretation,
                  "Moderate effort - good training", "legacy <100 interpretation")
    t.expectEqual(RCS.summaryCopy(for: none, tss: 120).label, "Hard", "legacy <150 label")
    t.expectEqual(RCS.summaryCopy(for: none, tss: 120).interpretation,
                  "Hard workout - significant stress", "legacy <150 interpretation")
    t.expectEqual(RCS.summaryCopy(for: none, tss: 200).label, "Very Hard", "legacy >=150 label")
    t.expectEqual(RCS.summaryCopy(for: none, tss: 200).interpretation,
                  "Very hard - extended recovery needed", "legacy >=150 interpretation")
    t.expect(abs(RCS.summaryCopy(for: none, tss: 75).ringProgress - 0.5) < 0.001,
             "legacy ring is tss/150")
}

func runRideClassificationTests(_ t: TestRun) {
    testFixtureRide(t)
    testIntensityBands(t)
    testIntensityDegradation(t)
    testStructureBands(t)
    testBurstRepresentative(t)
    testLabels(t)
    testSummaryCopy(t)
}
