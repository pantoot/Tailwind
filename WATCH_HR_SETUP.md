# Apple Watch Heart Rate Integration - Setup Instructions

## Overview
The app now supports reading heart rate from Apple Watch as a fallback when no Bluetooth HR sensor is connected.

## Priority Logic
1. **Bluetooth HR Sensor** (highest priority) - if data received in last 5 seconds
2. **Apple Watch HR** (fallback) - used when no Bluetooth HR available

## Required Xcode Configuration

### 1. Add HealthKit Capability to Watch App
In Xcode:
1. Select the **Tailwind Watch App** target
2. Go to **Signing & Capabilities**
3. Click **+ Capability**
4. Add **HealthKit**
5. Check **Read** for "Heart Rate"

### 2. Add Privacy Description
In Xcode:
1. Select the **Tailwind Watch App** target
2. Go to the **Info** tab
3. Add a new key: `NSHealthShareUsageDescription`
4. Value: `Tailwind needs access to your heart rate data from Apple Watch to track your cycling performance when a Bluetooth heart rate monitor is not available.`

Alternatively, if using Info.plist file:
```xml
<key>NSHealthShareUsageDescription</key>
<string>Tailwind needs access to your heart rate data from Apple Watch to track your cycling performance when a Bluetooth heart rate monitor is not available.</string>
```

## How It Works

### Watch App (watchOS)
- `WatchHealthKitService.swift` - Streams real-time HR from HealthKit
- Starts streaming when ride begins
- Stops streaming when ride ends
- Sends HR data to iPhone via WatchConnectivity every time it updates

### iPhone App (iOS)
- `PhoneConnectivityManager.swift` - Receives watch HR data
- `SensorDataService.swift` - Implements priority logic:
  - `updateHeartRate()` - From Bluetooth sensor (sets lastBluetoothHRUpdate)
  - `updateWatchHeartRate()` - From Apple Watch (checks Bluetooth timeout first)
  - `applyHeartRate()` - Common method that applies HR to ride data

### Data Flow
```
Watch HealthKit HR
    ↓
WatchHealthKitService (streams live data)
    ↓
WatchConnectivityManager.sendHeartRate()
    ↓
PhoneConnectivityManager.watchHeartRate (published)
    ↓
AppServices.setupWatchHeartRate() (Combine sink)
    ↓
SensorDataService.updateWatchHeartRate()
    ↓
(checks if Bluetooth HR is active)
    ↓
applyHeartRate() - updates ride metrics
```

## Testing

### Without Bluetooth HR Sensor
1. Start a ride on iPhone
2. Watch app should request HealthKit permission (first time)
3. Watch will display HR from its sensor
4. iPhone should show same HR (with "Using Watch HR" in console)

### With Bluetooth HR Sensor
1. Connect Bluetooth HR chest strap/armband
2. Start a ride
3. Watch HR will be ignored (console shows "Ignoring watch HR - using Bluetooth HR")
4. iPhone uses Bluetooth HR exclusively

### Switching Between Sources
1. Start with Bluetooth HR connected
2. Turn off Bluetooth HR sensor
3. After 5 seconds, watch HR will take over automatically
4. Turn Bluetooth HR back on - will take priority again within 5 seconds

## Console Logs

Look for these messages:
- `⌚ Watch: HR from HealthKit: 145 bpm` - Watch reading HR
- `📱 iPhone: Received watch HR: 145 bpm` - iPhone receiving watch data
- `❤️ Using Watch HR: 145 bpm` - iPhone using watch HR
- `❤️ Using Bluetooth HR: 148 bpm` - iPhone using Bluetooth HR
- `⌚ Ignoring watch HR - using Bluetooth HR (received 2s ago)` - Bluetooth takes priority

## Troubleshooting

### Watch HR Not Showing
1. Check HealthKit permission in Watch Settings → Privacy → Health
2. Verify watch is worn snugly on wrist
3. Check Watch Connectivity status (green badge on main view)
4. Look for console errors starting with `⌚ Watch:`

### Both Sources Showing Same HR
- This is expected! Watch displays HR from iPhone during rides
- The displayed HR is what iPhone is using (could be Bluetooth or Watch source)
- Check console logs to see which source is actually being used

### Bluetooth HR Not Taking Priority
1. Verify Bluetooth sensor is actually connected (Settings → Sensors)
2. Check console for "Using Bluetooth HR" messages
3. Ensure sensor is sending data (watch for updates every few seconds)
