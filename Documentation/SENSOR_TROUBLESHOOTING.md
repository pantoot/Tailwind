# Sensor Pairing Troubleshooting Guide

## What We Fixed

### 1. **Auto-Reconnect for Saved Sensors**
- Added `peripheralToTypeMap` to track which type each peripheral is
- When connecting via `connectToPeripheral(withId:type:)`, we now store the type mapping
- In `didConnect`, we check the type map and create SensorInfo for auto-reconnects

### 2. **Finding Already-Connected Sensors**
- iOS doesn't advertise already-connected BLE devices in scan results
- Added code to `startScanning()` to check for already-connected peripherals
- Uses `retrieveConnectedPeripherals(withServices:)` to find them
- This will find your heart rate monitor if it's still connected at the iOS level

### 3. **Reconnect Button**
- Added "Reconnect" button next to disconnected assigned sensors
- Allows you to manually reconnect a sensor using its saved peripheral ID

## How to Fix Your Heart Rate Sensor

### Option 1: Scan and Rediscover (Easiest)
1. Open the app and go to Settings (⋯ button)
2. Tap "Scan"
3. The heart rate monitor should appear in "Discovered Sensors" if:
   - It's still paired at iOS Bluetooth level, OR
   - It's advertising and in range
4. Tap "Connect" if needed
5. Tap "Assign" → "Assign to Profile"
6. Rename it if you want

### Option 2: Force Unpair and Re-pair
1. Go to iOS Settings → Bluetooth
2. Find your heart rate monitor in "My Devices"
3. Tap the (i) button → "Forget This Device"
4. Put heart rate monitor in pairing mode
5. Open DesertMetrics → Settings → Scan
6. Connect → Assign to Profile

### Option 3: Use Reconnect Button (If Already Assigned)
1. If the heart rate sensor shows in "Assigned Sensors" but is disconnected
2. Tap the "Reconnect" button next to it
3. It should reconnect using the saved peripheral ID

## Debug Checklist

If scanning still doesn't work:

- [ ] Check iOS Settings → DesertMetrics → Bluetooth is enabled
- [ ] Check iOS Settings → Privacy & Security → Bluetooth → DesertMetrics is enabled
- [ ] Check heart rate monitor has fresh battery
- [ ] Check heart rate monitor is in pairing mode (usually flashing LED)
- [ ] Check iOS Settings → Bluetooth - is HRM listed there?
- [ ] Try "Forget This Device" in iOS Bluetooth settings, then re-pair

## What Changed in the Refactor

**Before:**
- All sensors were stored in a flat list
- No distinction between profile vs bike-specific sensors
- Manual sensor switching required

**After:**
- Profile sensors (heart rate) stored separately in `BikeStable.profileSensors`
- Bike sensors stored per-bike in `Bike.assignedSensors`
- Auto-connect/disconnect when switching bikes
- Custom sensor naming

## Technical Details

### Sensor Storage Locations

**Profile Sensors (UserDefaults):**
```swift
// Heart rate monitor stored here
BikeStable.profileSensors: [String: SavedSensor]
```

**Bike-Specific Sensors (bikes.json):**
```swift
// Speed, cadence, power stored per bike
Bike.assignedSensors: [String: SavedSensor]
```

### Bluetooth Connection Flow

1. **Scanning:**
   - Check for already-connected peripherals via `retrieveConnectedPeripherals()`
   - Scan for advertising peripherals via `scanForPeripherals()`
   - Add both to `discoveredSensors` list

2. **Connection:**
   - User taps "Connect" on discovered sensor
   - Store type mapping: `peripheralToTypeMap[peripheral.id] = sensorType`
   - Connect via `centralManager.connect()`
   - On success, add to `connectedSensors`

3. **Assignment:**
   - User taps "Assign" on connected sensor
   - Choose "Profile" or current bike name
   - Create `SavedSensor` with peripheral UUID
   - Save to appropriate location

4. **Auto-Reconnect:**
   - On app launch or bike change
   - Call `connectToPeripheral(withId: savedSensor.id, type: sensorType)`
   - Uses `retrievePeripherals(withIdentifiers:)` to find known peripheral
   - Connects without scanning

## Expected Behavior

### When App Launches:
1. Auto-connect profile sensors (heart rate)
2. Auto-connect current bike's sensors

### When Switching Bikes:
1. Disconnect previous bike's sensors
2. Keep profile sensors connected
3. Connect new bike's sensors

### When Scanning:
1. Show all discovered sensors
2. Show already-connected sensors
3. Show connection status
4. Allow assignment of connected sensors
