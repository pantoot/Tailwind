# TDD Evidence — Phase 2 "Rides consolidation"

**Source plan**: ECC orch-add-feature pipeline; planner task_list approved at Gate 1 (Aug 16 2026) with three user decisions: confirm deletion only when the ride has a GPS track, standardize rows on TSS + heart rate, and scope this cycle to tasks 1–7 (deferring the `RideDetailView` nested-navigation cleanup, which needs an on-device outdoor-ride test).

## User journeys

1. As a rider, I see one ride list — not two with different designs, one of them hidden behind a "See All" link.
2. As a rider importing from the share sheet, I can see that something happened; and if it failed, the message is still there when I look.
3. As a rider deleting an outdoor ride, I am warned before its GPS track is destroyed.

## Task report

| # | Task | Validation | Result |
|---|------|------------|--------|
| 1 | `RideListService` (month keys/titles/expansion/duration) — **tests written first** | `./scripts/run-tests.sh` | RED (`cannot find type 'RideListService'`) → GREEN, 167 assertions |
| 2 | Rebuilt list: `List`, collapsible months, totals header, identity-based swipe delete + GPS-aware confirmation | `xcodebuild` | BUILD SUCCEEDED |
| 3 | Import actions → toolbar ＋ menu | `xcodebuild` | BUILD SUCCEEDED |
| 4 | `ImportStatusCenter` + `ImportStatusBanner`, replacing ephemeral `@State` strings | `xcodebuild` | BUILD SUCCEEDED |
| 5 | Share-extension / URL imports post status | `xcodebuild` | BUILD SUCCEEDED |
| 6 | Fix Calories → Settings ▸ Data; Performance Trends → Rides list | `xcodebuild` | BUILD SUCCEEDED |
| 7 | `AppRouter`; "See All" switches tabs; `RideHistoryView` deleted | `xcodebuild` + `grep` | BUILD SUCCEEDED, no dangling references |

## What the passing tests guarantee

| # | Guarantee | Test |
|---|-----------|------|
| 1 | Month keys are zero-padded and year-first, so plain string ordering is chronological across a year boundary | `testMonthKeys` |
| 2 | Month titles render from `Calendar` components, not a locale-sensitive `DateFormatter` round-trip; malformed keys fall back to the key rather than a blank header | `testMonthTitles` |
| 3 | The current month expands by default; when this month has no rides, the most recent month with rides opens instead, so the list never appears empty | `testDefaultExpansion` |
| 4 | Exactly one month expands by default | `testDefaultExpansion` |
| 5 | Duration formatting matches the two implementations it replaces, including the 0s / 59s / exactly-1h / 25h edges, and degrades to "0m" on negative input | `testFormatDuration` |

## Review outcome

Swift reviewer verdict: **Warning** (1 HIGH, 2 MEDIUM, 2 LOW; no CRITICAL). Fixed before commit:

- **HIGH — a new import erased an unacknowledged failure.** `start()` overwrote `current` unconditionally, so a background share-extension failure vanished the moment the user tapped Apple Health — defeating the entire reason this class exists. Failures now live in a separate `failures` array that only explicit dismissal clears, rendered above the active job.
- **MEDIUM — a fresh import could land in a collapsed month.** Once the user collapses any section, `expandedMonths` freezes; the old screen force-expanded the current month regardless. Now an increase in ride count expands the newest ride's month, which preserves the ability to collapse it.
- **LOW — `AppRouter` (Models/) referenced `RidesTabView.Segment`.** The segment enum moved onto `AppRouter`; the view keeps a `typealias`.

Accepted and not fixed:
- **MEDIUM — a user-initiated Health import and a background pending-FIT sweep can still overlap.** Pre-existing; all mutations are MainActor-serialized so it is not a data race, and the failure-array fix means interleaving can no longer lose an error. Tracked for Phase 4.
- **LOW — the ＋ toolbar item appears/disappears on segment switch** rather than staying disabled. Deliberate: importing is a History action.

## Coverage and known gaps

- 167 harness assertions (140 prior + 27 new). Only Task 1 is harness-testable; Tasks 2–7 are view work with no automated coverage, verified by compile plus per-task device-checkable acceptance criteria.
- `ImportStatusCenter` is `@MainActor` UI-state plumbing and is not harness-covered; its id-comparison auto-clear and MainActor isolation were verified by review, not by test.
- Deferred: `RideDetailView`'s nested `NavigationView` and redundant "Done" button (Task 8) — it is the only reachable path to the ride map, so it wants an outdoor-ride device test.
- Capability audit vs. the deleted `RideHistoryView`: lifetime totals, Performance Trends, Fix Calories, collapsible months, and swipe delete all rehomed; `EditButton` multi-select delete and per-row calories/avg-speed dropped by explicit user decision.
