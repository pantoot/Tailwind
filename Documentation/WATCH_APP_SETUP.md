# Apple Watch App Setup Guide

## What We Built

A companion Apple Watch app for Tailwind that shows:
- **Live metrics**: Speed, distance, duration, heart rate
- **Start/Stop controls**: Control ride from your wrist
- **Segment alerts**: See current segment and delta vs PR
- **Real-time sync**: Updates every second from iPhone

---

## Files Created

### Watch App Files (in `Tailwind Watch App/`)
1. **TailwindWatchApp.swift** - Main watch app entry point
2. **ContentView.swift** - Watch UI with metrics display
3. **WatchConnectivityManager.swift** - Handles iPhone ↔ Watch communication

### iPhone App Files (in `Tailwind/Services/`)
4. **PhoneConnectivityManager.swift** - Sends updates to watch

### Modified Files
5. **DesertMetricsApp.swift** - Added phone connectivity service
6. **MainView.swift** - Added watch update timer

---

## Adding Watch Target in Xcode

### Step 1: Create Watch App Target

1. **Open Xcode** with Tailwind.xcodeproj

2. **Add Watch App Target:**
   - File → New → Target
   - Select **"Watch App"** (under watchOS section)
   - Click "Next"

3. **Configure Target:**
   - Product Name: **"Tailwind Watch App"**
   - Organization Identifier: **com.rick**
   - Bundle Identifier: **com.rick.Tailwind.watchkitapp**
   - Interface: **SwiftUI**
   - Include Notification Scene: **Unchecked**
   - Click "Finish"

4. **Activate Scheme:**
   - Xcode will ask "Activate 'Tailwind Watch App' scheme?"
   - Click **"Activate"**

### Step 2: Add Watch App Files

1. **Delete the generated files:**
   - In Project Navigator, expand "Tailwind Watch App" folder
   - Delete `ContentView.swift` (select "Move to Trash")
   - Delete `TailwindWatchApp.swift` (select "Move to Trash")

2. **Add our watch app files:**
   - Drag `Tailwind Watch App/` folder from Finder into Xcode
   - Or right-click "Tailwind Watch App" → Add Files to "Tailwind Watch App"
   - Select all 3 files:
     - `TailwindWatchApp.swift`
     - `ContentView.swift`
     - `WatchConnectivityManager.swift`
   - **Important**: Check "Tailwind Watch App" in "Add to targets"
   - Click "Add"

### Step 3: Add PhoneConnectivityManager to iPhone Target

1. **Add to iPhone app:**
   - In Project Navigator, select "Tailwind" folder (iPhone app)
   - Right-click → Add Files to "Tailwind"
   - Navigate to `Tailwind/Services/`
   - Select `PhoneConnectivityManager.swift`
   - **Important**: Check "Tailwind" in "Add to targets" (NOT watch app)
   - Click "Add"

### Step 4: Enable WatchConnectivity Framework

**For Watch App:**
1. Select "Tailwind Watch App" target
2. Go to "Frameworks, Libraries, and Embedded Content"
3. Click "+" → Add "WatchConnectivity.framework"

**For iPhone App:**
1. Select "Tailwind" target (iPhone)
2. Go to "Frameworks, Libraries, and Embedded Content"
3. Click "+" → Add "WatchConnectivity.framework"

### Step 5: Build and Run

1. **Select Watch Simulator:**
   - At the top of Xcode, click the scheme selector
   - Choose "Tailwind Watch App"
   - Select "Apple Watch Series 9 (45mm)" or any watch simulator

2. **Build:**
   - Product → Build (Cmd+B)
   - Fix any errors (there shouldn't be any!)

3. **Run:**
   - Product → Run (Cmd+R)
   - Watch app will launch in simulator

4. **Test with iPhone:**
   - Open iPhone Simulator (will auto-open)
   - Run iPhone app (Tailwind) in iPhone simulator
   - Both should connect via WatchConnectivity
   - Start a ride on iPhone, see metrics update on watch!

---

## Testing the Watch App

### What You'll See on Watch

**Initial Screen:**
```
     18.5
     MPH

  12.3        00:42:15
  MILES         TIME

     ❤ 152
      BPM

   [  Start  ]
```

**During Segment:**
```
     22.3
     MPH

  15.8        01:12:45
  MILES         TIME

  🏁 Downtown Sprint
     -00:08
   (ahead of PR!)

   [  Stop   ]
```

### Testing Checklist

- [ ] Watch app launches without errors
- [ ] iPhone app connects to watch
- [ ] Metrics update in real-time (every second)
- [ ] Start button on watch controls iPhone app
- [ ] Stop button on watch controls iPhone app
- [ ] Segment info appears when segment starts
- [ ] Delta shows correctly (green when ahead, red when behind)
- [ ] Heart rate displays when available

---

## How It Works

### iPhone → Watch Communication

**Every second**, iPhone sends update via WCSession:
```swift
{
  "speed": 18.5,
  "distance": 12.3,
  "duration": 2535.0,
  "heartRate": 152,
  "isRecording": true,
  "segmentName": "Downtown Sprint",
  "segmentDelta": -8.0
}
```

Watch receives and updates UI immediately.

### Watch → iPhone Communication

**When you tap Start/Stop on watch:**
```swift
{
  "action": "startRide"  // or "stopRide"
}
```

iPhone receives and triggers ride start/stop.

### Connection Requirements

- Both devices must be paired (iOS Settings → Watch)
- WatchConnectivity framework handles background sync
- Works even when apps aren't in foreground
- Automatically reconnects when in range

---

## Troubleshooting

### "Watch not reachable"

**Problem**: iPhone logs "Watch not reachable"

**Solution**:
- Make sure both apps are running
- Check Watch app in iOS Watch app (Settings)
- Try restarting both simulators

### Watch app doesn't receive updates

**Problem**: Metrics stay at 0

**Solution**:
- Check iPhone logs for "📱 iPhone: WCSession activated"
- Check watch logs for "⌚ Watch: WCSession activated"
- Verify both apps have WatchConnectivity.framework
- Try sending test message from iPhone

### Build errors

**Problem**: "Cannot find 'WatchConnectivityManager' in scope"

**Solution**:
- Make sure `WatchConnectivityManager.swift` is in watch target
- Check target membership in File Inspector
- Clean build folder (Product → Clean Build Folder)

---

## Real Device Testing

### Requirements
- iPhone with iOS 16.0+
- Apple Watch with watchOS 9.0+
- Both paired together
- Both signed with same Apple Developer account

### Steps
1. Build iPhone app to your iPhone
2. Xcode will automatically install watch app to paired watch
3. Open Tailwind on iPhone
4. Open Tailwind on Apple Watch
5. Both will connect automatically!

---

## Future Enhancements

### Phase 2 (Easy additions)
- [ ] Complications for watch face
- [ ] Haptic feedback for segments
- [ ] Audio cue toggle button
- [ ] Customizable data screens

### Phase 3 (More complex)
- [ ] Independent GPS tracking on watch
- [ ] Workout session on watch
- [ ] Digital Crown to scroll metrics
- [ ] Force touch for settings menu

---

## Watch App Features Summary

### ✅ Implemented
- Live speed display (large, prominent)
- Distance tracking
- Duration timer
- Heart rate display (when available)
- Segment name and delta
- Start/Stop button
- Real-time sync with iPhone
- Automatic reconnection

### 🚧 Coming Soon
- Haptic alerts for segment start/end
- Complications
- Audio cue control
- Multiple data screen layouts

---

## Technical Details

### Watch App Architecture
```
TailwindWatchApp (main)
  └─ ContentView
      └─ WatchConnectivityManager (@EnvironmentObject)
          └─ Receives updates from iPhone
          └─ Sends commands to iPhone
```

### iPhone App Integration
```
AppServices
  └─ PhoneConnectivityManager
      └─ Sends updates every 1 second
      └─ Receives commands from watch
      └─ Wired to SensorDataService
```

### Data Flow
```
Sensors → SensorDataService → MainView → PhoneConnectivity → Watch
                                              ↓
                              Timer (1 Hz) ───┘
```

---

**Your Apple Watch companion is ready!** ⌚🚴

Once you add the watch target in Xcode, you'll have a fully functional companion app that makes it easy to glance at your metrics without looking at your handlebars.

Perfect for those moments when you just need to know "how fast am I going?" or "how far have I ridden?" with a quick wrist glance!
