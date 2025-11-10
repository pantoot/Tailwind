# 🚴 Introducing Tailwind - Your New Cycling Computer

> **A powerful iOS bike computer that tracks rides, races segments, monitors fitness, and manages bike maintenance - all in one beautiful app.**

---

## 🎯 Why Tailwind?

We've built something special that combines the best features of Wahoo and Garmin bike computers with unique capabilities they don't offer:

### What Makes Us Different

**✅ Beyond the Competition:**
- **Training Load Tracking** - CTL, ATL, and TSB metrics that Wahoo/Garmin charge extra for
- **Bike Maintenance Management** - Track chain, cassette, tires, brake pads with mileage-based reminders
- **Segment Racing** - Create your own segments and race your PRs in real-time
- **Speed Heatmap** - Visual route analysis showing where you crushed it vs struggled
- **Auto-pause** - Automatically pauses at stoplights (no more manual starts/stops)
- **All Your Data Stays Local** - No cloud servers, no subscriptions, no data selling

**📱 Native iOS Experience:**
- Clean, modern SwiftUI interface optimized for iPhone
- HealthKit integration to close your activity rings
- Dark mode throughout
- Landscape mode for handlebar mounting
- Portrait mode for quick checks

---

## 🚀 Key Features Demo

### 1. Real-Time Ride Tracking

**Live Metrics Display:**
- Speed (current, average, max)
- Distance with mile markers
- Duration (auto-excludes paused time)
- Elevation gain
- Heart rate zones
- Cadence tracking

**The Map Experience:**
- GPS breadcrumb trail with gradient colors (green → cyan → blue)
- Start marker with cycling icon
- Mile markers every mile along your route
- Toggle between gradient trail and speed heatmap view

**Speed Heatmap:**
- Red: 0-8 mph (climbing/slow sections)
- Orange: 8-12 mph (moderate pace)
- Yellow: 12-15 mph (cruising)
- Green: 15-18 mph (pushing hard)
- Cyan: 18+ mph (flying!)

### 2. Segment Detection & PR Racing

**How It Works:**
1. Complete a ride with GPS tracking
2. Create a segment from your saved ride (name it, mark start/end points)
3. Next time you ride that route, the app auto-detects when you enter the segment
4. Real-time comparison shows if you're ahead or behind your PR
5. Visual indicator displays: segment name, elapsed time, delta vs best time
6. Auto-saves new PRs

**Example:**
```
🏁 Downtown Sprint
⏱️  00:03:42
🟢 -00:08 vs PR  (8 seconds faster!)
```

### 3. Training Load Monitoring

**Metrics Tracked:**
- **CTL (Chronic Training Load)** - Your fitness level
- **ATL (Acute Training Load)** - Your fatigue level
- **TSB (Training Stress Balance)** - Your form/readiness

**What You Get:**
- Performance trends over time
- Peak power analysis (best 1min, 5min, 20min efforts)
- Heart rate zone distribution
- Training load charts

### 4. Bike Maintenance Dashboard

**Never Miss Maintenance Again:**
- Track multiple bikes
- Add components with service intervals (chain every 2000 mi, etc.)
- Visual progress indicators showing time until service
- Service history tracking
- Maintenance reminders based on actual usage

**Components You Can Track:**
- Chain
- Cassette
- Tires
- Brake pads
- Cables
- Bar tape
- Anything else you want to track!

### 5. Sensor Support

**Bluetooth Connectivity:**
- Speed sensors (works with Garmin, Wahoo, any BLE sensor)
- Cadence sensors
- Heart rate monitors
- Battery level monitoring for all sensors
- Multi-bike sensor management (auto-connect to bike-specific sensors)

**ANT+ Support:**
If you have ANT+ sensors, use a hardware bridge like NPE CABLE ($50) or Viiiiva ($80) to convert ANT+ to Bluetooth - works seamlessly with the app.

### 6. Health & Fitness Integration

**HealthKit Sync:**
- Automatic workout uploads after each ride
- Closes your activity rings
- Heart rate data sharing
- Calorie tracking
- All health data stays private in your Apple Health app

---

## 🎨 Beautiful Design

**Optimized for Cycling:**
- **Landscape Mode** - Mount your iPhone on handlebars, get large metrics display
- **Portrait Mode** - Quick checks when you pull over
- **Sunset Gradient Theme** - Beautiful color scheme that's easy to read in any lighting
- **Auto-pause Indicator** - Clear orange "PAUSED" badge when stopped

**Smart UI:**
- Large, glanceable text for riding
- Route matching indicator when riding known routes
- Segment detection takes visual priority during active efforts
- Clean metric cards with SF Symbols icons

---

## 🔒 Privacy First

**Your Data, Your Device:**
- ✅ All data stored locally on your iPhone
- ✅ No cloud servers or external APIs
- ✅ No analytics, tracking, or ads
- ✅ No account required
- ✅ No subscriptions or in-app purchases
- ✅ You can delete everything by deleting the app

**What We Collect (Locally Only):**
- GPS coordinates for route tracking
- Heart rate and fitness data (synced to HealthKit if enabled)
- Sensor data (speed, cadence)
- Your preferences and bike configurations

**What We DON'T Collect:**
- No personal information
- No advertising identifiers
- No crash reports sent anywhere
- No sharing with third parties

---

## 🎯 Use Cases

### Road Cyclist
"I love racing my segments on my regular training loop. The auto-pause is clutch for city riding, and tracking my chain mileage means I never get caught with a worn chain again."

### Mountain Biker
"The speed heatmap shows me exactly where I'm losing time on technical sections. Plus the maintenance tracking for my dropper post and shock service is super helpful."

### Gravel Grinder
"Training load tracking helps me balance my long gravel rides without overtraining. The mile markers are great for pacing on 50+ mile rides."

### Commuter
"Even my daily commutes count toward bike maintenance tracking. Auto-pause works perfectly for stop-and-go traffic."

---

## 📱 Getting Started with TestFlight

### Installation Steps:

1. **Install TestFlight** (if you don't have it)
   - Download from App Store: [TestFlight](https://apps.apple.com/us/app/testflight/id899247664)

2. **Join the Beta**
   - Click the TestFlight link I'll send you
   - Accept the invitation
   - Install Tailwind

3. **First Launch Setup**
   - Grant Location permissions (required for GPS tracking)
   - Grant Bluetooth permissions (optional, for sensors)
   - Grant HealthKit permissions (optional, for workout sync)

4. **Optional: Add Your Bike**
   - Tap bike selector
   - Add your bike with name and type
   - Optionally add maintenance components

5. **Optional: Pair Sensors**
   - Tap settings (⋯)
   - Tap "Scan" to find sensors
   - Connect and assign to your bike

6. **Start Riding!**
   - Tap the green "Start" button
   - Your route is recorded automatically
   - Metrics update in real-time
   - Tap "Finish" when done

---

## 🎁 What's Coming Next

**Planned Features:**
- [ ] GPX/TCX/FIT file export
- [ ] Strava auto-upload integration
- [ ] Live Activity / Lock Screen widget
- [ ] Apple Watch companion app
- [ ] Turn-by-turn navigation
- [ ] Weather integration
- [ ] Customizable data screens
- [ ] Power meter support

---

## 💬 Feedback Wanted!

As beta testers, your feedback is invaluable. I want to know:

**What's Working:**
- Which features do you love?
- What makes you want to use this over your current bike computer?
- Any "wow" moments?

**What Needs Work:**
- Any bugs or crashes?
- Features that are confusing?
- Missing features you need?
- UI/UX improvements?

**How to Provide Feedback:**
- Use the TestFlight feedback button in the app
- Send me direct messages
- We can discuss in team meetings

---

## 🏆 Tech Stack

Built with modern iOS development:
- **Swift 5.9** - Apple's powerful, safe language
- **SwiftUI** - Declarative, modern UI framework
- **MapKit** - Native Apple maps
- **Swift Charts** - Beautiful data visualization
- **CoreBluetooth** - Sensor connectivity
- **CoreLocation** - GPS tracking
- **HealthKit** - Fitness data integration

---

## 🙏 Thank You!

This app represents months of development focused on creating the ultimate cycling companion. Every feature was built with real cyclists in mind - combining the best of professional bike computers with unique capabilities you won't find anywhere else.

I can't wait to hear what you think!

**Let's ride.** 🚴💨

---

## 📎 Quick Links

- **Privacy Policy**: [PRIVACY_POLICY.md](PRIVACY_POLICY.md)
- **App Store Description**: [APP_STORE_DESCRIPTION.md](APP_STORE_DESCRIPTION.md)
- **Full Documentation**: [README.md](README.md)
- **TestFlight Checklist**: [TESTFLIGHT_CHECKLIST.md](TESTFLIGHT_CHECKLIST.md)

---

*Tailwind - Made with ❤️ for cyclists*

*Ride fast, ride safe, and always have a Tailwind.*
