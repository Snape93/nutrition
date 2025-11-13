# Streak Feature Implementation Plan

## Overview
Add a professional streak tracking feature to the Progress screen, positioned below the Calories card in the white space. The feature will track consecutive days of meeting calorie goals and exercise goals, with gender-specific color theming.

## Visual Mockup Description

### Streak Card Layout (Below Calories Card)

```
┌─────────────────────────────────────────┐
│ Streak                    🔥            │
│ Keep your momentum going                │
├─────────────────────────────────────────┤
│                                         │
│            🔥                            │
│            5                            │
│        days streak                      │
│                                         │
│    [Calories] badge                     │
├─────────────────────────────────────────┤
│ ┌─────────┐ ┌─────────┐ ┌─────────┐   │
│ │Current  │ │Longest  │ │Started  │   │
│ │   5     │ │  10     │ │ 5 days  │   │
│ │ days    │ │ days    │ │ ago     │   │
│ └─────────┘ └─────────┘ └─────────┘   │
│                                         │
│ Great start! Keep it up!                │
└─────────────────────────────────────────┘
```

### Color Coding:
- **Green theme (Male)**: Primary color #4CAF50 for all highlighted elements
- **Rose Gold theme (Female)**: Primary color #B76E79 for all highlighted elements
- Current Streak box: Light primary color background (alpha 0.1)
- Other boxes: Light grey background
- Text: Black for primary, grey for secondary

## Database Schema (Already Exists)
Based on the database image, the `streaks` table has the following structure:
- `id` (serial) - Primary key
- `user` (varchar(88)) - Username
- `current_streak` (integer) - Current consecutive days
- `longest_streak` (integer) - Best streak ever achieved
- `last_activity_date` (date) - Last date activity was logged
- `streak_start_date` (date) - Date when current streak started
- `streak_type` (varchar(58)) - Type: 'calories' or 'exercise'
- `minimum_exercise_minutes` (integer) - Minimum minutes required for exercise streak
- `created_at` (timestamp) - Record creation time
- `updated_at` (timestamp) - Last update time

## Frontend Implementation Plan

### 1. UI Component Design
**Location**: Below the Calories card in `progress_screen.dart`

**Component Structure**:
```
StreakCard Widget
├── Header Section
│   ├── Title: "Streak" with flame icon
│   └── Subtitle: "Keep your momentum going"
├── Main Display
│   ├── Large Current Streak Number (prominent)
│   ├── Streak Type Badge (Calories/Exercise)
│   └── Visual Indicator (flame icons or progress ring)
├── Stats Row
│   ├── Current Streak Box
│   ├── Longest Streak Box
│   └── Days Since Start Box
└── Motivational Message
    └── Dynamic message based on streak length
```

**Design Specifications**:
- **Card Style**: 
  - White card (`AppDesignSystem.surface`)
  - Rounded corners: `AppDesignSystem.radiusLG` (16px)
  - Padding: `AppDesignSystem.spaceMD` (16px) internal padding
  - Elevation: `AppDesignSystem.elevationLow` (2.0) with shadow
  - Matches existing `BeautifulProgressCard` style
- **Spacing**: 
  - `AppDesignSystem.spaceMD` (16px) margin below Calories card
  - Use `AppDesignSystem.spaceMD` for internal spacing between elements
- **Colors**: 
  - Male users: Green (`AppDesignSystem.primaryGreen` - #4CAF50) for primary elements
  - Female users: Rose Gold (`AppDesignSystem.primaryRoseGold` - #B76E79) for primary elements
  - Use `AppDesignSystem.getPrimaryColor(userSex)` or `ThemeService.getPrimaryColor(userSex)` for consistency
  - Background: `AppDesignSystem.getBackgroundColor(userSex)`
  - Text: `AppDesignSystem.onSurface` for primary text, `AppDesignSystem.onSurfaceVariant` for secondary
- **Typography**: 
  - Title: `AppDesignSystem.headlineSmall` (18px, bold)
  - Streak number: `AppDesignSystem.displayLarge` (32px, bold) or custom 48px for emphasis
  - Stats labels: `AppDesignSystem.labelMedium` (12px, medium weight)
  - Stats values: `AppDesignSystem.titleMedium` (14px, semibold)
  - Motivational message: `AppDesignSystem.bodyMedium` (14px, regular)
- **Icons**: 
  - Flame icon (`Icons.local_fire_department`) for streak - size 24
  - Trophy icon (`Icons.emoji_events`) for longest streak - size 20
  - Calendar icon (`Icons.calendar_today`) for start date - size 20
  - Use primary color for icons

### 2. Flutter Files to Create/Modify

#### New Files:
1. **`lib/widgets/streak_card.dart`**
   - Reusable streak card widget
   - Accepts streak data and user sex for theming
   - Handles empty state (no streak yet)

2. **`lib/models/streak_model.dart`**
   - Data model for streak information
   - Parses JSON from API response

3. **`lib/services/streak_service.dart`**
   - Service to fetch streak data from backend
   - Handles API calls and error handling

#### Files to Modify:
1. **`lib/screens/progress_screen.dart`**
   - Add streak card below the Calories card (after `_buildWeightCard()`)
   - Add state management for streak data:
     ```dart
     StreakData? _streakData;
     bool _isLoadingStreak = false;
     ```
   - Add method to load streak data:
     ```dart
     Future<void> _loadStreakData() async {
       // Fetch streak data from API
     }
     ```
   - Call `_loadStreakData()` in `initState()` and `_loadDataForTimeRange()`
   - Add streak card widget in build method:
     ```dart
     _buildWeightCard(),
     SizedBox(height: AppDesignSystem.spaceMD),
     _buildStreakCard(),  // New streak card
     ```
   - Add spacing between cards using `AppDesignSystem.spaceMD`

### 3. UI Component Details

**StreakCard Widget Features**:
- **Current Streak Display**: Large number with flame icon
- **Streak Type Indicator**: Badge showing "Calories" or "Exercise"
- **Stats Boxes**: Three boxes showing:
  - Current Streak (highlighted in primary color)
  - Longest Streak (grey background)
  - Days Since Start (grey background)
- **Visual Progress**: 
  - For streaks < 7 days: Show progress ring
  - For streaks >= 7 days: Show milestone badge
  - For streaks >= 30 days: Show special achievement badge
- **Empty State**: 
  - Message: "Start your streak today!"
  - Button: "Log Activity" (opens relevant logging screen)
- **Motivational Messages** (based on streak length):
  - 1-3 days: "Great start! Keep it up!"
  - 4-6 days: "You're building momentum!"
  - 7-13 days: "One week strong! 🔥"
  - 14-29 days: "Two weeks! You're unstoppable!"
  - 30+ days: "30+ days! Legend status! 🏆"

**Color Logic Implementation**:
```dart
// Get primary color based on gender
Color primaryColor = ThemeService.getPrimaryColor(widget.userSex);
Color backgroundColor = ThemeService.getBackgroundColor(widget.userSex);

// Use primaryColor for:
// - Streak number text
// - Current streak box background
// - Progress indicators
// - Icons
```

**Responsive Design**:
- Card width: Full width (matches Calories card)
- Padding: 20px internal padding
- Minimum height: 200px
- Adapts to different screen sizes

## Backend Implementation Plan

### 1. Database Model (Add to app.py)

```python
class Streak(db.Model):
    __tablename__ = 'streaks'
    __table_args__ = (
        db.Index('ix_streaks_user_type', 'user', 'streak_type'),
    )
    id = db.Column(db.Integer, primary_key=True)
    user = db.Column(db.String(88), nullable=False)
    current_streak = db.Column(db.Integer, default=0)
    longest_streak = db.Column(db.Integer, default=0)
    last_activity_date = db.Column(db.Date, nullable=True)
    streak_start_date = db.Column(db.Date, nullable=True)
    streak_type = db.Column(db.String(58), nullable=False)  # 'calories' or 'exercise'
    minimum_exercise_minutes = db.Column(db.Integer, default=15)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
```

### 2. API Endpoints

#### GET `/api/streaks`
**Purpose**: Fetch user's streak data
**Query Parameters**:
- `user` (required): Username
- `type` (optional): Filter by streak type ('calories' or 'exercise'). If not provided, returns both.

**Response**:
```json
{
  "success": true,
  "streaks": [
    {
      "id": 1,
      "user": "markdle",
      "current_streak": 5,
      "longest_streak": 10,
      "last_activity_date": "2025-11-07",
      "streak_start_date": "2025-11-03",
      "streak_type": "calories",
      "minimum_exercise_minutes": 15,
      "days_since_start": 5,
      "is_active": true
    }
  ]
}
```

#### POST `/api/streaks/update`
**Purpose**: Update streak when user logs activity
**Request Body**:
```json
{
  "user": "markdle",
  "streak_type": "calories",  // or "exercise"
  "date": "2025-11-07",
  "met_goal": true,  // Whether user met their goal for the day
  "exercise_minutes": 30  // Required if streak_type is "exercise"
}
```

**Response**:
```json
{
  "success": true,
  "streak_updated": true,
  "current_streak": 6,
  "longest_streak": 10,
  "message": "Streak updated successfully"
}
```

#### GET `/api/streaks/check`
**Purpose**: Check if user's streak should be updated based on today's activity
**Query Parameters**:
- `user` (required): Username
- `type` (optional): Streak type to check

**Response**:
```json
{
  "success": true,
  "needs_update": true,
  "current_streak": 5,
  "will_increment": true
}
```

### 3. Streak Calculation Logic

#### For Calories Streak:
- Check if user met their daily calorie goal
- If met: Increment streak, update `last_activity_date`
- If not met: Reset streak to 0, update `streak_start_date` to today if starting new streak
- Update `longest_streak` if current exceeds it

#### For Exercise Streak:
- Check if user logged at least `minimum_exercise_minutes` (default: 15) of exercise
- Same logic as calories streak

#### Streak Continuity Rules:
- Streak continues if activity is logged on consecutive days
- If a day is missed, streak resets to 0
- `last_activity_date` must be yesterday or today to continue streak
- If `last_activity_date` is 2+ days ago, streak is broken

### 4. Integration Points

**When to Update Streaks**:
1. **Calories Streak**: 
   - After food logging (check if daily goal is met)
   - End of day check (cron job or scheduled task)

2. **Exercise Streak**:
   - After exercise session logging
   - After workout log creation
   - End of day check

**Existing Endpoints to Modify**:
- `/log/food` (POST) - Add streak check after logging
- `/log/exercise` (POST) - Add streak check after logging
- `/log/workout` (POST) - Add streak check after logging
- `/progress/daily` (GET) - Include streak data in response

### 5. Helper Functions

```python
def calculate_calories_streak(user, target_date=None):
    """Calculate calories streak for a user"""
    # Check if user met calorie goal for consecutive days
    # Return current streak count
    
def calculate_exercise_streak(user, target_date=None):
    """Calculate exercise streak for a user"""
    # Check if user met exercise goal for consecutive days
    # Return current streak count
    
def update_streak(user, streak_type, met_goal, date=None):
    """Update streak record for user"""
    # Get or create streak record
    # Update based on whether goal was met
    # Handle streak breaks and increments
    
def get_streak_data(user, streak_type=None):
    """Get streak data for user"""
    # Query streak records
    # Calculate additional metrics (days since start, etc.)
    # Return formatted data
```

## Implementation Steps

### Phase 1: Backend Setup
1. Add `Streak` model to `app.py`
2. Create helper functions for streak calculation
3. Implement GET `/api/streaks` endpoint
4. Implement POST `/api/streaks/update` endpoint
5. Add streak update logic to existing logging endpoints
6. Test backend endpoints

### Phase 2: Frontend Models & Services
1. Create `streak_model.dart` with data classes
2. Create `streak_service.dart` with API integration
3. Test API connectivity

### Phase 3: UI Component
1. Create `streak_card.dart` widget
2. Implement empty state
3. Implement active streak display
4. Add gender-specific theming
5. Add motivational messages
6. Test UI responsiveness

### Phase 4: Integration
1. Integrate streak card into `progress_screen.dart`
2. Add state management
3. Load streak data on screen load
4. Test full flow

### Phase 5: Polish
1. Add animations (streak increment, milestone celebrations)
2. Add error handling
3. Add loading states
4. Test edge cases (no streak, broken streak, etc.)

## Testing Checklist

### Backend Tests:
- [ ] GET endpoint returns correct streak data
- [ ] POST endpoint updates streak correctly
- [ ] Streak increments when goal is met
- [ ] Streak resets when goal is not met
- [ ] Longest streak updates correctly
- [ ] Handles missing streak records
- [ ] Handles concurrent updates

### Frontend Tests:
- [ ] Streak card displays correctly
- [ ] Colors match gender theme
- [ ] Empty state shows when no streak
- [ ] Stats display correctly
- [ ] Motivational messages change based on streak
- [ ] Card fits properly below Calories card
- [ ] Responsive on different screen sizes
- [ ] Error handling works
- [ ] Loading states display

## Notification System Plan

### Overview
Implement a comprehensive notification system to help users maintain their streaks through timely reminders, milestone celebrations, and streak protection alerts.

### Notification Types

#### 1. Daily Reminder Notifications
**Purpose**: Remind users to log activity to maintain their streak

**Trigger Conditions**:
- User has an active streak (current_streak > 0)
- No activity logged for today yet
- User has notifications enabled

**Timing**:
- **Morning Reminder**: 9:00 AM (configurable)
- **Evening Reminder**: 7:00 PM (if still no activity logged)
- **Last Chance**: 10:00 PM (if still no activity logged)

**Notification Content**:
```
Title: "Keep your streak alive! 🔥"
Body: "You're on a {current_streak}-day streak! Log your {streak_type} to keep it going."
Action: "Log Activity" button
```

#### 2. Milestone Celebration Notifications
**Purpose**: Celebrate user achievements at streak milestones

**Trigger Conditions**:
- Streak reaches milestone (7, 14, 30, 50, 100 days)
- Milestone notification not sent yet for this streak

**Timing**: Immediate when milestone is reached

**Notification Content by Milestone**:
- **7 days**: "🔥 One week strong! You've maintained your streak for 7 days!"
- **14 days**: "💪 Two weeks! You're unstoppable! 14 days and counting!"
- **30 days**: "🏆 30-day milestone! You're a streak legend! Keep it up!"
- **50 days**: "⭐ 50 days! Incredible dedication! You're inspiring!"
- **100 days**: "👑 100 DAYS! You're a streak master! This is legendary!"

#### 3. Streak Warning Notifications
**Purpose**: Alert users when their streak is at risk

**Trigger Conditions**:
- User has an active streak
- It's past 8:00 PM and no activity logged today
- Last activity was yesterday (streak will break if no activity today)

**Timing**: 8:00 PM (configurable)

**Notification Content**:
```
Title: "⚠️ Don't lose your streak!"
Body: "You're on a {current_streak}-day streak. Log your {streak_type} today to keep it going!"
Action: "Log Now" button
```

#### 4. Streak Broken Notifications
**Purpose**: Notify users when streak is broken and encourage restart

**Trigger Conditions**:
- Streak was broken (missed a day)
- Notification not sent yet for this break

**Timing**: Next day after streak breaks (morning)

**Notification Content**:
```
Title: "Your streak has ended"
Body: "You had a {previous_streak}-day streak! Start a new one today and beat your record of {longest_streak} days."
Action: "Start New Streak" button
```

#### 5. Longest Streak Achievement
**Purpose**: Celebrate when user breaks their personal record

**Trigger Conditions**:
- Current streak exceeds longest_streak
- New record achieved

**Timing**: Immediate when record is broken

**Notification Content**:
```
Title: "🎉 New Personal Record!"
Body: "You've set a new record with {current_streak} days! Your longest streak ever!"
```

#### 6. Streak Recovery Reminder
**Purpose**: Encourage users to restart after a break

**Trigger Conditions**:
- User had a streak that was broken
- No new streak started yet
- 2-3 days after break

**Timing**: 2 days after streak break (morning)

**Notification Content**:
```
Title: "Ready to start again?"
Body: "Your longest streak was {longest_streak} days. Start a new streak today and beat it!"
Action: "Start Streak" button
```

### Implementation Architecture

#### Frontend (Flutter)

**Required Packages** (add to `pubspec.yaml`):
```yaml
dependencies:
  flutter_local_notifications: ^17.2.3
  timezone: ^0.9.4  # For scheduling notifications
  # Optional: For push notifications
  firebase_messaging: ^15.1.3
  firebase_core: ^3.6.0
```

**New Files to Create**:

1. **`lib/services/notification_service.dart`**
   - Initialize local notifications
   - Request notification permissions
   - Schedule notifications
   - Cancel notifications
   - Handle notification taps

2. **`lib/services/streak_notification_service.dart`**
   - Streak-specific notification logic
   - Check streak status and schedule reminders
   - Handle milestone notifications
   - Manage notification preferences

3. **`lib/models/notification_preferences.dart`**
   - User notification preferences model
   - Store preferences in SharedPreferences

**Files to Modify**:

1. **`lib/settings.dart`**
   - Add detailed notification settings screen
   - Toggle for each notification type
   - Time picker for reminder times
   - Notification sound/vibration preferences

2. **`lib/services/streak_service.dart`**
   - Trigger notifications when streak updates
   - Check for milestones and send notifications

3. **`lib/main.dart`** or app entry point
   - Initialize notification service
   - Handle notification taps (deep linking)

#### Backend (Python/Flask)

**New Database Table**: `notification_preferences`
```sql
CREATE TABLE notification_preferences (
    id SERIAL PRIMARY KEY,
    user VARCHAR(88) NOT NULL,
    notifications_enabled BOOLEAN DEFAULT TRUE,
    daily_reminders_enabled BOOLEAN DEFAULT TRUE,
    milestone_notifications_enabled BOOLEAN DEFAULT TRUE,
    warning_notifications_enabled BOOLEAN DEFAULT TRUE,
    reminder_time_morning TIME DEFAULT '09:00:00',
    reminder_time_evening TIME DEFAULT '19:00:00',
    reminder_time_warning TIME DEFAULT '20:00:00',
    timezone VARCHAR(50) DEFAULT 'UTC',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user)
);
```

**New API Endpoints**:

1. **GET `/api/notifications/preferences`**
   - Get user's notification preferences
   - Query params: `user` (required)

2. **POST `/api/notifications/preferences`**
   - Update user's notification preferences
   - Request body: JSON with preference settings

3. **POST `/api/notifications/send`** (Optional - for server-side push)
   - Send push notification from server
   - Request body: `{user, type, title, body, data}`

**Helper Functions**:
```python
def get_notification_preferences(user):
    """Get user notification preferences"""
    
def update_notification_preferences(user, preferences):
    """Update user notification preferences"""
    
def should_send_notification(user, notification_type):
    """Check if notification should be sent based on preferences"""
```

### Notification Service Implementation

**File: `lib/services/notification_service.dart`**

```dart
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = 
      FlutterLocalNotificationsPlugin();
  
  // Initialize notification service
  static Future<void> initialize() async {
    // Request permissions
    // Initialize Android and iOS channels
    // Set up notification handlers
  }
  
  // Schedule daily reminder
  static Future<void> scheduleDailyReminder({
    required Time time,
    required String title,
    required String body,
    required int notificationId,
  }) async {
    // Schedule recurring notification
  }
  
  // Send immediate notification
  static Future<void> showNotification({
    required String title,
    required String body,
    required Map<String, dynamic>? data,
  }) async {
    // Show notification immediately
  }
  
  // Cancel notification
  static Future<void> cancelNotification(int id) async {
    // Cancel scheduled notification
  }
  
  // Cancel all notifications
  static Future<void> cancelAllNotifications() async {
    // Cancel all scheduled notifications
  }
}
```

**File: `lib/services/streak_notification_service.dart`**

```dart
class StreakNotificationService {
  // Schedule streak-related notifications
  static Future<void> scheduleStreakNotifications({
    required String username,
    required StreakData streak,
  }) async {
    // Schedule daily reminders if streak is active
    // Schedule warning if needed
    // Cancel old notifications
  }
  
  // Send milestone notification
  static Future<void> sendMilestoneNotification({
    required int streakDays,
  }) async {
    // Send celebration notification
  }
  
  // Send streak broken notification
  static Future<void> sendStreakBrokenNotification({
    required int previousStreak,
    required int longestStreak,
  }) async {
    // Send notification about broken streak
  }
  
  // Check and send notifications based on streak status
  static Future<void> checkAndSendNotifications({
    required String username,
    required StreakData streak,
  }) async {
    // Check current time and streak status
    // Send appropriate notifications
  }
}
```

### Notification Settings UI

**New Screen: `lib/screens/notification_settings_screen.dart`**

Features:
- Toggle switches for each notification type
- Time pickers for reminder times
- Sound/vibration preferences
- Test notification button
- Preview notification examples

**Settings Structure**:
```dart
class NotificationPreferences {
  bool notificationsEnabled;
  bool dailyRemindersEnabled;
  bool milestoneNotificationsEnabled;
  bool warningNotificationsEnabled;
  bool streakBrokenNotificationsEnabled;
  Time morningReminderTime;
  Time eveningReminderTime;
  Time warningReminderTime;
  bool soundEnabled;
  bool vibrationEnabled;
}
```

### Notification Scheduling Logic

**Daily Reminder Scheduling**:
1. Check if user has active streak
2. Check if activity logged today
3. If no activity, schedule reminders at configured times
4. Cancel reminders if activity is logged

**Milestone Detection**:
1. When streak updates, check if milestone reached
2. Compare current_streak to milestone values (7, 14, 30, 50, 100)
3. Send notification if milestone reached
4. Mark milestone as notified to avoid duplicates

**Warning Notifications**:
1. Check current time (after warning time)
2. Check if activity logged today
3. Check if streak is active
4. Send warning if conditions met

### Implementation Steps

#### Phase 1: Setup
1. Add notification packages to `pubspec.yaml`
2. Create `NotificationService` class
3. Initialize notifications in app startup
4. Request permissions from user

#### Phase 2: Basic Notifications
1. Implement immediate notifications
2. Test notification display
3. Handle notification taps

#### Phase 3: Scheduling
1. Implement notification scheduling
2. Create time-based reminders
3. Test scheduled notifications

#### Phase 4: Streak Integration
1. Create `StreakNotificationService`
2. Integrate with streak updates
3. Implement milestone detection
4. Test all notification types

#### Phase 5: Settings UI
1. Create notification settings screen
2. Add preferences storage
3. Implement preference sync with backend
4. Test all settings

#### Phase 6: Backend Integration
1. Create notification preferences table
2. Implement API endpoints
3. Sync preferences between app and backend
4. Test full flow

### Testing Checklist

**Notification Functionality**:
- [ ] Notifications display correctly
- [ ] Notification taps navigate to correct screen
- [ ] Scheduled notifications fire at correct times
- [ ] Notifications respect user preferences
- [ ] Notifications cancel when activity logged
- [ ] Milestone notifications trigger correctly
- [ ] Warning notifications work
- [ ] Streak broken notifications send
- [ ] Notification sounds/vibration work
- [ ] Notifications work when app is closed
- [ ] Notifications work when app is in background

**Settings**:
- [ ] All toggles work correctly
- [ ] Time pickers save correctly
- [ ] Preferences persist across app restarts
- [ ] Preferences sync with backend
- [ ] Test notification button works

**Edge Cases**:
- [ ] No notifications if user disabled them
- [ ] No notifications if no active streak
- [ ] Handle timezone changes
- [ ] Handle app updates
- [ ] Handle notification permission denial

### Notification Content Examples

**Daily Reminder (Morning)**:
```
🔥 Keep Your Streak Going!
You're on a 5-day streak! Log your calories today to make it 6 days.
[Log Activity]
```

**Daily Reminder (Evening)**:
```
⏰ Don't Forget Your Streak!
You're on a 5-day streak. Log your calories before the day ends!
[Log Now]
```

**Milestone (7 days)**:
```
🎉 One Week Strong!
Congratulations! You've maintained your streak for 7 days. Keep it up!
[View Progress]
```

**Warning**:
```
⚠️ Streak at Risk!
You're on a 5-day streak but haven't logged activity today. Log now to keep it going!
[Log Activity]
```

**Streak Broken**:
```
Your Streak Ended
You had a 5-day streak! Start a new one today and beat your record of 10 days.
[Start New Streak]
```

### Future Enhancements
- Push notifications via Firebase (server-side)
- Rich notifications with images
- Notification actions (quick log buttons)
- Streak freeze feature (pause streak for one day)
- Social notifications (friends' milestones)
- Notification analytics

## Future Enhancements (Not in Initial Implementation)
- Streak history graph
- Streak sharing/social features
- Multiple streak types (water intake, steps, etc.)
- Streak recovery options (freeze streak for one day)
- Streak leaderboards

## Notes
- The database table already exists, so we only need to add the model class
- Follow existing code patterns for consistency
- Use the same error handling approach as other services
- Maintain gender-specific color theming throughout
- Ensure proper spacing and alignment with existing UI elements
- Notifications should respect user preferences and be non-intrusive
- Consider battery optimization when scheduling notifications
- Test notifications on both Android and iOS platforms

