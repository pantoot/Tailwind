# TDD Evidence — Ride Classification

**Source plan**: ECC orch-add-feature pipeline; planner task_list approved at Gate 1 (Aug 16 2026) with two user decisions: zone-aligned %FTP intensity bands (not Coggan's ride-level IF table), and core scope = tasks 1–6 (badges and the cardiac-efficiency environment split deferred).

## User journeys

1. As a rider who mostly does steady endurance, my cruising 30-second power must not be plotted as if it were a sprint, so the burst-power trend means something.
2. As a rider importing a 3-hour Z2 ride, the summary must not tell me it was "Very Hard" just because the TSS total is large.
3. As a rider whose FTP is about to be retested, ride labels must re-derive themselves rather than persist a stale classification.

## Process deviation (disclosed)

For `RideClassificationService` the implementation was written **before** the tests, breaking strict RED-first order. Compensating control: **mutation testing** — nine mutations of the service's decision constants and precedence logic were applied one at a time, and the suite was re-run against each. All nine were killed, demonstrating the tests genuinely constrain the implementation (which is what a RED gate buys):

| Mutation | Result |
|---|---|
| recoveryCeiling 0.55 → 0.60 | killed |
| enduranceCeiling 0.76 → 0.80 | killed |
| tempoCeiling 0.90 → 0.95 | killed |
| thresholdCeiling 1.05 → 1.10 | killed |
| steadyCeiling 1.05 → 1.10 | killed |
| mixedCeiling 1.15 → 1.25 | killed |
| burstPowerRatio 1.5 → 1.2 | killed |
| matchesForIntervals 2 → 1 | killed |
| HR consulted before power (precedence swap) | killed |

The `getFourWeekTypicalWeekTSS` and Phase 1 work in this repo did follow RED-first; this is a one-off deviation, recorded so the next reader does not assume the whole suite was written test-first.

## Task report

| # | Task | Validation | Result |
|---|------|------------|--------|
| 1 | Harness wiring (Constants.swift + service into SOURCES; new test file into the runner) | `./scripts/run-tests.sh` | compiles; TestShims.swift unchanged, proving the primitives-only `Input` design |
| 2–3 | Intensity axis, structure axis, burst flag | `./scripts/run-tests.sh` | 119 assertions PASS |
| — | Mutation check (see above) | 9 × mutate + run | 9/9 killed |
| 4 | `Ride`/`UserProfile` adapter in a separate file | `xcodebuild … build` | BUILD SUCCEEDED |
| 5 | Power charts de-emphasize floor artifacts | `xcodebuild … build` | BUILD SUCCEEDED |
| 6 | Intensity-led import summary + legacy fallback | `./scripts/run-tests.sh` && `xcodebuild` | 140 assertions PASS + BUILD SUCCEEDED |

## What the passing tests guarantee

| # | Guarantee | Test |
|---|-----------|------|
| 1 | The real Aug 16 fixture ride (NP 192.2 / avg 187.8 / max30s 237.9 / 0 matches / FTP 250) classifies "Steady tempo", high confidence, VI ≈ 1.023 | `testFixtureRide` |
| 2 | **That ride's 237.9W 30s peak is NOT burst-representative** (ratio 1.27 < 1.5, no matches) | `testFixtureRide`, `testBurstRepresentative` |
| 3 | Zone-aligned IF bands at 0.55 / 0.76 / 0.90 / 1.05, tested from both sides of every boundary | `testIntensityBands` |
| 4 | NP beats average power; **power always beats HR**; HR-derived is always `.low` confidence with a non-nil cadence/heat caveat; HR never sets structure | `testIntensityDegradation` |
| 5 | FTP of 0 is treated as unset; no power and no HR yields "Unclassified"; rides under 15 min are unclassified and never burst-representative; exactly 15 min is classifiable | `testIntensityDegradation` |
| 6 | VI bands at 1.05 / 1.15; 2 matches escalate mixed→intervals; **matches never override a steady VI**; no NP means no VI, and matches become the only structure signal | `testStructureBands` |
| 7 | Burst flag: exactly 1.5× counts, 1.49× does not, one match qualifies regardless of ratio, missing/zero inputs never qualify | `testBurstRepresentative` |
| 8 | A 3-hour endurance ride at 150 TSS labels "Endurance" with easy tone and never says "very hard"; volume is still reported | `testSummaryCopy` |
| 9 | Gauge ring tracks IF when known (not TSS), so ring and word measure the same thing | `testSummaryCopy` |
| 10 | Unclassifiable rides reproduce the **exact** pre-existing TSS strings and tss/150 ring — characterization lock on the fallback | `testSummaryCopy` |

## Review outcome

Swift reviewer verdict: **Warning** (1 HIGH, 3 MEDIUM, 2 LOW; no CRITICAL). All findings fixed before commit.

- **HIGH — VI numerator and denominator came from different pipelines.** The adapter fed `ride.bestKnownAveragePower`, which prefers the FIT device's summary average (a plain mean over raw samples that skips auto-paused gaps), while `normalizedPower` and `max30sPower` both derive from the zero-filled dense 1Hz array. Dividing a stopped-time-inclusive numerator by a stopped-time-excluding denominator biases VI **low**, pushing punchy rides toward "steady"/"mixed" precisely at the 1.05/1.15 cutoffs. Fixed by sourcing average power from `creatineMetrics?.averagePower` first, falling back to `ride.averagePower` only when there are no metrics.
- MEDIUM — force-unwrap of `recentPowerRides.last!` replaced with a bound optional; `recentPowerRides` (which re-filters and re-sorts up to 1000 rides) now resolved once per card instead of ~6 times; `userProfile` doc comment corrected from "once for the whole screen" to "once per render".
- LOW — `matchesForIntervals` doc comment reworded to say the escalator applies within the mixed band only (a steady VI always wins, as the tests assert).

## Coverage and known gaps

- 140 harness assertions total (58 pre-existing + 82 new). No coverage tooling exists in this project.
- SwiftUI changes (chart point de-emphasis, summary card) are compile-verified only; on-device visual check pending.
- `RideClassificationService+Ride.swift` is not harness-testable by construction (it references `Ride`); it is a pure field mapping covered indirectly through the core. **This is where the HIGH review finding lived** — the field-source choice is exactly the kind of bug the harness cannot catch, so the reasoning is documented inline in the adapter.
- Deferred from this cycle by user decision: ride-row type badges, cardiac-efficiency indoor/outdoor split.
- Open risk carried forward: rides predating the Aug 15 2026 NP work have `normalizedPower == nil` and therefore `structure == .unknown`; a FIT-only ride whose power never reached Apple Health can never gain NP via reanalysis. Count not yet measured.
