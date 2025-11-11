# CLAUDE.md

This file provides guidance to Claude Code when working on the Tailwind cycling app.

## Project Overview

**Tailwind** is a native iOS cycling app with Apple Watch companion that tracks rides using Bluetooth sensors and GPS. Built with SwiftUI for iOS 18+ and watchOS.

**Repository**: https://github.com/pantoot/Tailwind.git
**Current Branch**: `feature/tab-based-architecture`
**Language**: Swift (SwiftUI)
**Platforms**: iOS 18+, watchOS

## Current Status (November 11, 2025)

### ✅ Completed Features

#### Core Ride Tracking
- Real-time speed, distance, time, heart rate, calories
- GPS route tracking with polyline visualization
- Elevation gain tracking
- Auto-pause when stopped (speed < 0.5 mph for 3 seconds)
- Background audio keeps app alive when phone locked
- Save rides to Apple Health (HealthKit integration)

#### Sensor Support
- Bluetooth sensor connectivity (speed, cadence, heart rate)
- **Apple Watch heart rate streaming** (fallback when no Bluetooth HR)
- **Priority system**: Bluetooth HR > Watch HR (5-second timeout)
- Per-bike sensor assignment (power meter on MTB, cadence on road bike)
- Profile sensors (heart rate follows user across bikes)
- Battery level monitoring for sensors

#### Apple Watch Companion
- **Remote control**: Start/Stop rides from watch
- Real-time metrics display (speed, distance, time, HR)
- Bi-directional sync via WatchConnectivity
- Heart rate streaming to iPhone via HealthKit
- Segment performance tracking on watch

#### Bike Management
- Multiple bike support with quick switcher
- Bike-specific maintenance schedules:
  - Intense 951 Gravel (31 items, Shimano GRX)
  - Pivot Trail 429 Enduro Pro X0 (21 items, SRAM X0, FOX)
  - Basic schedule for other bikes
- Auto-detect schedule based on bike name/type
- Track total miles per bike
- Maintenance due/approaching indicators

#### Analytics & Training
- Training Load Manager (CTL/ATL/TSB)
- HR-based Training Stress Score (hrTSS)
- Time in heart rate zones
- Performance trends over time
- Peak performance analysis
- Route history map (all GPS rides overlaid)

#### UI/UX
- Tab-based architecture: Ride / History / Settings
- Portrait mode: 4 metrics (HR, Calories, Distance, Time)
- Landscape mode: 2 layouts (simple/detailed) with swipe
- Speed heatmap overlay on route
- Mile markers on map
- Route/Segment detection with live performance comparison
- Dark theme optimized

### 🔧 Technical Architecture

#### App Structure
```
Tailwind/
├── Models/
│   ├── Bike.swift              # Bike & BikeStable (sensor assignment)
│   ├── MaintenanceItem.swift   # Maintenance schedules
│   ├── Ride.swift              # Ride data model
│   ├── SensorType.swift        # Bluetooth sensor types
│   ├── TrainingLoad.swift      # CTL/ATL/TSB calculations
│   └── UserProfile.swift       # User settings (LTHR, weight, age)
├── Services/
│   ├── BluetoothService.swift         # BLE sensor management
│   ├── SensorDataService.swift        # Data aggregation & calculations
│   ├── GPSService.swift               # Location tracking
│   ├── HealthKitService.swift         # Apple Health integration
│   ├── PhoneConnectivityManager.swift # iPhone ↔ Watch communication
│   ├── BackgroundAudioService.swift   # Keep app alive when locked
│   ├── RouteMatchingService.swift     # Detect known routes
│   ├── SegmentManager.swift           # Strava-like segments
│   └── AudioCueService.swift          # Voice announcements
├── Views/
│   ├── MainView.swift             # Main ride screen
│   ├── HistoryTabView.swift       # Ride history & analytics
│   ├── SettingsTabView.swift      # App settings
│   ├── BikeManagementView.swift   # Bike CRUD & maintenance
│   └── [other views...]
└── DesertMetricsApp.swift         # App entry point & service wiring

Tailwind Watch App Watch App/
├── TailwindWatchApp.swift           # Watch app entry
├── ContentView.swift                 # Watch UI
├── WatchConnectivityManager.swift    # Watch ↔ iPhone communication
└── WatchHealthKitService.swift       # HR streaming from watch
```

#### Data Flow

**Bluetooth Sensors → iPhone:**
```
BluetoothService (BLE)
  → SensorDataService (aggregation)
  → MainView (display)
```

**Apple Watch HR → iPhone:**
```
Watch HealthKit
  → WatchHealthKitService (stream)
  → WatchConnectivityManager (send)
  → PhoneConnectivityManager (receive)
  → SensorDataService.updateWatchHeartRate()
```

**iPhone → Apple Watch:**
```
SensorDataService (ride data)
  → MainView.sendWatchUpdate()
  → PhoneConnectivityManager
  → WatchConnectivityManager
  → Watch ContentView (display)
```

**Watch Remote Control:**
```
Watch: Tap Start/Stop
  → WatchConnectivityManager.sendStartRide()
  → PhoneConnectivityManager.watchRequestsStartRide (toggle)
  → MainView.onChange() observes
  → MainView.handleStartStop()
```

#### Service Wiring (AppServices)
All services initialized in `DesertMetricsApp.swift`:
- Bluetooth callbacks → SensorDataService
- GPS callbacks → RouteMatchingService & SegmentManager
- Bike selection → Auto-connect sensors
- Watch callbacks → Remote control triggers

### 📋 Known Issues & TODO

#### Configuration Needed (Manual Steps)
- [ ] **Watch App**: Add HealthKit capability in Xcode
  - Select "Tailwind Watch App Watch App" target
  - Signing & Capabilities → + Capability → HealthKit
  - Enable READ for Heart Rate
- [ ] **Watch App**: Add privacy description
  - Info tab → Add `Privacy - Health Share Usage Description`
  - Value: "Tailwind needs access to your heart rate data from Apple Watch to track your cycling performance when a Bluetooth heart rate monitor is not available."
- See `WATCH_HR_SETUP.md` for detailed instructions

#### Priority Bugs
- None currently identified

#### Future Enhancements
- Power meter support (watts, normalized power, TSS)
- FTP testing protocol
- Workout builder (intervals, custom workouts)
- Strava sync
- Garmin Connect IQ integration
- Indoor trainer support (Zwift, TrainerRoad)

### 🎯 Recent Work Session (Nov 11, 2025)

1. **Added bike selector to main ride view**
   - Tappable bike indicator in toolbar
   - Quick sheet to switch bikes without navigating to Settings

2. **Simplified portrait mode layout**
   - Removed elevation metrics (still tracked in background)
   - Single row: HR, Calories, Distance, Time
   - Increased bottom padding (100px) to clear tab bar

3. **Implemented Apple Watch HR streaming**
   - WatchHealthKitService queries live HR from watch
   - Sends to iPhone via WatchConnectivity
   - Priority logic: Bluetooth HR > Watch HR (5s timeout)
   - Fixed critical memory leak (limit=1, not unlimited)

4. **Added watch remote control**
   - Start/Stop rides from watch
   - Guard checks prevent duplicate starts/stops
   - Full bi-directional sync

5. **Security audit**
   - Verified no secrets/API keys in public GitHub repo
   - All sensitive data stored locally (UserDefaults, HealthKit)
   - No backend server, no authentication needed

## Development Guidelines

### Working with Xcode

**Opening Project:**
```bash
cd /Users/rick/projects/bike/Tailwind
open Tailwind.xcodeproj
```

**Configuring Targets:**
1. Click blue "Tailwind" icon at top of left sidebar (not a file!)
2. Select target from list (Tailwind, Tailwind Watch App Watch App)
3. Use tabs: General, Signing & Capabilities, Info, Build Settings

**Running on Device:**
- Select target (Tailwind or Watch App)
- Select device from dropdown
- Cmd+R to build and run

### Git Workflow

**Current Branch:** `feature/tab-based-architecture`

```bash
# Check status
git status
git log --oneline -10

# Make changes
git add -A
git commit -m "Descriptive message"
git push origin feature/tab-based-architecture

# Merge to main (when feature is complete)
git checkout main
git merge feature/tab-based-architecture
git push origin main
```

### Code Style

- Use SwiftUI declarative syntax
- Prefer `@EnvironmentObject` for shared services
- Use `.onChange()` for reactive updates
- Weak self in closures: `[weak self]` or `[weak service]`
- Published properties for UI-driven state
- Print statements with emoji prefixes for debugging:
  - `📱` iPhone
  - `⌚` Watch
  - `🔵` Bluetooth
  - `❤️` Heart rate
  - `🎬` Start
  - `🛑` Stop

### Adding New Bluetooth Sensor Type

1. Add to `SensorType` enum in `SensorType.swift`
2. Update `BluetoothService` to handle new UUID
3. Add callback in `AppServices.init()`
4. Add update method in `SensorDataService`
5. Update UI in `MainView` to display

### Adding New Maintenance Schedule

1. Add static function to `MaintenanceSchedule` in `MaintenanceItem.swift`
2. Update `BikeStable.loadMaintenanceSchedule()` with detection logic
3. Update `BikeEditView.getScheduleCount()` to return correct count

### Memory Management

- **Critical**: Limit HealthKit queries to recent data only
- Use `limit: 1` for anchored queries (not `HKObjectQueryNoLimit`)
- Reset anchors when stopping streams
- Weak references in closures to prevent retain cycles

## Testing

### Manual Testing Checklist

**Ride Recording:**
- [ ] Start ride → GPS starts, sensors connect
- [ ] Pause automatically at stoplights
- [ ] Resume when moving again
- [ ] Stop ride → saves to HealthKit
- [ ] Ride appears in History tab

**Watch Integration:**
- [ ] Watch displays live metrics during ride
- [ ] Watch can start ride (iPhone starts recording)
- [ ] Watch can stop ride (iPhone saves ride)
- [ ] Watch HR used when no Bluetooth HR

**Bike Switching:**
- [ ] Tap bike name in toolbar → sheet appears
- [ ] Select different bike → sensors reconnect
- [ ] Maintenance items load correctly per bike
- [ ] Miles tracked per bike

**Sensors:**
- [ ] Bluetooth HR connects and displays
- [ ] Watch HR appears when no Bluetooth
- [ ] Bluetooth HR takes priority when both active
- [ ] Battery levels shown for sensors

### Console Logs to Check

```
✅ Successfully loaded X bikes
🔧 Found bike at index X: [name]
❤️ Using Bluetooth HR: 145 bpm
❤️ Using Watch HR: 142 bpm
⌚ Ignoring watch HR - using Bluetooth HR (received 2s ago)
📱 iPhone: Received watch HR: 145 bpm
🎬 Starting ride from watch command
🛑 Stopping ride from watch command
```

## Documentation Files

- `WATCH_HR_SETUP.md` - Apple Watch HealthKit setup instructions
- `Documentation/WATCH_APP_SETUP.md` - Watch app overview
- `README.md` - Project overview for GitHub
- `.gitignore` - Standard Xcode ignores (working correctly)

## Environment

**User:** Rick
**Machine:** Rick's MacBook Pro (M-series)
**Xcode:** 26.1 (24454)
**iOS:** 26.1
**watchOS:** Latest
**Test Device:** iPhone 12,3 (iPhone 11 Pro?)

## Important Notes for Next Session

1. **Watch app needs manual Xcode configuration** - HealthKit capability and privacy string must be added in Xcode (can't be done via code)

2. **Branch strategy** - We're on `feature/tab-based-architecture`. When ready to release, merge to `main`.

3. **No secrets in repo** - All clear, safe for public GitHub

4. **Memory leak fixed** - Watch HR streaming was causing crashes, now limited to 1 sample with 10s window

5. **Portrait mode optimized** - Button placement fixed, elevation metrics removed from display (still tracked)

6. **Bike-specific maintenance working** - Auto-detects Intense 951 (gravel) and Pivot 429 (mountain) by name/type

7. **Watch remote control working** - Start/Stop from watch triggers iPhone ride recording

## Useful Commands

```bash
# Find files
find . -name "*.swift" -type f

# Search code
grep -r "functionName" --include="*.swift"

# Check git history
git log --oneline --graph --all

# View specific commit
git show <commit-hash>

# Check what's in repo
git ls-files

# Build from command line (if needed)
xcodebuild -scheme Tailwind -destination 'platform=iOS,name=iPhone'
```

## Contact & Support

- **GitHub Issues**: https://github.com/pantoot/Tailwind/issues
- **User**: Rick (@pantoot)
- **App Store**: Not yet published
- **Status**: Active development, personal project
