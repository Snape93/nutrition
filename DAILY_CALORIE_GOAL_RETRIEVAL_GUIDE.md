# How to Get User's Daily Calorie Goal
## Complete Guide to Retrieving Old/Current Daily Calorie Target

---

## 📍 Where Daily Calorie Goal is Stored

### Backend (Database)
**Table:** `users`  
**Column:** `daily_calorie_goal` (Integer, nullable)

**Location:** `app.py` - User model (Line 536)
```python
daily_calorie_goal = db.Column(db.Integer, nullable=True)
```

---

## 🔍 How to Retrieve Daily Calorie Goal

### Method 1: From Progress Data Service (Recommended)
**Location:** `nutrition_flutter/lib/services/progress_data_service.dart`

**Usage:**
```dart
final progress = await ProgressDataService.getProgressData(
  usernameOrEmail: 'username',
  timeRange: TimeRange.daily,
);

final goalValue = progress.calories.goal; // This is the daily calorie goal
```

**How it works:**
1. Calls `/progress/goals?user={username}` endpoint
2. Backend returns: `{'calories': {'goal': 2248, ...}}`
3. Goal is the user's `daily_calorie_goal` from database

**Backend Endpoint:** `GET /progress/goals?user={username}` (Line 3717 in app.py)
```python
return jsonify({
    'calories': {
        'goal': user.daily_calorie_goal,  # From database
        ...
    }
})
```

---

### Method 2: From User Database (Direct)
**Location:** `nutrition_flutter/lib/user_database.dart`

**Usage:**
```dart
final goal = await UserDatabase().getDailyCalorieGoal('username');
// Returns: int (e.g., 2248) or 2000 if not found
```

**How it works:**
1. Calls `getUserData()` which fetches from `/user/{username}`
2. Extracts `daily_calorie_goal` from user data
3. Returns goal or defaults to 2000 if not found

**Backend Endpoint:** `GET /user/{username}` (Line 3603 in app.py)
```python
return jsonify({
    'daily_calorie_goal': user.daily_calorie_goal,
    ...
})
```

---

### Method 3: From Progress Screen (Current Implementation)
**Location:** `nutrition_flutter/lib/screens/beautiful_progress_screen.dart`

**Current Code:**
```dart
final goalValue = _progressData?.calories.goal ?? 0.0;
// _progressData comes from ProgressDataService.getProgressData()
```

---

## 📊 Data Flow

### Complete Flow Diagram

```
1. User Profile Created/Updated
   ↓
2. Backend Calculates Goal
   - Uses: compute_daily_calorie_goal()
   - Based on: age, sex, weight, height, activity_level, goal
   - Formula: BMR × Activity Multiplier ± Goal Adjustment
   ↓
3. Goal Stored in Database
   - Table: users
   - Column: daily_calorie_goal
   - Example: 2248 calories
   ↓
4. Frontend Retrieves Goal
   - Option A: ProgressDataService.getProgressData()
     → Calls: GET /progress/goals?user={username}
     → Returns: {'calories': {'goal': 2248}}
   
   - Option B: UserDatabase().getDailyCalorieGoal()
     → Calls: GET /user/{username}
     → Returns: {'daily_calorie_goal': 2248}
   ↓
5. Goal Used in UI
   - Bar graph goal line
   - Summary statistics
   - Progress calculations
```

---

## 🎯 How Goal is Calculated

### Backend Calculation
**Location:** `app.py` - `compute_daily_calorie_goal()` (Line 986)

**Formula:**
```python
# Step 1: Calculate BMR (Mifflin-St Jeor)
if sex == 'female':
    bmr = 10 * weight_kg + 6.25 * height_cm - 5 * age - 161
else:
    bmr = 10 * weight_kg + 6.25 * height_cm - 5 * age + 5

# Step 2: Calculate TDEE (Total Daily Energy Expenditure)
multipliers = {
    'sedentary': 1.2,
    'lightly active': 1.375,
    'active': 1.55,
    'very active': 1.725,
}
tdee = bmr * multipliers[activity_level]

# Step 3: Apply Goal Adjustment
if goal == 'lose weight':
    tdee -= 300
elif goal == 'gain muscle':
    tdee += 200
elif goal == 'gain weight':
    tdee += 300
# ... other goals

# Step 4: Clamp to Scientific Range
# Based on age, sex, activity level
# Example: Male 19-30, active: 2400-3000 calories

# Step 5: Store in Database
user.daily_calorie_goal = int(round(tdee))
```

---

## 🔄 When Goal is Updated

### Automatic Updates:
1. **User Registration:** Goal calculated and stored
2. **Profile Update:** If age, sex, weight, height, activity_level, or goal changes
   - Backend recalculates: `compute_daily_calorie_goal()`
   - Updates: `user.daily_calorie_goal` in database

**Location:** `app.py` - `/user/{username}` PUT endpoint (Line 3812)
```python
# Recalculate daily calorie goal if relevant fields changed
recalculate_calories = any(field in data for field in 
    ['age', 'sex', 'weight_kg', 'height_cm', 'activity_level', 'goal'])

if recalculate_calories:
    user.daily_calorie_goal = compute_daily_calorie_goal(
        user.sex, user.age, user.weight_kg, user.height_cm,
        user.activity_level, user.goal
    )
```

### Manual Updates:
- User can manually set goal via profile settings
- Stored directly in database without recalculation

---

## 📝 Code Examples

### Example 1: Get Goal in Progress Screen
```dart
// In beautiful_progress_screen.dart
Future<void> _loadProgressData() async {
  final progress = await ProgressDataService.getProgressData(
    usernameOrEmail: widget.usernameOrEmail,
    timeRange: TimeRange.daily,
  );
  
  final goalValue = progress.calories.goal; // Daily calorie goal
  // Use for bar graph goal line
}
```

### Example 2: Get Goal in Home Screen
```dart
// In home.dart
Future<void> _loadCalorieGoal() async {
  try {
    final progress = await ProgressDataService.getProgressData(
      usernameOrEmail: widget.usernameOrEmail,
      timeRange: TimeRange.daily,
    );
    setState(() {
      baseGoal = progress.calories.goal.toInt();
    });
  } catch (_) {
    // Fallback
    final calorieGoal = await UserDatabase().getDailyCalorieGoal(
      widget.usernameOrEmail,
    );
    setState(() {
      baseGoal = calorieGoal;
    });
  }
}
```

### Example 3: Get Goal Directly
```dart
// Direct method
final goal = await UserDatabase().getDailyCalorieGoal('username');
print('Daily calorie goal: $goal'); // e.g., 2248
```

---

## 🗄️ Database Structure

### User Table
```sql
CREATE TABLE users (
    id INTEGER PRIMARY KEY,
    username VARCHAR(80),
    email VARCHAR(120),
    ...
    daily_calorie_goal INTEGER,  -- The daily calorie target
    ...
);
```

### Example Data
```json
{
  "id": 1,
  "username": "john_doe",
  "email": "john@example.com",
  "daily_calorie_goal": 2248,
  "age": 25,
  "sex": "male",
  "weight_kg": 75,
  "height_cm": 175,
  "activity_level": "active",
  "goal": "maintain_weight"
}
```

---

## 🔍 Backend Endpoints

### 1. Get User Data (Includes Goal)
**Endpoint:** `GET /user/{username}`  
**Response:**
```json
{
  "username": "john_doe",
  "daily_calorie_goal": 2248,
  "age": 25,
  "sex": "male",
  ...
}
```

### 2. Get Progress Goals
**Endpoint:** `GET /progress/goals?user={username}`  
**Response:**
```json
{
  "calories": {
    "goal": 2248,
    "current": 1500,
    "remaining": 748
  }
}
```

### 3. Calculate Goal
**Endpoint:** `POST /calculate/daily_goal`  
**Request:**
```json
{
  "age": 25,
  "sex": "male",
  "weight": 75,
  "height": 175,
  "activity_level": "active",
  "goal": "maintain_weight"
}
```
**Response:**
```json
{
  "daily_calorie_goal": 2248
}
```

---

## ⚠️ Important Notes

### Default Value
- If goal is not set: Returns `2000` calories (default)
- If user doesn't exist: Returns `2000` calories (fallback)

### Goal Changes Over Time
- Goal is **current** goal, not historical
- If user updates profile, old goal is overwritten
- **No history** of previous goals is stored

### For Historical Goals
- **Current Limitation:** System doesn't track goal history
- Goal shown is always the **current** goal
- If you need historical goals, you would need to:
  1. Add a `goal_history` table
  2. Store goal changes with timestamps
  3. Query goal for specific date

---

## 🎯 Summary

**To Get User's Daily Calorie Goal:**

1. **Recommended Method:**
   ```dart
   final progress = await ProgressDataService.getProgressData(...);
   final goal = progress.calories.goal;
   ```

2. **Direct Method:**
   ```dart
   final goal = await UserDatabase().getDailyCalorieGoal('username');
   ```

3. **Backend:**
   - Stored in: `users.daily_calorie_goal` column
   - Calculated by: `compute_daily_calorie_goal()` function
   - Updated when: Profile changes (age, weight, etc.)

**The goal is the user's CURRENT daily calorie target, calculated based on their profile information!**

