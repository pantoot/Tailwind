import Foundation

typealias RLS = RideListService

private let utc: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    return c
}()

private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
    utc.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
}

// MARK: - Month keys

func testMonthKeys(_ t: TestRun) {
    t.expectEqual(RLS.monthKey(for: date(2026, 8, 16), calendar: utc), "2026-08", "August key")
    t.expectEqual(RLS.monthKey(for: date(2026, 1, 1), calendar: utc), "2026-01", "January pads to 01")
    t.expectEqual(RLS.monthKey(for: date(2026, 12, 31), calendar: utc), "2026-12", "December key")
    t.expectEqual(RLS.monthKey(for: date(2025, 12, 31), calendar: utc), "2025-12", "prior year")

    // Keys must sort newest-first as plain strings — this is why they are
    // zero-padded and year-first.
    let sorted = RLS.sortedMonthKeys(["2025-12", "2026-01", "2026-08", "2025-09"])
    t.expectEqual(sorted, ["2026-08", "2026-01", "2025-12", "2025-09"],
                  "keys sort newest-first across a year boundary")
    t.expectEqual(RLS.sortedMonthKeys([]), [], "empty key list is fine")
    t.expectEqual(RLS.sortedMonthKeys(["2026-03"]), ["2026-03"], "single key")
}

// MARK: - Titles

func testMonthTitles(_ t: TestRun) {
    t.expectEqual(RLS.monthTitle(forKey: "2026-08"), "August 2026", "August title")
    t.expectEqual(RLS.monthTitle(forKey: "2026-01"), "January 2026", "January title")
    t.expectEqual(RLS.monthTitle(forKey: "2025-12"), "December 2025", "December title")
    // Malformed keys degrade to the key itself rather than crashing or
    // rendering an empty header.
    t.expectEqual(RLS.monthTitle(forKey: "garbage"), "garbage", "malformed key falls back")
    t.expectEqual(RLS.monthTitle(forKey: "2026-13"), "2026-13", "out-of-range month falls back")
    t.expectEqual(RLS.monthTitle(forKey: "2026-00"), "2026-00", "zero month falls back")
}

// MARK: - Default expansion

func testDefaultExpansion(_ t: TestRun) {
    let keys = ["2026-08", "2026-07", "2026-06"]

    // The current month opens by default.
    t.expectEqual(RLS.defaultExpandedKeys(allKeys: keys, now: date(2026, 8, 16), calendar: utc),
                  ["2026-08"], "current month expands")

    // No rides this month: fall back to the most recent month that has rides,
    // so the list never opens fully collapsed.
    t.expectEqual(RLS.defaultExpandedKeys(allKeys: keys, now: date(2026, 9, 2), calendar: utc),
                  ["2026-08"], "gap month falls back to most recent")

    t.expectEqual(RLS.defaultExpandedKeys(allKeys: [], now: date(2026, 8, 16), calendar: utc),
                  [], "no rides, nothing to expand")

    t.expectEqual(RLS.defaultExpandedKeys(allKeys: ["2026-06"], now: date(2026, 8, 16), calendar: utc),
                  ["2026-06"], "single old month still opens")

    // Only ever one month open by default.
    let picked = RLS.defaultExpandedKeys(allKeys: keys, now: date(2027, 1, 1), calendar: utc)
    t.expectEqual(picked.count, 1, "exactly one month expands by default")
}

// MARK: - Duration formatting

func testFormatDuration(_ t: TestRun) {
    // Characterization: matches the two implementations this replaces.
    t.expectEqual(RLS.formatDuration(0), "0m", "zero reads 0m")
    t.expectEqual(RLS.formatDuration(59), "0m", "under a minute rounds down")
    t.expectEqual(RLS.formatDuration(60), "1m", "one minute")
    t.expectEqual(RLS.formatDuration(3599), "59m", "just under an hour stays minutes")
    t.expectEqual(RLS.formatDuration(3600), "1h 0m", "exactly one hour")
    t.expectEqual(RLS.formatDuration(3660), "1h 1m", "an hour and a minute")
    t.expectEqual(RLS.formatDuration(7320), "2h 2m", "two hours two minutes")
    t.expectEqual(RLS.formatDuration(90000), "25h 0m", "past a day keeps counting hours")
    t.expectEqual(RLS.formatDuration(-5), "0m", "negative input degrades to 0m")
}

func runRideListTests(_ t: TestRun) {
    testMonthKeys(t)
    testMonthTitles(t)
    testDefaultExpansion(t)
    testFormatDuration(t)
}
