# 🚴 Tailwind - Pro Cycling Computer

> Your complete cycling companion for every ride.

Tailwind is a powerful iOS bike computer app designed for serious cyclists. Track rides, race segments, monitor fitness, and manage bike maintenance - all in one beautiful app.

[![Download on TestFlight](https://img.shields.io/badge/TestFlight-Download-blue)](https://testflight.apple.com/join/[YOUR-CODE])
[![iOS](https://img.shields.io/badge/iOS-16.0+-black.svg)](https://www.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org/)

![Tailwind Screenshots](docs/screenshots.png)

## ✨ Features

### 🗺️ Ride Tracking
- Real-time speed, distance, and duration
- GPS route recording with gradient breadcrumb trails
- **Auto-pause** when stopped at lights
- Mile markers along your route
- **Speed heatmap** showing fast vs slow sections
- Elevation gain and altitude tracking

### 🏁 Performance Analytics
- **Segment detection** - race your PRs on known routes!
- Real-time performance comparison vs personal records
- **Route matching** - auto-detect repeated routes
- Heart rate zone tracking with time in zone
- Peak performance analysis (best 1min, 5min, 20min efforts)
- Performance trends over time
- **Training load tracking** (CTL, ATL, TSB)

### 📡 Sensor Support
- Bluetooth speed sensors
- Bluetooth cadence sensors
- Heart rate monitors
- **Battery level monitoring** for all sensors
- Multi-bike sensor management
- Auto-connect to bike-specific sensors

### 🔧 Bike Maintenance
- Track component mileage (chain, cassette, tires, brake pads)
- Maintenance reminders based on usage
- Multiple bike management
- Service history tracking

### 💪 Health Integration
- **HealthKit integration** to close your rings
- Automatic workout sync
- Heart rate data sharing
- Calorie tracking

### 🎨 Beautiful Design
- Landscape mode for handlebar mounting
- Portrait mode for quick checks
- Sunset gradient color scheme
- Dark mode optimized
- Clean, modern SwiftUI interface

## 📱 Requirements

- iOS 16.0 or later
- iPhone or iPad
- GPS capability
- (Optional) Bluetooth cycling sensors
- (Optional) Apple Watch for heart rate

## 🚀 Getting Started

### TestFlight Beta

1. **Join the beta**: [TestFlight Link](https://testflight.apple.com/join/[YOUR-CODE])
2. **Install** Tailwind on your iPhone
3. **Grant permissions** for Location and Bluetooth
4. **Pair your sensors** (optional but recommended)
5. **Start riding!**

### Building from Source

```bash
# Clone the repository
git clone https://github.com/[your-username]/tailwind-cycling.git
cd tailwind-cycling

# Open in Xcode
open DesertMetrics.xcodeproj

# Build and run
# Select your device/simulator and press Cmd+R
```

**Requirements for building:**
- Xcode 15.0+
- macOS 14.0+
- Apple Developer account (for device deployment)

## 📖 User Guide

### First Ride

1. **Setup your profile**
   - Tap your profile icon
   - Enter your weight and lactate threshold HR (optional)

2. **Add your bike**
   - Tap bike selector
   - Add your bike with name and type

3. **Pair sensors** (optional)
   - Tap settings (⋯)
   - Tap "Scan" to find sensors
   - Connect and assign to bike/profile

4. **Start riding**
   - Tap green "Start" button
   - Watch real-time metrics
   - Route is recorded automatically

### Creating Segments

1. Complete a ride with GPS tracking
2. Go to Settings → My Segments
3. Tap "Create from Saved Ride"
4. Select your ride and name the segment
5. Next time you ride that route, segments auto-detect!

### Maintenance Tracking

1. Go to Settings → Bike selector
2. Tap your bike → Maintenance
3. Add components with mileage intervals
4. Get reminded when service is due

## 🛠️ Technology Stack

- **Language**: Swift 5.9
- **UI Framework**: SwiftUI
- **Mapping**: MapKit
- **Charts**: Swift Charts
- **Sensors**: CoreBluetooth
- **Location**: CoreLocation
- **Health**: HealthKit
- **Storage**: UserDefaults (local only)

## 🔒 Privacy

Tailwind takes your privacy seriously:

- ✅ **All data stays on your device** - no cloud servers
- ✅ **No analytics** or tracking
- ✅ **No ads** or third-party SDKs
- ✅ **No account** required
- ✅ **Open source** - you can verify

See our [Privacy Policy](PRIVACY_POLICY.md) for full details.

## 🎯 Roadmap

- [ ] Live Activity / Lock Screen widget
- [ ] Customizable data screens
- [ ] GPX/TCX/FIT file export
- [ ] Strava auto-upload
- [ ] Turn-by-turn navigation
- [ ] Weather integration
- [ ] Apple Watch app
- [ ] Power meter support

See [FEATURE_IDEAS.md](FEATURE_IDEAS.md) for complete list.

## 🤝 Contributing

Contributions are welcome! Here's how:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Setup

```bash
# Generate app icons
cd /Users/rick/projects/bike/DesertMetrics
source /tmp/icon_venv/bin/activate
python3 generate_app_icon.py
```

## 📄 License

[Choose a license - MIT recommended]

## 🙏 Acknowledgments

- **Icons**: SF Symbols by Apple
- **Phoenix Design**: Inspired by desert sunsets
- **Inspiration**: Wahoo ELEMNT, Garmin Edge, Strava

## 📧 Contact

- **Issues**: [GitHub Issues](https://github.com/[your-username]/tailwind-cycling/issues)
- **Email**: [your-email]
- **TestFlight Feedback**: Use in-app feedback in TestFlight

## 📊 Stats

![GitHub stars](https://img.shields.io/github/stars/[your-username]/tailwind-cycling)
![GitHub forks](https://img.shields.io/github/forks/[your-username]/tailwind-cycling)
![GitHub issues](https://img.shields.io/github/issues/[your-username]/tailwind-cycling)

---

**Made with ❤️ for cyclists**

*Ride fast, ride safe, and always have a Tailwind.*
