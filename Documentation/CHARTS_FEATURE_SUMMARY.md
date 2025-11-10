# mPaceline-Inspired Charts & Analytics

## Overview
Integrated comprehensive charts and analytics inspired by mPaceline's powerful visualization features. These charts provide deep insights into your cycling performance, trends, and peak efforts.

## New Chart Views

### 1. **Ride Detail Charts** (`RideDetailChartView.swift`)
Individual ride analysis with interactive charts showing:

**Features:**
- **Segmented Metric Selector**: Switch between Heart Rate, Speed, Cadence, Elevation
- **Interactive Line Charts**: Smooth curves with area fill showing metric progression over time
- **X-Axis**: Time-based (minutes:seconds format)
- **Color-coded Metrics**:
  - Heart Rate: Red
  - Speed: Blue
  - Cadence: Green
  - Elevation: Orange

**Statistics Grid:**
- Average HR / Max HR
- Average Speed / Max Speed
- Average Cadence / Max Cadence (if available)
- Beautiful stat cards with color-coded icons

**Access:** Ride History → Select Ride → "View Detailed Charts"

---

### 2. **Performance Trends** (`PerformanceTrendsView.swift`)
Track your progress over time with multiple views:

**Time Range Selector:**
- Week (7 days)
- Month (30 days)
- 3 Months (90 days)
- Year (365 days)

**Summary Cards:**
- Total Distance
- Total Rides
- Total Time
- Average Speed

**Trend Chart:**
- Bar chart showing selected metric over time
- Metric dropdown: Distance, Avg Speed, Calories, Ride Time, Avg Heart Rate
- Dashed trend line showing overall improvement direction
- Color-coded by metric type

**Week-over-Week Comparison:**
- Last 4 weeks comparison
- Distance totals per week
- Value annotations on bars

**Access:** Ride History → "Performance Trends"

---

### 3. **Peak Performance** (`PeakPerformanceView.swift`)
Analyze your best efforts and efficiency:

**Duration Selector Pills:**
- 30 seconds
- 1 minute
- 5 minutes
- 10 minutes
- 20 minutes
- 30 minutes

**Best Effort Card:**
- Largest display of best average speed for selected duration
- Date achieved
- Average heart rate
- Average cadence
- Distance covered

**Peak Speed Curve:**
- Bar chart showing your best speeds across all durations
- Identifies which durations you excel at
- Value annotations

**Recent Best Efforts:**
- Last 30 days improvements
- Shows % improvement over previous best
- Green up arrow for improvements
- Sorted by biggest improvements first

**Efficiency Analysis (Power Ratio):**
- Speed/Heart Rate ratio over time
- Line chart with points showing trend
- Higher ratio = more efficient riding
- Average efficiency calculation

**Access:** Ride History → "Peak Performance"

---

## Chart Technology

### SwiftUI Charts Framework
- Uses native `Charts` framework (iOS 16+)
- Smooth animations
- Interactive elements
- Accessibility support

### Chart Types Used:
- **LineMark**: Smooth curves for time-series data
- **AreaMark**: Filled areas under curves
- **BarMark**: Vertical bars for comparisons
- **PointMark**: Individual data points

### Color Palette:
- Consistent color scheme across all views
- Metric-specific colors for instant recognition
- Gradient fills for visual appeal
- Professional, clean design

---

## Integration Points

### Ride History View
Added "Analytics" section at top with navigation to:
1. Performance Trends
2. Peak Performance

### Ride Detail View
Added "View Detailed Charts" button for rides with recorded data

### Data Requirements
Charts use existing `Ride` model data:
- `recordedData: [RideDataPoint]` - For detailed charts
- `date`, `distance`, `duration` - For trends
- `averageSpeed`, `maxSpeed` - For performance analysis
- `averageHeartRate` - For efficiency calculations

---

## Features Inspired by mPaceline

✅ **Output Graphs** → Speed/HR/Cadence over time
✅ **Graph Granularity** → Smooth interpolation with catmullRom
✅ **Performance Charts** → Bar and line charts for trends
✅ **Peak Power** → Best efforts at different durations
✅ **Power Ratio** → Efficiency metric (Speed/HR)
✅ **Enhanced Metrics** → Multiple statistics and summaries
✅ **Ride Comparisons** → Week-over-week comparisons
✅ **Time in Zone** → Already had this from previous implementation

---

## User Experience

### Visual Design:
- Clean, modern interface
- Color-coded metrics for quick recognition
- Shadow effects for depth
- Rounded corners throughout
- Proper spacing and padding

### Navigation Flow:
```
Main View
  └─> Ride History
        ├─> Performance Trends (new)
        │     ├─> Time range selector
        │     ├─> Summary cards
        │     ├─> Trend charts
        │     └─> Weekly comparison
        │
        ├─> Peak Performance (new)
        │     ├─> Duration selector
        │     ├─> Best effort card
        │     ├─> Peak curve
        │     ├─> Recent bests
        │     └─> Efficiency chart
        │
        └─> Individual Ride
              └─> Ride Detail Charts (new)
                    ├─> Metric selector
                    ├─> Interactive chart
                    └─> Statistics grid
```

### Empty States:
- Friendly messages when no data available
- Icon + text combinations
- Guidance on how to populate data

---

## Future Enhancement Ideas

### Possible Additions:
- [ ] Route comparison overlay (already have route detection!)
- [ ] FTP testing and tracking
- [ ] Monthly/yearly summaries
- [ ] Export charts as images
- [ ] Share ride data
- [ ] Goal tracking and progress
- [ ] Personal records (PR) tracking
- [ ] Training calendar view
- [ ] Comparison with previous rides on same route

### Integration Opportunities:
- Connect Peak Performance with existing Route Matching
- Show route-specific peak efforts
- Compare current ride to route best in real-time (already doing this!)

---

## Technical Notes

### Performance Optimization:
- Lazy loading of chart data
- Efficient date filtering
- Computed properties for aggregations
- Minimal re-renders

### Data Flow:
```swift
RideHistory (ObservableObject)
  └─> @Published var rides: [Ride]
        └─> Charts read from this array
              └─> Filter by date range
                    └─> Calculate metrics
                          └─> Display in charts
```

### Chart Smoothing:
- Uses `.interpolationMethod(.catmullRom)` for smooth curves
- Matches mPaceline's "Graph Granularity" feature
- Better visual representation than linear interpolation

---

## Testing Checklist

When testing the new charts:

- [ ] Ride Detail Charts show all 4 metrics correctly
- [ ] Performance Trends time ranges work (Week, Month, 3 Months, Year)
- [ ] All 5 trend metrics display properly
- [ ] Week-over-week comparison shows last 4 weeks
- [ ] Peak Performance duration selector works
- [ ] Best effort card shows correct data
- [ ] Peak curve displays all durations
- [ ] Recent bests show improvements
- [ ] Efficiency chart calculates ratio correctly
- [ ] Empty states display when no data
- [ ] Navigation works between all views
- [ ] Charts are responsive to data changes

---

## Summary

Added **3 major chart views** with **15+ different visualizations** covering:
- Individual ride analysis
- Performance trends over time
- Peak efforts and efficiency
- Week-over-week comparisons
- Best effort tracking

All inspired by mPaceline's excellent analytics features, but tailored for outdoor cycling and integrated with DesertMetrics' existing features like route detection and training load tracking.

🚴‍♂️ **Result:** A comprehensive analytics suite that gives you deep insights into your cycling performance!
