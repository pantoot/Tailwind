# Battery Monitoring for Bluetooth Sensors

## Overview
DesertMetrics now monitors battery levels for all connected Bluetooth sensors using the standard Battery Service (0x180F). This helps you know when it's time to replace or recharge sensor batteries.

## How It Works

### Bluetooth Battery Service
- **Service UUID**: `0x180F` (Battery Service)
- **Characteristic UUID**: `0x2A19` (Battery Level)
- **Format**: Single byte representing battery percentage (0-100)

### Automatic Battery Reading
When a sensor connects, DesertMetrics:
1. Discovers all services on the peripheral
2. Looks for the Battery Service (0x180F)
3. Reads the Battery Level characteristic (0x2A19)
4. Updates the UI with the battery percentage

### Battery Updates
- **Initial Read**: Performed immediately after connection
- **Updates**: Battery level is read once per connection
- **Storage**: Battery level stored in `BluetoothService.batteryLevels` dictionary

## UI Display

### Battery Indicators

#### Assigned Sensors
In Settings → Sensors → Assigned Sensors:
- Shows connection status: "✓ Connected"
- Shows battery icon and percentage (e.g., 🔋 85%)
- Icon changes based on battery level
- Color changes based on battery level

#### Discovered Sensors
During scanning:
- Battery level shown next to sensor type
- Only visible for connected sensors that support battery service
- Helps you identify sensors that need battery replacement before assignment

### Battery Icons
The app uses SF Symbols battery icons:
- `battery.100` - 76-100% (Green)
- `battery.75` - 51-75% (Green)
- `battery.50` - 26-50% (Green)
- `battery.25` - 11-25% (Orange - Warning!)
- `battery.0` - 0-10% (Red - Critical!)

### Color Coding
- **Green** (26-100%): Good battery level
- **Orange** (11-25%): Low battery, should replace soon
- **Red** (0-10%): Critical battery, replace immediately

## Supported Sensors

### Sensors with Battery Service
Most modern cycling sensors support the Battery Service:

✅ **Heart Rate Monitors**
- Polar H10, H9
- Garmin HRM-Pro, HRM-Dual
- Wahoo TICKR

✅ **Speed/Cadence Sensors**
- Wahoo Speed/Cadence sensors
- Garmin Speed/Cadence sensors
- Many generic Bluetooth sensors

✅ **Power Meters**
- Many power meters include battery service
- Check manufacturer documentation

### Sensors Without Battery Service
Some older or budget sensors may not broadcast battery levels. These will simply not show a battery indicator.

## Technical Implementation

### Data Model
```swift
struct SensorInfo: Identifiable {
    let id = UUID()
    let name: String
    let type: SensorType
    let rssi: Int
    var isConnected: Bool = false
    var batteryLevel: Int? = nil  // ← NEW: Battery percentage
}
```

### BluetoothService Updates

**Battery Level Storage:**
```swift
private var batteryLevels: [UUID: Int] = [:] // UUID -> Battery %
```

**Reading Battery:**
```swift
// In didDiscoverCharacteristics
if characteristic.uuid.uuidString == "2A19" && characteristic.properties.contains(.read) {
    peripheral.readValue(for: characteristic)
}
```

**Parsing Battery Data:**
```swift
private func parseBatteryLevel(data: Data, peripheral: CBPeripheral) {
    guard data.count >= 1 else { return }
    let batteryLevel = Int(data[0]) // 0-100%
    batteryLevels[peripheral.identifier] = batteryLevel
    // Update SensorInfo...
}
```

**Public API:**
```swift
func getBatteryLevel(for sensorType: SensorType) -> Int? {
    guard let sensorInfo = connectedSensors[sensorType] else { return nil }
    return batteryLevels[sensorInfo.id]
}
```

## Usage Examples

### Check Battery Before Ride
1. Open app → Settings (⋯ button)
2. Check "Assigned Sensors" section
3. Look for battery icons next to connected sensors
4. Replace batteries if showing orange or red

### Monitor During Scanning
1. Settings → Scan for sensors
2. Battery levels appear for already-connected sensors
3. Helps identify which sensors need fresh batteries
4. Connect to sensors with good battery levels

### Battery Alerts
Current implementation shows:
- Green: Good to ride
- Orange: Plan to replace soon (11-25%)
- Red: Replace before next ride (0-10%)

## Troubleshooting

### "No Battery Level Showing"
**Possible Causes:**
1. Sensor doesn't support Battery Service (older models)
2. Sensor not fully connected
3. Battery Service not yet discovered
4. Sensor firmware doesn't expose battery

**Solutions:**
- Disconnect and reconnect sensor
- Check sensor manufacturer documentation
- Update sensor firmware if available

### "Battery Level Not Updating"
**Behavior:**
- Battery level is read once per connection
- Doesn't continuously monitor (to save power)
- Reconnect sensor to get updated battery level

**To Refresh:**
1. Disconnect sensor (or restart app)
2. Reconnect sensor
3. New battery reading will be taken

## Future Enhancements

### Possible Improvements:
- [ ] Low battery notifications (when <20%)
- [ ] Battery history tracking
- [ ] Battery level trends over time
- [ ] Estimated time until replacement needed
- [ ] Battery change reminders
- [ ] Critical battery warnings before ride start

## Battery Service Specification

### Bluetooth SIG Standard
- **Service**: Battery Service (org.bluetooth.service.battery_service)
- **UUID**: 0x180F
- **Characteristics**:
  - Battery Level (0x2A19): uint8, 0-100 representing percentage
  - Battery Level State (optional): charging status, etc.

### Data Format
```
Byte 0: Battery Level (0-100)
  0 = 0% (battery completely discharged)
  100 = 100% (battery fully charged)
```

## Benefits

### For Riders:
- **Know before you go**: Check battery levels before starting ride
- **Avoid mid-ride failures**: Replace batteries proactively
- **Better planning**: Know when to buy replacement batteries
- **Peace of mind**: See all sensor statuses at a glance

### For Multi-Bike Setups:
- **Track all sensors**: See battery for sensors on each bike
- **Maintenance planning**: Replace batteries across fleet
- **Quick checks**: Verify all sensors ready before switching bikes

## Example Battery Management Workflow

### Weekly Check (Sunday):
```
1. Open DesertMetrics
2. Go to Settings
3. Check all assigned sensors
4. Note any orange/red batteries
5. Replace batteries as needed
6. Ready for the week!
```

### Pre-Ride Quick Check:
```
1. Open app
2. Main screen shows sensor connection
3. Check battery icons (if visible)
4. All green? Start riding!
5. Orange/Red? Replace battery first
```

---

## Summary

Battery monitoring provides:
- ✅ Real-time battery levels for connected sensors
- ✅ Visual indicators (icons + percentages)
- ✅ Color-coded warnings (green/orange/red)
- ✅ Works with all standard Bluetooth sensors
- ✅ Shown in both Assigned and Discovered sensor lists
- ✅ Automatic reading on connection
- ✅ No configuration required

Keep your sensors powered and never miss a ride due to dead batteries! 🔋🚴‍♂️
