# Ad Hoc Distribution Guide

## Overview

Ad Hoc distribution lets you install Tailwind on up to 100 devices without paying for the Apple Developer Program. Perfect for sharing with your team to validate interest before investing $99/year.

---

## Step 1: Collect Device UDIDs

You need the UDID (Unique Device Identifier) from each iPhone that will install the app.

### How team members get their UDID:

**Option A: Using Finder (easiest)**
1. Connect iPhone to Mac via cable
2. Open **Finder**
3. Select the iPhone in the sidebar
4. Click on the device info under the iPhone name (where it shows capacity/serial number)
5. It will cycle through: Serial Number → UDID → Model Number
6. When **UDID** appears, right-click and **Copy**
7. Send it to you

**Option B: Using Xcode**
1. Connect iPhone to Mac
2. Open Xcode
3. Window → Devices and Simulators
4. Select the iPhone
5. Copy the **Identifier** field

**Option C: Using iPhone Settings (no computer)**
1. Install an app like **UDID Finder** from App Store
2. App will display the UDID
3. Copy and send to you

---

## Step 2: Register Devices in Xcode

Once you have UDIDs:

1. **Open Xcode**
2. **Go to:** Xcode → Settings → Accounts
3. **Select your Apple ID** (apple4@malooka.com)
4. **Select your Personal Team**
5. **Click "Manage Certificates..."** then close that window
6. **Go back** and click **"Download Manual Profiles"** (if available)

### Add devices to your developer account:

1. **Go to:** https://developer.apple.com/account
2. **Sign in** with your Apple ID
3. **Go to:** Certificates, Identifiers & Profiles → Devices
4. **Click "+"** to add a device
5. **Enter:**
   - Platform: iOS
   - Device Name: "Rick's iPhone" (or team member name)
   - Device ID (UDID): paste the UDID
6. **Click "Continue"** and **"Register"**
7. **Repeat** for each team member's device

---

## Step 3: Create Provisioning Profile

1. **Still in developer.apple.com**
2. **Go to:** Profiles → Click **"+"**
3. **Select:** iOS App Development (or Ad Hoc)
4. **Click "Continue"**
5. **Select your App ID:** com.rick.Tailwind
   - If it doesn't exist, create it first under Identifiers
6. **Select your certificate** (Apple Development)
7. **Select all the devices** you registered
8. **Name it:** "Tailwind Ad Hoc"
9. **Click "Generate"**
10. **Download** the .mobileprovision file

---

## Step 4: Archive for Ad Hoc Distribution

### In Xcode:

1. **Select scheme:** Tailwind → Any iOS Device (not simulator)
2. **Product → Archive**
3. **Wait** for archive to complete

### In Organizer (opens automatically):

1. **Select your archive**
2. **Click "Distribute App"**
3. **Select "Ad Hoc"**
4. **Click "Next"**

5. **Distribution options:**
   - App Thinning: None
   - Rebuild from Bitcode: Unchecked
   - Strip Swift symbols: Checked
   - **Click "Next"**

6. **Re-sign options:**
   - Automatically manage signing: **Checked**
   - **Click "Next"**

7. **Review and Export:**
   - **Click "Export"**
   - Choose a location (Desktop/Tailwind-AdHoc)
   - **Click "Export"**

---

## Step 5: Distribute to Team

You'll now have a folder with:
- `Tailwind.ipa` - The app file
- `manifest.plist` - Installation manifest

### Distribution Methods:

**Option A: AirDrop (Simplest)**
1. AirDrop the `Tailwind.ipa` file to team member's iPhone
2. On their iPhone, tap the .ipa file
3. May need to go to Settings → General → VPN & Device Management
4. Tap "CORJL SOFTWARE, LLC" or "Richard Perry"
5. Tap "Install"

**Option B: Email/Dropbox/Drive**
1. Upload `Tailwind.ipa` to shared location
2. Team member downloads on iPhone
3. Tap to install (may need to enable in Settings)

**Option C: Install via Cable (Most Reliable)**
1. Connect team member's iPhone to your Mac
2. Open **Finder**
3. Select the iPhone
4. Drag `Tailwind.ipa` to the iPhone window
5. App installs automatically

**Option D: Over-the-Air (OTA) Install (Advanced)**
You can host the .ipa and manifest.plist on a web server (HTTPS required):
1. Upload `Tailwind.ipa` and `manifest.plist` to web server
2. Create HTML page with install link:
   ```html
   <a href="itms-services://?action=download-manifest&url=https://yourserver.com/manifest.plist">
     Install Tailwind
   </a>
   ```
3. Team opens link in Safari on iPhone
4. Taps "Install"

---

## Troubleshooting

### "Untrusted Developer" Error

After installing, if the app won't open:
1. Go to **Settings → General → VPN & Device Management**
2. Tap on your developer profile
3. Tap **"Trust"**
4. Confirm

### "Unable to Install"

- Make sure the device UDID was registered correctly
- Provisioning profile must include that specific device
- Re-export with updated provisioning profile if you added new devices

### Certificate Expired

Free developer accounts have certificates that expire every 7 days:
- App will stop working after 7 days
- Need to re-export and reinstall
- **Paid developer account ($99/year) has 1-year certificates**

---

## Limitations of Ad Hoc (Free Account)

⚠️ **Important limitations:**
- ❌ **App expires every 7 days** - needs reinstall
- ❌ **Maximum 100 devices** per year
- ❌ **No TestFlight** - manual distribution only
- ❌ **No App Store** distribution
- ❌ **Must re-register devices** if they're removed

✅ **Benefits of paid account ($99/year):**
- ✅ Apps last 1 year (not 7 days)
- ✅ TestFlight for easy team distribution
- ✅ App Store publishing capability
- ✅ Advanced capabilities

---

## When to Upgrade to Paid Account

Consider paying $99/year when:
- You have 5+ team members testing regularly
- Tired of re-installing every 7 days
- Want to publish to App Store
- App shows real traction/interest

---

## Quick Reference: Team Instructions

**Send this to team members:**

> **Installing Tailwind (Ad Hoc)**
>
> 1. First, send me your iPhone UDID:
>    - Connect iPhone to Mac
>    - Open Finder → Select iPhone
>    - Click device info until "UDID" appears
>    - Copy and send to me
>
> 2. After I register your device, I'll send you `Tailwind.ipa`
>
> 3. Install:
>    - Open the .ipa file on your iPhone
>    - Tap "Install"
>    - Go to Settings → General → VPN & Device Management
>    - Trust the developer profile
>
> 4. App will work for 7 days, then needs reinstall

---

## Notes

- Ad Hoc is perfect for initial team testing
- If you get momentum, upgrade to paid account
- All team documentation (README.md, TEAM_DEMO.md) is ready to share
- Keep track of who you've registered (100 device limit)

---

**Good luck with the testing!** 🚴
