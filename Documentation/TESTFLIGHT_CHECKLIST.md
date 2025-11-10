# TestFlight Submission Checklist

## Pre-Upload Steps

### ✅ Completed
- [x] Renamed app to "Tailwind"
- [x] Updated bundle identifier to `com.rick.Tailwind`
- [x] Created Privacy Manifest (PrivacyInfo.xcprivacy)
- [x] Updated all privacy usage descriptions
- [x] Created Privacy Policy
- [x] Created App Description
- [x] Generated app icons (all sizes)

### 📋 To Do in Xcode

1. **Add Privacy Manifest to Project**
   - Open Xcode
   - Drag `PrivacyInfo.xcprivacy` into the project navigator
   - Ensure it's added to the Tailwind target

2. **Verify Build Settings**
   - Product Name: `Tailwind`
   - Bundle Identifier: `com.rick.Tailwind`
   - Display Name: `Tailwind`
   - Version: `1.0`
   - Build: `1`

3. **Archive the App**
   - Select "Any iOS Device" as destination
   - Product → Archive
   - Wait for archive to complete
   - Opens Organizer automatically

4. **Validate Archive**
   - Select your archive
   - Click "Validate App"
   - Select your Apple ID/Team
   - Choose "Automatically manage signing"
   - Click "Validate"
   - Fix any errors

5. **Upload to App Store Connect**
   - Click "Distribute App"
   - Select "App Store Connect"
   - Click "Upload"
   - Select your Apple ID/Team
   - Choose "Automatically manage signing"
   - Click "Upload"
   - Wait 5-15 minutes for processing

## App Store Connect Setup

### Create App Listing
1. Go to https://appstoreconnect.apple.com
2. Click "My Apps" → "+" → "New App"
3. Fill in:
   - **Platform**: iOS
   - **Name**: Tailwind
   - **Primary Language**: English (U.S.)
   - **Bundle ID**: com.rick.Tailwind
   - **SKU**: TAILWIND001
   - **User Access**: Full Access

### App Information
- **Name**: Tailwind
- **Subtitle**: Pro Cycling Computer & Tracker
- **Category**:
  - Primary: Health & Fitness
  - Secondary: Sports
- **Privacy Policy URL**: https://github.com/[your-username]/tailwind-cycling/blob/main/PRIVACY_POLICY.md

### Version Information
- **Version**: 1.0
- **Copyright**: 2025 Rick
- **Description**: (Copy from APP_STORE_DESCRIPTION.md)
- **Keywords**: cycling computer, bike tracker, ride metrics, segment timing
- **Support URL**: https://github.com/[your-username]/tailwind-cycling
- **Marketing URL**: (Optional, same as support URL)

### Screenshots (Required)
You'll need to take screenshots in Xcode Simulator:

#### iPhone 6.7" Display (Required)
- Ride tracking screen (landscape)
- Main metrics screen (portrait)
- Route map with trail
- Segment detection
- Bike maintenance screen

#### iPhone 6.5" Display (Required)
- Same as above

Take screenshots:
1. Run app in iPhone 15 Pro Max simulator
2. Navigate to each screen
3. Cmd+S to save screenshot
4. Screenshots saved to Desktop

### TestFlight Setup

1. **Internal Testing**
   - Add yourself as tester
   - Add your team members
   - Enable automatic distribution

2. **Test Information**
   - **What to Test**: Copy from APP_STORE_DESCRIPTION.md (TestFlight section)
   - **Feedback Email**: [your-email]
   - **Beta App Description**: (Optional)

3. **Export Compliance**
   - Does your app use encryption? **NO**
   - (Tailwind only uses standard iOS encryption, no custom crypto)

## After Upload

### Processing Time
- Wait 5-15 minutes for build to appear in App Store Connect
- Build will show under "Activity" tab first
- Then appears under TestFlight tab

### Add Build to TestFlight
1. Go to TestFlight tab
2. Click on "Internal Testing" group
3. Click "+" next to Builds
4. Select your uploaded build
5. Answer export compliance questions
6. Build goes into "Waiting for Review" status

### Internal Testing (Fast)
- Review usually 5-30 minutes for internal testing
- You and internal testers can install immediately after approval

### External Testing (Slower)
- Create external group if sharing outside your team
- Submit for Beta App Review
- Review takes 1-2 days typically
- Can distribute to up to 10,000 testers

## Troubleshooting

### Common Issues

**"Missing Privacy Manifest"**
- Ensure PrivacyInfo.xcprivacy is added to project
- Check it's included in app target

**"Missing Required Reasons API"**
- Privacy manifest declares UserDefaults usage (CA92.1)
- Privacy manifest declares FileTimestamp usage (C617.1)

**"Invalid Bundle Identifier"**
- Verify in Xcode: com.rick.Tailwind
- Must match App Store Connect listing

**"Missing Icon"**
- Run generate_app_icon.py
- Copy icons to Assets.xcassets/AppIcon.appiconset/
- Verify all sizes present

**"Processing for too long"**
- Normal! Can take 15-30 minutes
- Check Activity tab for status
- Refresh page occasionally

## Distribution

### TestFlight Invite Link
After approval, you'll get:
- Public link to share with testers
- Email invites
- Redemption codes

### Share with Team
Send TestFlight link via:
- Email
- Slack
- Team meeting

## Next Steps

After TestFlight is working:
1. Gather feedback from testers
2. Fix any bugs
3. Upload new builds as needed
4. Consider full App Store release

---

## Quick Commands

```bash
# Regenerate icons if needed
cd /Users/rick/projects/bike/DesertMetrics
source /tmp/icon_venv/bin/activate
python3 generate_app_icon.py

# Check for DesertMetrics references (should be none)
grep -r "DesertMetrics" --exclude-dir=.git --exclude="*.md" .

# Add privacy manifest to git
git add DesertMetrics/PrivacyInfo.xcprivacy
```

---

## Need Help?

- [App Store Connect Help](https://developer.apple.com/help/app-store-connect/)
- [TestFlight Documentation](https://developer.apple.com/testflight/)
- [Privacy Manifest Requirements](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files)
