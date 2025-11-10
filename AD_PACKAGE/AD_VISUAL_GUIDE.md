# Tailwind - Visual Reference Guide for Ad Production

## Quick Visual Summary

### The 3-Panel Story
```
┌─────────────────────────────────────────────────┐
│  PANEL 1: THE PROBLEM (0-5s)                    │
│  ┌─────────────────────┐                        │
│  │  Cyclist looking at │   "Garmin Edge: $500"  │
│  │  expensive Garmin   │   "Wahoo: $400"        │
│  │  in bike shop       │   "Just for tracking?" │
│  └─────────────────────┘                        │
├─────────────────────────────────────────────────┤
│  PANEL 2: THE SOLUTION (5-12s)                  │
│  ┌─────────────────────┐                        │
│  │  iPhone on bars     │   "Tailwind does it    │
│  │  showing Tailwind   │    all - on your       │
│  │  with live metrics  │    iPhone"             │
│  └─────────────────────┘                        │
│  Feature montage: GPS • Segments • Training     │
│                   Auto-pause • Maintenance      │
├─────────────────────────────────────────────────┤
│  PANEL 3: THE CALL (12-15s)                     │
│  ┌─────────────────────┐                        │
│  │   TAILWIND LOGO     │   "Join the beta"      │
│  │   App Store icon    │   [QR Code]            │
│  │                     │   "Free on TestFlight" │
│  └─────────────────────┘                        │
└─────────────────────────────────────────────────┘
```

---

## Color Palette (Provide to Designer)

### Primary Colors
```
Sunset Orange:  #FF6B35  ████████
Twilight Purple: #6B4E9C  ████████
Deep Black:     #000000  ████████
Pure White:     #FFFFFF  ████████
```

### Speed Heatmap Colors
```
Slow Red:       #FF5252  ████████  (0-8 mph)
Medium Orange:  #FF9800  ████████  (8-12 mph)
Warm Yellow:    #FFC107  ████████  (12-15 mph)
Fast Green:     #4CAF50  ████████  (15-18 mph)
Very Fast Cyan: #00BCD4  ████████  (18+ mph)
```

### Usage
- **Backgrounds**: Black (#000000)
- **Text**: White (#FFFFFF)
- **Accents**: Sunset gradient (Orange → Purple)
- **Map trails**: Gradient (Green → Cyan → Blue)
- **Highlights**: Cyan (#00BCD4)

---

## Typography

### Primary Font
**SF Pro Display** (Apple's system font)
- Available free from Apple
- Download: https://developer.apple.com/fonts/

### Weights to Use
- **Bold** (700) - Headlines, numbers
- **Semibold** (600) - Feature labels
- **Regular** (400) - Body text

### Text Hierarchy
```
HEADLINE:        SF Pro Display Bold, 48pt
"TAILWIND"       All caps, letter-spacing: 5%

SUBHEADLINE:     SF Pro Display Semibold, 32pt
"Your Complete Cycling Companion"

FEATURE TEXT:    SF Pro Display Semibold, 24pt
"RACE YOUR SEGMENTS"

BODY TEXT:       SF Pro Display Regular, 18pt
"Available on TestFlight"
```

---

## Key Screenshots (To Record and Provide)

### Screenshot 1: Main Ride Screen (Landscape)
**What to Show:**
```
┌────────────────────────────────────────────────────┐
│ [Bike Icon] Road Bike    [GPS Signal] [Battery]   │
├────────────────────────────────────────────────────┤
│                                                    │
│  ┌─────────────┐  ┌─────────────┐  ┌────────────┐│
│  │   18.5      │  │   12.3      │  │  00:42:15  ││
│  │   MPH       │  │   MILES     │  │  DURATION  ││
│  └─────────────┘  └─────────────┘  └────────────┘│
│                                                    │
│  ┌────────────────────────────────────────────┐  │
│  │         [MAP WITH GRADIENT TRAIL]          │  │
│  │  • Start marker (green with bike icon)     │  │
│  │  • Mile markers (1, 2, 3...)               │  │
│  │  • Current location (blue dot)             │  │
│  │  • Trail: Green→Cyan→Blue gradient         │  │
│  └────────────────────────────────────────────┘  │
│                                                    │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐           │
│  │  152    │  │   85    │  │  1,250  │           │
│  │  BPM    │  │  RPM    │  │  ELEV   │           │
│  └─────────┘  └─────────┘  └─────────┘           │
└────────────────────────────────────────────────────┘
```

**Recording Instructions:**
1. Start a test ride
2. Let it run for ~5 minutes to get some distance
3. Switch to landscape mode
4. Screen record for 30 seconds while "riding"
5. Show smooth scrolling/updates

---

### Screenshot 2: Segment Detection
**What to Show:**
```
┌────────────────────────────────────────┐
│  [MAP in background with trail]       │
│                                        │
│     ┌───────────────────────────┐     │
│     │  🏁 Downtown Sprint        │     │
│     │                            │     │
│     │      00:03:42              │     │
│     │   (Yellow, large)          │     │
│     │                            │     │
│     │   ▼ -00:08 vs PR           │     │
│     │   (Green, with down arrow) │     │
│     └───────────────────────────┘     │
│         (Purple badge/card)           │
└────────────────────────────────────────┘
```

**Recording Instructions:**
1. Create a test segment
2. Start ride and approach segment start point
3. Screen record when segment activates
4. Show the popup appear and time counting
5. Capture 10-15 seconds

---

### Screenshot 3: Speed Heatmap View
**What to Show:**
```
┌─────────────────────────────────────────┐
│  [Toggle: ◉ HEATMAP  ○ GRADIENT]       │
├─────────────────────────────────────────┤
│  ┌────────────────────────────────┐    │
│  │  [MAP with color-coded route]  │    │
│  │                                 │    │
│  │  Red section (climbing)         │    │
│  │  Orange section (moderate)      │    │
│  │  Yellow section (cruising)      │    │
│  │  Green section (fast flat)      │    │
│  │  Cyan section (descending)      │    │
│  │                                 │    │
│  │  Mile markers: 1, 2, 3, 4       │    │
│  └────────────────────────────────┘    │
│                                         │
│  Legend:                                │
│  🔴 0-8 mph  🟠 8-12  🟡 12-15         │
│  🟢 15-18    🔵 18+                    │
└─────────────────────────────────────────┘
```

---

### Screenshot 4: Training Load Dashboard
**What to Show:**
```
┌────────────────────────────────────────┐
│  Training Load                         │
├────────────────────────────────────────┤
│                                        │
│  CTL (Fitness): 65  ──────────▲       │
│  ATL (Fatigue): 72  ──────────────▲   │
│  TSB (Form):   -7   ────────▼         │
│                                        │
│  ┌────────────────────────────────┐  │
│  │   [30-day chart showing]       │  │
│  │   - Blue line (CTL trending up)│  │
│  │   - Red line (ATL fluctuating) │  │
│  │   - Green area (TSB zone)      │  │
│  └────────────────────────────────┘  │
│                                        │
│  Form: Optimal for racing             │
│  Recommendation: Maintain current load │
└────────────────────────────────────────┘
```

---

### Screenshot 5: Bike Maintenance
**What to Show:**
```
┌────────────────────────────────────────┐
│  Road Bike - Maintenance               │
├────────────────────────────────────────┤
│                                        │
│  ⛓️  Chain                            │
│  ▓▓▓▓▓▓▓▓▓░  1,800 / 2,000 mi       │
│  Replace in 200 mi                     │
│                                        │
│  🎡 Cassette                          │
│  ▓▓▓▓░░░░░░  1,200 / 3,000 mi       │
│  Good condition                        │
│                                        │
│  🛞 Tires                             │
│  ▓▓▓░░░░░░░    500 / 2,500 mi       │
│  Good condition                        │
│                                        │
│  🔴 Brake Pads                        │
│  ▓▓▓▓▓▓▓▓▓▓  2,100 / 2,000 mi  ⚠️   │
│  REPLACE SOON!                         │
│                                        │
│  [+ Add Component]                     │
└────────────────────────────────────────┘
```

---

## Motion Graphics Elements

### Text Animation Style
```
ENTER:  Fade in + slide up (0.3s)
        Ease: easeOutCubic

HOLD:   Static (1-2s)

EXIT:   Fade out (0.2s)
        Ease: easeInCubic
```

### Screen Transitions
```
TYPE 1: Quick Cut
        Duration: Instant
        Use: Between different scenes

TYPE 2: Swipe/Slide
        Duration: 0.4s
        Direction: Left to right
        Use: Between app screens

TYPE 3: Fade
        Duration: 0.5s
        Use: Into/out of title cards
```

### UI Element Animations
```
Segment Popup:
  - Scales from 0.8 to 1.0
  - Fades from 0% to 100%
  - Duration: 0.4s
  - Bounce effect on arrival

Mile Marker Appearance:
  - Pops in with scale 0.5 to 1.2 to 1.0
  - Duration: 0.3s

Progress Bars:
  - Fill from 0 to target value
  - Duration: 1.0s
  - Ease: easeOutQuad
```

---

## Sample Frame Compositions

### Frame 1: Hero Shot (Opening)
```
COMPOSITION:
┌────────────────────────────────────────┐
│         [THIRDS GRID OVERLAY]          │
│  ┌──────────┬──────────┬──────────┐  │
│  │          │          │          │  │
│  │          │ Cyclist  │          │  │
│  │          │ center   │          │  │
│  ├──────────┼──────────┼──────────┤  │
│  │          │ iPhone   │          │  │
│  │ Sunset   │   on     │ Road     │  │
│  │ (left)   │  bars    │ (right)  │  │
│  ├──────────┼──────────┼──────────┤  │
│  │ TAILWIND │          │          │  │
│  │  (logo)  │          │          │  │
│  └──────────┴──────────┴──────────┘  │
└────────────────────────────────────────┘

Camera: Drone, low angle
Time: Golden hour (sunset)
Focus: iPhone screen (sharp), background (slight blur)
```

### Frame 2: App Interface Focus
```
COMPOSITION:
┌────────────────────────────────────────┐
│  [Center-weighted composition]        │
│                                        │
│         ┌──────────────┐              │
│         │              │              │
│         │   iPhone     │              │
│         │   showing    │              │
│         │   Tailwind   │              │
│         │   app        │              │
│         │              │              │
│         └──────────────┘              │
│                                        │
│  Text overlay (lower third):          │
│  "REAL-TIME GPS TRACKING"             │
└────────────────────────────────────────┘

Camera: Static, straight-on
Background: Subtle blur of cycling environment
Focus: App screen (100% sharp)
```

---

## Audio Guide

### Music Tempo Map
```
0:00-0:02   Intro (build-up)         ▁▂▃▄
0:02-0:08   Main section (energetic) ▅▆▆▅▆▆
0:08-0:12   Bridge (maintain)        ▅▅▅▅▅
0:12-0:15   Outro (resolve)          ▄▃▂▁
```

### Voiceover Script (Professional Read)
```
[0s]   "Meet Tailwind."
       (Confident, friendly)

[3s]   "Your complete cycling computer."
       (Informative, clear)

[6s]   "Track rides, race segments, monitor fitness."
       (Faster pace, energetic)

[9s]   "Everything a Garmin does,"
       (Building emphasis)

[11s]  "plus bike maintenance tracking."
       (Emphasis on "plus")

[13s]  "Tailwind. Your ride, elevated."
       (Slower, memorable, tagline delivery)
```

### Sound Effects Cues
```
0:02 - Subtle "whoosh" (app screen appears)
0:05 - Notification "ding" (segment activates)
0:08 - Soft "beep" (GPS tracking sound)
0:12 - Success "chime" (feature complete)
```

---

## Filming Guidelines

### Camera Settings
```
Resolution:  4K (3840x2160) minimum
Frame Rate:  60fps (for slow-motion capability)
Shutter:     1/120 (natural motion blur)
ISO:         Auto (daylight) / 400-800 (low light)
White Bal:   5500K (daylight) / Auto
Format:      LOG profile if available (for color grading)
```

### Shot List Priority

**MUST HAVE:**
1. iPhone mounted on handlebars (app visible)
2. Cyclist riding on scenic road
3. Close-up of app screen showing metrics
4. Wide shot of cyclist at sunset/sunrise

**NICE TO HAVE:**
5. Drone follow shot
6. Segment detection popup moment
7. Maintenance screen with progress bars
8. Group ride (social proof)

**CAN USE STOCK:**
9. Generic cycling B-roll
10. Urban cycling scenes
11. Bike maintenance close-ups

---

## Platform-Specific Adaptations

### Instagram/TikTok (Vertical 9:16)
```
┌──────────┐
│   Logo   │  Top: Branding
├──────────┤
│          │
│          │
│  Main    │  Center: Main content
│  Content │  (cyclist, app, features)
│          │
│          │
├──────────┤
│   Text   │  Bottom: Call-to-action
│   CTA    │  "Join Beta" + QR code
└──────────┘
```

### YouTube Pre-Roll (Horizontal 16:9)
```
┌────────────────────────────────────┐
│  Logo (corner)                     │
│  ┌──────────────────────────────┐ │
│  │                              │ │
│  │      Main Content            │ │
│  │      (full screen)           │ │
│  │                              │ │
│  └──────────────────────────────┘ │
│  Text CTA (lower third)           │
└────────────────────────────────────┘
```

### Twitter/X (Square 1:1)
```
┌─────────────────┐
│  Logo (top)     │
├─────────────────┤
│                 │
│  Main Content   │
│  (square crop)  │
│                 │
├─────────────────┤
│  CTA (bottom)   │
└─────────────────┘
```

---

## Competitor Reference (For Comparison Shots)

### If Showing Comparison
```
SPLIT SCREEN LAYOUT:

┌──────────────────┬──────────────────┐
│  Garmin Edge 530 │    Tailwind      │
├──────────────────┼──────────────────┤
│                  │                  │
│  [Product photo] │  [iPhone + app]  │
│                  │                  │
│  $499.99         │  Free (Beta)     │
│                  │                  │
│  ✓ GPS tracking  │  ✓ GPS tracking  │
│  ✓ Segments      │  ✓ Segments      │
│  ✓ Training      │  ✓ Training      │
│  ✗ Maintenance   │  ✓ Maintenance   │
│                  │                  │
└──────────────────┴──────────────────┘

NOTE: Keep comparison factual, no disparaging remarks
```

---

## End Card Variations

### Option A: Simple Logo
```
┌────────────────────────────────┐
│                                │
│       ┌──────────────┐         │
│       │  TAILWIND    │         │
│       │    LOGO      │         │
│       └──────────────┘         │
│                                │
│  Your Complete Cycling         │
│       Companion                │
│                                │
│  [TestFlight QR Code]          │
│                                │
│  tailwind.app                  │
└────────────────────────────────┘
```

### Option B: App Store Showcase
```
┌────────────────────────────────┐
│  ┌──────┐                      │
│  │ Icon │  TAILWIND             │
│  │      │  Pro Cycling Computer │
│  └──────┘                      │
│                                │
│  ★★★★★ 4.9 (128 reviews)      │
│                                │
│  [Download on TestFlight]      │
│  [     Button Image      ]     │
│                                │
│  tailwind.app                  │
└────────────────────────────────┘
```

### Option C: Feature Grid
```
┌────────────────────────────────┐
│         TAILWIND               │
│                                │
│  ✓ GPS Tracking                │
│  ✓ Segment Racing              │
│  ✓ Training Load               │
│  ✓ Maintenance Tracking        │
│                                │
│  Download on TestFlight        │
│  [QR Code]  tailwind.app       │
└────────────────────────────────┘
```

---

## Quick Start Checklist for Agency

- [ ] Read AD_CREATIVE_BRIEF.md (full details)
- [ ] Review this visual guide
- [ ] Download SF Pro Display font
- [ ] Note color palette (hex codes above)
- [ ] Review screenshot mockups
- [ ] Understand motion graphics style
- [ ] Check platform specs for deliverables
- [ ] Review voiceover script
- [ ] Confirm music licensing approach
- [ ] Plan shot list from filming guidelines
- [ ] Prepare questions for kickoff call

---

## File Naming Convention

Please deliver files as:
```
Tailwind_15s_v1_Instagram_Vertical_1080x1920.mp4
Tailwind_15s_v1_YouTube_Horizontal_1920x1080.mp4
Tailwind_15s_v1_Twitter_Square_1080x1080.mp4

Tailwind_15s_v2_[platform]_[orientation]_[resolution].mp4

Tailwind_15s_FINAL_[platform]_[orientation]_[resolution].mp4
```

---

**Ready to create an amazing ad for Tailwind!** 🚴

This guide gives your ad agency all the visual reference they need alongside the creative brief. They should have everything to produce a compelling 15-second ad that showcases Tailwind's unique features.
