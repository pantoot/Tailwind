# Tailwind FIT Import Setup Guide

This guide walks through setting up Tailwind as a FIT file import app for syncing Magene rides to Apple Health.

## Quick Start (5 minutes)

### Step 1: Add FitFileParser Package

1. Open `Tailwind.xcodeproj` in Xcode
2. File → Add Package Dependencies
3. Enter: `https://github.com/roznet/FitFileParser`
4. Click "Add Package"
5. Select the **Tailwind** target → Add Package

### Step 2: Add Share Extension Target

1. File → New → Target
2. Choose "Share Extension"
3. Product Name: `TailwindShareExtension`
4. Click Finish
5. When prompted about activating the scheme, click "Activate"

### Step 3: Configure Share Extension

Replace the auto-generated files with the ones we created:

1. Delete the auto-generated `ShareViewController.swift` in the extension folder
2. Drag these files into the TailwindShareExtension group:
   - `TailwindShareExtension/ShareViewController.swift`
   - `TailwindShareExtension/Info.plist`
   - `TailwindShareExtension/TailwindShareExtension.entitlements`

### Step 4: Configure App Groups

**For main Tailwind target:**
1. Select Tailwind target → Signing & Capabilities
2. Click "+ Capability" → App Groups
3. Add: `group.com.tailwind.app`

**For TailwindShareExtension target:**
1. Select TailwindShareExtension target → Signing & Capabilities
2. Click "+ Capability" → App Groups
3. Add: `group.com.tailwind.app` (same group)

### Step 5: Add URL Scheme (for Share Extension callback)

1. Select Tailwind target → Info tab
2. Expand "URL Types"
3. Click "+" to add a new URL type
4. Set:
   - Identifier: `com.tailwind.app`
   - URL Schemes: `tailwind`

### Step 6: Build & Run

1. Select "Tailwind" scheme
2. Build and run on your iPhone
3. The app should show the new import UI

---

## Testing the Flow

### Test 1: Manual File Import

1. Open Tailwind app
2. Tap "Import FIT File"
3. Navigate to a FIT file (if you have one in Files)
4. Confirm import success

### Test 2: Share from Magene

1. Open Magene app
2. Go to a completed ride
3. Tap Share → Choose "FIT File" or similar
4. Select "Import to Tailwind" from share sheet
5. Tailwind opens and imports the ride
6. Check Apple Health → Workouts to verify

---

## What Gets Imported

| Data | Source | Apple Health |
|------|--------|--------------|
| Heart Rate | FIT records (per-second) | Full HR samples |
| Distance | FIT session | Cycling Distance |
| Duration | FIT session | Workout duration |
| Calories | FIT session | Active Energy |
| GPS Route | FIT records | Workout Route |
| Elevation | FIT records | Elevation Gained |
| Cadence | FIT records | Metadata |
| Power | FIT records | Metadata |

**Key difference from Strava:** We import the actual second-by-second heart rate data, not just averages!

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                     Magene App                          │
│                   (Record ride)                         │
└────────────────────────┬────────────────────────────────┘
                         │ Share FIT file
                         ▼
┌─────────────────────────────────────────────────────────┐
│              TailwindShareExtension                     │
│         (Receives file, saves to App Group)             │
└────────────────────────┬────────────────────────────────┘
                         │ Opens Tailwind via URL
                         ▼
┌─────────────────────────────────────────────────────────┐
│                   Tailwind App                          │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │              FITImportService                    │   │
│  │   • Parses FIT file (FitFileParser)             │   │
│  │   • Extracts HR, GPS, distance, etc.            │   │
│  └──────────────────────┬──────────────────────────┘   │
│                         │                               │
│  ┌──────────────────────▼──────────────────────────┐   │
│  │              HealthKitService                    │   │
│  │   • Creates HKWorkout                           │   │
│  │   • Adds all HR samples                         │   │
│  │   • Adds distance, calories                     │   │
│  │   • Adds GPS route                              │   │
│  └──────────────────────┬──────────────────────────┘   │
│                         │                               │
│  ┌──────────────────────▼──────────────────────────┐   │
│  │               RideHistory                        │   │
│  │   • Stores ride locally                         │   │
│  │   • Shows in history view                       │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│                   Apple Health                          │
│   • Workout with full HR curve                         │
│   • All data available to other apps                   │
└─────────────────────────────────────────────────────────┘
```

---

## Troubleshooting

### Share Extension doesn't appear
- Make sure you built with the Tailwind scheme (not just the extension)
- Check that both targets have the same App Group
- Restart the phone if needed

### "File not found" error
- The FIT file might not have proper permissions
- Try using the file picker instead of share

### No heart rate in Apple Health
- Check that the FIT file actually contains HR data
- Some computers don't record HR if no sensor connected

### Import succeeds but workout not in Health
- Check HealthKit authorization in Settings → Health → Apps → Tailwind
- Make sure all permissions are granted

---

## Files Changed in This Pivot

### New Files
- `Services/FITImportService.swift` - FIT parsing and import logic
- `Views/ImportView.swift` - New main UI
- `TailwindShareExtension/` - Share extension target

### Modified Files
- `DesertMetricsApp.swift` - Simplified to import-focused app
- `Tailwind.entitlements` - Added App Group

### Preserved (but unused)
- All original ride-tracking views and services are still in the project
- Can re-enable hybrid mode later if desired

---

## Future Enhancements

- [ ] Auto-import from Magene cloud (if API available)
- [ ] Background import via shortcuts
- [ ] Batch import multiple FIT files
- [ ] Widget showing last ride stats
- [ ] Watch app as import status viewer
