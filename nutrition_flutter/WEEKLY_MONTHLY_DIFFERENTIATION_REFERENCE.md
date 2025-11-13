# Weekly vs Monthly View Differentiation Reference

## Problem Statement
Currently, weekly and monthly views look identical because they both show:
- Current value (total)
- Average value (same as current)
- No goals
- Same layout

## Solution Overview
Make weekly and monthly views functionally different by:
1. **Different data breakdowns** (daily vs weekly)
2. **Different visualizations** (7-day chart vs 4-5 week chart)
3. **Different metrics** (daily patterns vs weekly patterns)
4. **Different insights** (day-level vs week-level analysis)

---

## Data Structure Reference

### Current Backend Endpoints Available

#### `/progress/weekly-summary` (app.py:2353)
Returns:
```json
{
  "week_start": "2024-01-01",
  "week_end": "2024-01-07",
  "calories": {
    "current": 14000,
    "goal": 17976,
    "daily_average": 2000,
    "remaining": 3976,
    "percentage": 0.78
  },
  "exercise": {
    "total_duration": 210,
    "daily_average_duration": 30,
    "sessions": 5,
    "consistency": 0.71
  },
  "trends": {...}
}
```

#### `/progress/monthly-summary` (app.py:2409)
Returns:
```json
{
  "month_start": "2024-01-01",
  "month_end": "2024-01-31",
  "calories": {
    "current": 62000,
    "goal": 79584,
    "daily_average": 2000,
    "remaining": 17584,
    "percentage": 0.78
  },
  "exercise": {
    "total_duration": 900,
    "daily_average_duration": 29,
    "sessions": 20,
    "consistency": 0.65
  },
  "trends": {...}
}
```

### Required Data Structure for Breakdowns

#### Weekly View Needs:
```dart
class WeeklyBreakdown {
  final List<DailyData> dailyBreakdown; // 7 days
  final double total;
  final double dailyAverage;
  final int daysWithData;
  final double consistency; // daysWithData / 7
}

class DailyData {
  final DateTime date;
  final double calories;
  final int exerciseMinutes;
  final String dayName; // "Mon", "Tue", etc.
}
```

#### Monthly View Needs:
```dart
class MonthlyBreakdown {
  final List<WeeklyData> weeklyBreakdown; // 4-5 weeks
  final double total;
  final double dailyAverage;
  final int weeksWithData;
  final double consistency; // weeksWithData / totalWeeks
}

class WeeklyData {
  final DateTime weekStart;
  final DateTime weekEnd;
  final double calories;
  final int exerciseMinutes;
  final String weekLabel; // "Week 1", "Week 2", etc.
}
```

---

## UI Layout Reference

### Weekly View Layout

```
┌─────────────────────────────────────┐
│ Calories                            │
│ This Week                           │
├─────────────────────────────────────┤
│ [Current: 14000 cal] [Avg: 2000/day]│
├─────────────────────────────────────┤
│ Daily Breakdown:                    │
│ ┌─────────────────────────────────┐ │
│ │ Mon: 1800 cal  ████████░░ 90%   │ │
│ │ Tue: 2200 cal  ██████████ 110%  │ │
│ │ Wed: 1900 cal  ████████░░ 95%   │ │
│ │ Thu: 2100 cal  █████████░ 105%  │ │
│ │ Fri: 2000 cal  █████████ 100%  │ │
│ │ Sat: 2200 cal  ██████████ 110% │ │
│ │ Sun: 1900 cal  ████████░░ 95%  │ │
│ └─────────────────────────────────┘ │
│                                      │
│ [Mini 7-Day Line Chart]             │
│ Mon Tue Wed Thu Fri Sat Sun         │
└─────────────────────────────────────┘
```

**Key Features:**
- Shows 7 individual days
- Daily average calculation (total ÷ 7)
- Mini line/bar chart for 7 days
- Day-by-day comparison
- Consistency metric (e.g., "5/7 days logged")

### Monthly View Layout

```
┌─────────────────────────────────────┐
│ Calories                            │
│ This Month                          │
├─────────────────────────────────────┤
│ [Current: 62000 cal] [Avg: 2000/day]│
├─────────────────────────────────────┤
│ Weekly Breakdown:                   │
│ ┌─────────────────────────────────┐ │
│ │ Week 1 (Jan 1-7):  14000 cal    │ │
│ │ Week 2 (Jan 8-14): 15000 cal    │ │
│ │ Week 3 (Jan 15-21): 16000 cal    │ │
│ │ Week 4 (Jan 22-28): 14000 cal    │ │
│ │ Week 5 (Jan 29-31): 3000 cal     │ │
│ └─────────────────────────────────┘ │
│                                      │
│ [4-5 Week Bar Chart]                │
│ Week1 Week2 Week3 Week4 Week5        │
└─────────────────────────────────────┘
```

**Key Features:**
- Shows 4-5 weekly summaries
- Daily average calculation (total ÷ days in month)
- Bar chart for weekly totals
- Week-by-week comparison
- Consistency metric (e.g., "4/5 weeks logged")

---

## Implementation Reference

### Existing Code Patterns

#### 1. Professional Graph Card (RECOMMENDED)
**Location:** `lib/widgets/professional_graph_card.dart`
- Uses `fl_chart` library for charts
- Supports line, bar, area, and combined charts
- Already has animations and professional styling
- Can handle different time ranges

**Reference for:** Both weekly and monthly charts (use bar chart for monthly, line for weekly)

#### 2. Line Graph Implementation
**Location:** `progress_screen.dart:679-882`
- `_buildLineGraph()` - Creates 7-day line chart
- `LineGraphPainter` - Custom painter for line graphs
- `_generateWeekData()` - Generates sample data for 7 days

**Reference for:** Weekly view daily breakdown chart (alternative to fl_chart)

#### 2. Graph Models
**Location:** `lib/models/graph_models.dart`
- `GraphDataPoint` - Data point structure
- `GraphStatistics` - Statistics calculation
- `TimeRange` enum - Time range options

**Reference for:** Data structure for breakdowns

#### 3. Backend Data Fetching
**Location:** `progress_data_service.dart:270-335`
- `_fetchBackendData()` - Fetches from `/progress/all`
- Returns: `{'calories': [...], 'weight': [...], 'workouts': [...]}`

**Reference for:** How to fetch breakdown data

### New Components Needed

#### 1. Weekly Breakdown Widget
```dart
class WeeklyBreakdownWidget extends StatelessWidget {
  final List<DailyData> dailyData;
  final double dailyAverage;
  
  // Shows 7-day list with mini chart
}
```

#### 2. Monthly Breakdown Widget
```dart
class MonthlyBreakdownWidget extends StatelessWidget {
  final List<WeeklyData> weeklyData;
  final double dailyAverage;
  
  // Shows 4-5 week cards with bar chart
}
```

#### 3. Daily Data Card
```dart
class DailyDataCard extends StatelessWidget {
  final DateTime date;
  final double calories;
  final double dailyGoal;
  
  // Shows single day with progress bar
}
```

#### 4. Weekly Data Card
```dart
class WeeklyDataCard extends StatelessWidget {
  final DateTime weekStart;
  final DateTime weekEnd;
  final double calories;
  
  // Shows week summary card
}
```

---

## Backend Enhancement Needed

### Current Issue
`/progress/all` returns raw date-value pairs:
```json
{
  "calories": [
    {"date": "2024-01-01", "calories": 2000},
    {"date": "2024-01-02", "calories": 2200}
  ]
}
```

### Required Enhancement
Add breakdown endpoints or enhance existing ones:

#### Option 1: Enhance `/progress/weekly-summary`
Add `daily_breakdown` field:
```json
{
  "daily_breakdown": [
    {"date": "2024-01-01", "calories": 2000, "day": "Mon"},
    {"date": "2024-01-02", "calories": 2200, "day": "Tue"}
  ]
}
```

#### Option 2: New Endpoint `/progress/weekly-breakdown`
Returns daily breakdown for the week

#### Option 3: Enhance `/progress/monthly-summary`
Add `weekly_breakdown` field:
```json
{
  "weekly_breakdown": [
    {
      "week_start": "2024-01-01",
      "week_end": "2024-01-07",
      "calories": 14000
    }
  ]
}
```

---

## Visual Differentiation Summary

| Feature | Weekly View | Monthly View |
|---------|------------|--------------|
| **Primary Display** | 7 individual days | 4-5 weekly summaries |
| **Chart Type** | Line chart (7 points) | Bar chart (4-5 bars) |
| **Data Granularity** | Daily values | Weekly totals |
| **Average Label** | "Daily Average: X cal/day" | "Daily Average: X cal/day" |
| **Breakdown Format** | Day list with progress bars | Week cards with totals |
| **Consistency Metric** | "X/7 days logged" | "X/5 weeks logged" |
| **Insights** | "Best day: Monday" | "Best week: Week 2" |
| **Trend Display** | Day-to-day variation | Week-to-week variation |

---

## Implementation Steps

1. **Backend Enhancement**
   - Add daily breakdown to `/progress/weekly-summary`
   - Add weekly breakdown to `/progress/monthly-summary`
   - Or create new breakdown endpoints

2. **Data Model Updates**
   - Add `WeeklyBreakdown` class
   - Add `MonthlyBreakdown` class
   - Update `ProgressData` to include breakdowns

3. **UI Component Creation**
   - Create `WeeklyBreakdownWidget`
   - Create `MonthlyBreakdownWidget`
   - Create `DailyDataCard` and `WeeklyDataCard`

4. **Integration**
   - Update `progress_screen.dart` to show different layouts
   - Update `simple_progress_screen.dart` similarly
   - Update `beautiful_progress_card.dart` for breakdown display

5. **Data Fetching**
   - Update `ProgressDataService` to fetch breakdown data
   - Parse and structure breakdown data
   - Pass to UI components

---

## Quick Win Implementation

**Phase 1: Basic Differentiation**
- Weekly: Show "Daily Average: X cal/day" + 7-day mini chart
- Monthly: Show "Daily Average: X cal/day" + 4-5 week summary list

**Phase 2: Enhanced Breakdowns**
- Weekly: Full daily breakdown with individual day cards
- Monthly: Full weekly breakdown with week summary cards

**Phase 3: Advanced Features**
- Trends and comparisons
- Consistency metrics
- Best day/week highlights
- Insights and recommendations

---

## Code References

### Existing Patterns to Reuse:
1. **Professional Graph Card:** `lib/widgets/professional_graph_card.dart` - Uses `fl_chart` library (RECOMMENDED)
2. **Line Graph:** `progress_screen.dart:679` - `_buildLineGraph()` (Alternative)
3. **Data Fetching:** `progress_data_service.dart:270` - `_fetchBackendData()`
4. **Graph Models:** `lib/models/graph_models.dart` - `GraphDataPoint`, `GraphConfig`
5. **Backend Endpoints:** `app.py:2353` - `/progress/weekly-summary`
6. **Chart Library:** `fl_chart` package (already in dependencies via `professional_graph_card.dart`)

### Files to Modify:
1. `lib/services/progress_data_service.dart` - Add breakdown fetching
2. `lib/screens/progress_screen.dart` - Add breakdown widgets
3. `lib/screens/simple_progress_screen.dart` - Add breakdown widgets
4. `lib/widgets/beautiful_progress_card.dart` - Add breakdown display
5. `app.py` - Enhance backend endpoints with breakdowns

---

This reference document provides the structure and patterns needed to differentiate weekly and monthly views effectively.

