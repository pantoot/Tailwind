# TDD Evidence — Phase 1 "Today-First" (TodayView rework)

**Source plan**: ECC orch-add-feature pipeline, planner task_list approved at Gate 1 (Aug 16 2026 session). Journeys derived from the Today-First redesign proposal.

## User journeys

1. As a self-coached cyclist, I open the app in the morning and see — without any taps — my form state, a target-TSS range for today, and a one-line reason, so I can decide what to ride in under 10 seconds.
2. As a rider whose CTL is ramping > 5/wk, I see the prescription capped downward and flagged red, so I back off before getting injured.
3. As a rider reading the form chart, I see which form zone each day fell in via shaded bands that use the same names/colors as the hero card.

## Task report

| # | Task | Validation | Result |
|---|------|------------|--------|
| 1 | swiftc harness + FormStatus characterization tests | `./scripts/run-tests.sh` | 11 assertions PASS (baseline locked) |
| 2 | FormStatus band-table refactor (single source of truth) | `./scripts/run-tests.sh` unchanged tests | 11 PASS — behavior preserved |
| 3 | TrainingDirectiveService contract tests | `./scripts/run-tests.sh` | RED — `cannot find type 'TrainingDirectiveService'` (compile-time RED, intended) |
| 4 | Implement TrainingDirectiveService | `./scripts/run-tests.sh` | 55 assertions PASS (GREEN) |
| 5 | Rename ImportView→TodayView, extract RideRow/FormChart, drop duplicate metric row | `xcodebuild … build` | BUILD SUCCEEDED |
| 6 | getFourWeekTypicalWeekTSS test | `./scripts/run-tests.sh` | RED — `no member 'getFourWeekTypicalWeekTSS'` |
| 6 | Implement getFourWeekTypicalWeekTSS | `./scripts/run-tests.sh` | 58 assertions PASS (GREEN) |
| 6–7 | Snapshot-once TodayView + DirectiveHeroCard + GlanceTileGrid | `xcodebuild … build` | BUILD SUCCEEDED |
| 8 | Form-zone bands on FormChart + explicit y-domain | `./scripts/run-tests.sh` && `xcodebuild` | 58 PASS + BUILD SUCCEEDED |

## What the passing tests guarantee

| # | Guarantee | Test | Type |
|---|-----------|------|------|
| 1 | FormStatus band boundaries unchanged by the table refactor (25/5/−10/−30, inclusive lower bounds) | `testFormStatusBands` | characterization |
| 2 | Target range per band = CTL × {fresh 1.2–1.8, rested 1.0–1.5, optimal 0.8–1.2, productive 0.5–0.9, overreaching 0–0.4} | `testTargetRangePerBand` | unit |
| 3 | Ramp > 5 caps both bounds via min (can only lower, never raise); exactly 5 does not cap; capped prescription says "back off" | `testRampCap` | unit |
| 4 | CTL < 10 → nil target range + history-building prescription, non-empty why | `testInsufficientHistory` | unit |
| 5 | Why sentence: empty rides / all-nil TSS fall back to CTL-only; today vs yesterday vs weekday phrasing; out-of-order input picks most recent scored ride; nil-TSS rides skipped | `testWhySentence` | unit |
| 6 | Range construction never produces lower > upper for small CTLs; prescription cites the range | `testRangeSanity` | unit |
| 7 | 4-week typical divides by fixed 4 weeks (no zero rows in dailyLoads), excludes >28-day-old entries, 0 for empty | `testFourWeekTypical` | unit |

## Coverage and known gaps

- No coverage tooling exists (no Xcode test target); the harness covers 100% of `TrainingDirectiveService` public behavior and the two touched `TrainingLoad` functions.
- SwiftUI views (TodayView, DirectiveHeroCard, GlanceTileGrid, FormChart bands) are verified by full `xcodebuild` compile + planned on-device check; Charts rendering is not unit-testable in this setup.
- `scripts/TestShims.swift` declares a minimal `Ride` (date, hrTSS) so the harness avoids the CoreLocation/CreatineMetrics dependency chain; if TrainingLoad.swift ever reads more of Ride, the harness fails to compile — the intended divergence signal.

## Merge evidence

Checkpoint commits were deferred to the pipeline's Gate 2 (single review point); the RED/GREEN sequence above is the preserved evidence.
