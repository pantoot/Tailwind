# CLAUDE.md

This file provides guidance to Claude Code when working on the Tailwind cycling app.

## Project Overview

**Tailwind** is a native iOS cycling app that imports FIT files from Magene cycling computers and syncs cycling workouts from Apple Health (Peloton, Zwift, etc.) into a training analytics dashboard. Built with SwiftUI for iOS 18+.

**Repository**: https://github.com/pantoot/Tailwind.git
**Current Branch**: `fit-import-pivot`
**Language**: Swift (SwiftUI)
**Platforms**: iOS 18+
**Version**: 1.2

## Current Status (February 2026)

The app pivoted from live ride tracking to FIT file import + Apple Health sync. Legacy ride-tracking code (Bluetooth sensors, GPS, Watch companion) is preserved but commented out in `DesertMetricsApp.swift`.

### App Architecture

**Three-tab layout:**
1. **Today** (`TodayView`) — Directive hero (form state, TSB, target-TSS prescription with ramp-rate override, "why" sentence via `TrainingDirectiveService`), 2×2 glance tiles (CTL + trend, ATL, 7-day TSS vs 4-week typical, last ride), form chart with shaded form-zone bands, 3 recent rides
2. **Rides** (`RidesTabView`) — One ride list: lifetime totals header, collapsible month sections, swipe-to-delete (confirms when the ride has a GPS track, since deleting prunes the track file). Import lives in a toolbar ＋ menu (FIT / Apple Health / Manual / Reimport). Power analytics segment (`PowerAnalyticsContent`). Persistent `ImportStatusBanner` above the segment switch.
3. **Settings** (`SettingsTabView`) — Profile, training zones, data maintenance, diagnostics

### Core Features

#### FIT File Import
- Import via file picker, share extension (`TailwindShareExtension`), or direct file open
- Share extension uses App Group (`group.com.rick.Tailwind`) to queue files
- URL scheme: `tailwind://import?file=<path>`
- Parses 1Hz record data: power, HR, speed, cadence, elevation, distance
- Registered UTI: `com.garmin.fit` (FIT Activity File)

#### Apple Health Integration
- Import cycling workouts from HealthKit (Peloton, Zwift, Apple Watch rides)
- Reads: workouts, routes, heartRate, activeEnergyBurned, distanceCycling, cyclingPower, cyclingFunctionalThresholdPower
- Writes: cycling workouts with HR samples, distance, calories, routes
- Duplicate detection via time overlap analysis

#### Training Load Dashboard
- **CTL** (Chronic Training Load / Fitness) — 42-day exponential average
- **ATL** (Acute Training Load / Fatigue) — 7-day exponential average
- **TSB** (Training Stress Balance / Form) — CTL minus ATL
- **Ramp Rate Warning** — Red/green indicator when weekly CTL change > 5 (injury risk)
- Form chart (30-day CTL/ATL/TSB history)
- Weekly TSS summary

#### Creatine Focus Analytics
Analyzes raw 1Hz power/HR/speed data to track metrics affected by creatine supplementation:

- **Matches Burned** — Hard anaerobic efforts above Zone 6 threshold (120% FTP). Bar chart per ride.
- **Max 30s Power** — Best 30-second rolling average power per ride. Line chart trend.
- **W/kg Delta** — Max 30s power divided by body weight. Requires weight log entries.
- **HR Recovery** — Detects high HR → power drop → 60s measurement. Classifies coasting vs stopped.

Filtering: Rides < 20 minutes excluded (cool downs/warm ups).
Match threshold: Zone 6 floor (120% FTP) when FTP is set, otherwise manual watts setting.

#### Power Analysis Pipeline
```
FIT File (1Hz records) ──► CreatineAnalysisService.analyze()
                                │
                           buildDenseArray() — interpolate sparse samples to 1s grid
                           smooth3s() — centered 3-second moving average
                           detectMatches() — contiguous periods above threshold >5s
                           maxRollingAverage() — sliding 30s window maximum
                           detectHRRecovery() — HR spike + power drop + 60s measurement
                           AerobicDecouplingService.decoupling() — Pw:HR drift, first vs second half
                                │
                           ──► CreatineMetrics struct (stored on Ride model)
```

#### LTHR Estimation
- Scans last 90 days of cycling workouts from HealthKit
- Finds best 20-minute rolling average HR using timestamp-based sliding window
- Applies 2% discount for non-test field conditions
- Deduplicates workouts by start time (HealthKit returns same ride from multiple sources)
- Shows top 5 candidates with option to apply estimated LTHR

#### Max HR Estimation
- Scans last 2 years of cycling workouts, two-phase: cheap per-workout `HKStatisticsQuery` raw-max ranking, then full sample fetch for only the top 25
- `MaxHREstimationService` (pure, tested): rolling median-of-5 kills 1–2 sample sensor spikes, then best time-weighted 15s sustained window = credible max
- Continuity check kills *sustained* artifacts (chest-strap doubling to 2× real HR, optical cadence-lock): a sample is credible only within 30 bpm of the workout median or of a credible sample in the trailing minute — real HR climbs through the values below a peak; a non-credible block can't legitimize its own tail. Rejected blocks are surfaced per candidate, not silently dropped
- LTHR-derived plausibility ceiling (LTHR × 1.20): catches doubling that persists long enough to inflate the workout median and defeat the continuity check. Implausible candidates are listed separately ("likely 2× of N"), never in the headline
- Workouts deduplicated by time-range overlap (≥50% of the shorter), not start time — the same ride recorded by Peloton + a head unit starts minutes apart
- Candidates show source app/device and flag spiky data when raw max exceeds sustained by > 8 bpm
- Settings > Training Zones > "Estimate Max HR from Data"; apply writes the profile Max HR field (`MaxHRResultView`)

#### User Profile
- Birthday, weight, gender
- LTHR (Lactate Threshold HR) — required for TSS/zone calculations
- Max HR (optional, estimated from age if not set)
- FTP (Functional Threshold Power) — used for power zone calculations and match threshold
- Weight log for tracking W/kg over time

### File Structure
```
Tailwind/
├── Models/
│   ├── Ride.swift                # Ride data model (includes creatineMetrics)
│   ├── CreatineMetrics.swift     # PowerMatch, HRRecoveryEvent structs
│   ├── CreatineSettings.swift    # Match threshold, creatine start date, CreatineSettingsManager
│   ├── WeightLog.swift           # WeightEntry, WeightLogManager
│   ├── TrainingLoad.swift        # CTL/ATL/TSB, DailyTrainingLoad, ramp rate
│   ├── UserProfile.swift         # User settings (LTHR, FTP, weight, age)
│   ├── SensorType.swift          # Bluetooth sensor types (legacy)
│   └── Bike.swift                # Bike & BikeStable (legacy)
├── Services/
│   ├── FITImportService.swift         # FIT file parsing (FitFileParser), 1Hz capture
│   ├── HealthKitService.swift         # Apple Health read/write, LTHR estimation, FTP fetch
│   ├── CreatineAnalysisService.swift  # Power analysis algorithms (static methods)
│   ├── TrainingDirectiveService.swift # Today's prescription from form/ramp (pure, tested)
│   ├── RideClassificationService.swift # Intensity/structure axes + burst flag (pure, tested)
│   ├── RideListService.swift          # Month grouping/expansion/duration (pure, tested)
│   ├── MaxHREstimationService.swift   # Spike-filtered sustained max HR (pure, tested)
│   ├── AerobicDecouplingService.swift # Friel Pw:HR decoupling, first vs second half EF (pure, tested)
│   ├── PowerMath.swift                # Normalized power + shared power arithmetic (pure)
│   ├── ImportStatusCenter.swift       # App-level import job status
│   └── [legacy services...]           # Bluetooth, GPS, Audio, etc. (unused)
├── Views/
│   ├── TodayView.swift            # Today tab (snapshot-once dashboard)
│   ├── Today/
│   │   ├── DirectiveHeroCard.swift # Form state + prescription + why
│   │   └── GlanceTileGrid.swift   # 2×2 at-a-glance tiles
│   ├── FormChart.swift            # CTL/ATL/TSB chart with form-zone bands
│   ├── RideRow.swift              # Shared ride list row (Today + Rides tabs)
│   ├── ImportStatusBanner.swift   # Durable import job status
│   ├── CalorieRepairSection.swift # Fix-calories tool (Settings > Data)
│   ├── CreatineFocusView.swift    # 4-widget power analytics + WeightQuickEntry
│   ├── ImportSummaryView.swift    # Post-import summary with power highlights
│   ├── RideDetailView.swift       # Individual ride detail + creatine metrics section
│   ├── WeightLogView.swift        # Weight entry form + history
│   ├── RidesTabView.swift         # Rides tab: one list + ＋ import menu + Power segment
│   └── SettingsTabView.swift      # Profile, zones, data maintenance, diagnostics
├── DesertMetricsApp.swift         # App entry, TabView, AppServices, URL/share handling
├── Info.plist                     # URL scheme, FIT UTI, document types
└── Tailwind.entitlements          # App Group, HealthKit

TailwindShareExtension/
├── ShareViewController.swift      # Receives FIT files via share sheet
├── Info.plist                     # Extension activation rules
└── TailwindShareExtension.entitlements
```

### Service Container (AppServices)
```swift
class AppServices: ObservableObject {
    let rideHistory: RideHistory
    let healthKitService: HealthKitService
    let fitImportService: FITImportService
    let trainingLoadManager: TrainingLoadManager
    let weightLogManager: WeightLogManager
    let creatineSettingsManager: CreatineSettingsManager
    let importStatusCenter: ImportStatusCenter
}
```

Navigation state lives in `AppRouter` (`Models/AppRouter.swift`): named tab enum plus the Rides segment, so any screen can hand the user to the full ride list via `router.showAllRides()`.

All injected as `@EnvironmentObject` into views.

### Data Persistence
- **Rides**: UserDefaults (JSON-encoded `[Ride]`)
- **Training loads**: UserDefaults key `"DailyTrainingLoads"`
- **User profile**: UserDefaults key `"UserProfile"`
- **Creatine settings**: UserDefaults key `"CreatineSettings"`
- **Weight log**: UserDefaults key `"WeightLogEntries"`
- **Share extension pending imports**: App Group UserDefaults key `"pendingFITImports"`

### Dependencies
- **FitFileParser** — Swift package for parsing Garmin FIT files
- **SwiftUI Charts** — Native charting framework (BarMark, LineMark, PointMark, RuleMark, AreaMark)

## Development Guidelines

### Testing
- No Xcode test target. Pure logic (TrainingDirectiveService, TrainingLoad bands/typical-load, AerobicDecouplingService, MaxHREstimationService, RideClassificationService, RideListService) is tested via `./scripts/run-tests.sh` — a standalone `swiftc` harness that compiles the model + service layer for macOS and runs assertions. Add new pure-logic tests to `scripts/TrainingDirectiveTests.swift`.

### Xcode Project
- Uses **PBXFileSystemSynchronizedRootGroup** — new Swift files are auto-detected by Xcode, no need to edit project.pbxproj
- SourceKit single-file analysis shows false "Cannot find type" errors — these resolve when building the full project

### Code Style
- SwiftUI declarative syntax
- `@EnvironmentObject` for shared services
- `@State` / `@Published` for UI state
- Print statements with emoji prefixes: `📱` app, `⚡` power, `📊` metrics, `📥` import, `✅` success, `❌` error, `⚠️` warning
- Codable structs with UserDefaults persistence pattern (static `load()` + instance `save()`)

### HealthKit Patterns
- **Critical**: Cap sample queries (10,800 max) to prevent OOM kills
- Use `limit: 1` for existence checks (`hasPowerData`)
- Two-phase approach: cheap existence check first, then full fetch only for confirmed data
- 100ms pause between batch operations to let memory settle
- Deduplicate HealthKit workouts by start time (multiple sources write same workout)

### Known Harmless Warnings
- `CFPrefsPlistSource` / `kCFPreferencesAnyUser` — App Group UserDefaults at launch, mitigated with lazy property
- `Failed to create 1125x0 image slot` — iOS rendering engine, zero-height chart during layout
- `RBSServiceErrorDomain Code=1 'Client not entitled'` — RunningBoard system noise
- `UIViewAlertForUnsatisfiableConstraints` — iOS keyboard auto-layout internal conflict

### Git
- **Current branch**: `fit-import-pivot`
- **Main branch**: `main`
- **Push auth issue**: `rick12341` doesn't have push access to `pantoot/Tailwind` — needs `gh auth login` or SSH remote URL fix

## Testing Checklist

**FIT Import:**
- [ ] Import FIT file via file picker → ride appears with metrics
- [ ] Import FIT with power meter → creatineMetrics populated
- [ ] Import FIT without power → creatineMetrics is nil
- [ ] Share extension queues file → app processes on foreground

**Apple Health Import:**
- [ ] Import last 30/60/90 days → workouts with HR/power imported
- [ ] Duplicate detection skips already-imported rides
- [ ] Peloton rides include power data in creatine analysis

**Creatine Focus Tab:**
- [ ] Rides < 20 min filtered out
- [ ] Match threshold uses Zone 6 (120% FTP) when FTP is set
- [ ] Charts show creatine start date annotation
- [ ] Weight quick-entry works for W/kg calculation

**Settings:**
- [ ] Save profile persists LTHR, FTP, weight
- [ ] LTHR estimation returns deduplicated results
- [ ] FTP fetch from Apple Health (may return nil if source app doesn't write it)
- [ ] Reanalyze Power Data backfills creatine metrics from HealthKit
- [ ] Ramp rate warning shows on dashboard when CTL delta > 5/week

## User Context

**User:** Rick, age 51
**Bikes:** Magene cycling computer (outdoor), Peloton (indoor)
**LTHR:** ~152-153 bpm (validated by estimator)
**FTP:** ~250W (to be confirmed from Peloton settings)
**Power profile:** ~200W average on 2-hour rides, ~250W peak
**Creatine supplementation:** Tracking effects on burst power and recovery
