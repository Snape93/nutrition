# ExerciseDB API Setup Guide

## Overview
This app now integrates with the ExerciseDB API to provide a comprehensive exercise database with filtering by categories (Cardio, Strength, Flexibility, Sports, Dance, Yoga).

## Setup Instructions

### 1. Get Free API Key
1. Visit [RapidAPI ExerciseDB](https://rapidapi.com/justin-WFnsXH_t6/api/exercisedb/)
2. Sign up for a free account
3. Subscribe to the ExerciseDB API (free tier available)
4. Copy your API key

### 2. Update API Key
Open `lib/services/exercise_service.dart` and replace:
```dart
static const String apiKey = 'YOUR_RAPIDAPI_KEY'; // Replace with your API key
```
with your actual API key:
```dart
static const String apiKey = 'your_actual_api_key_here';
```

### 3. Features Implemented

#### Exercise Categories
- **Cardio**: Running, jumping, cycling exercises
- **Strength**: Weight training, bodyweight exercises
- **Flexibility**: Stretching, mobility work
- **Sports**: Basketball, soccer, tennis drills
- **Dance**: Dance cardio, Zumba moves
- **Yoga**: Yoga poses, meditation

#### Exercise Timer
- Countdown timer with pause/resume
- Quick time presets (30s, 60s, 90s, 120s)
- Progress indicator
- Completion dialog
- Animated timer display

#### Exercise Details
- Step-by-step instructions
- Target muscle groups
- Difficulty levels
- Equipment needed
- Estimated calories burned

### 4. How to Use

1. **Browse Categories**: Tap any category on the exercise screen
2. **Search Exercises**: Use the search bar to find specific exercises
3. **View Details**: Tap any exercise to see detailed instructions
4. **Start Timer**: Tap "Start Timer" to begin a timed workout
5. **Customize Time**: Use the time presets or let it run for the default 60 seconds

### 5. API Endpoints Used

- `GET /exercises` - Fetch all exercises
- Automatic filtering by category based on exercise metadata
- Caching implemented to reduce API calls

### 6. Fallback Data
If the API is unavailable, the app will use sample exercise data for development and testing.

### 7. Categories Mapping

| Your Category | ExerciseDB Mapping | Examples |
|---------------|-------------------|----------|
| Cardio | bodyPart: 'cardio' or name contains 'run', 'jump', 'bike' | Running, Jumping Jacks |
| Strength | Most exercises by default | Push-ups, Squats |
| Flexibility | bodyPart: 'neck' or name contains 'stretch' | Stretches, Mobility |
| Sports | name contains 'basketball', 'soccer', 'tennis' | Sports drills |
| Dance | name contains 'dance', 'zumba', 'salsa' | Dance cardio |
| Yoga | name contains 'yoga', 'pose', 'meditation' | Yoga poses |

### 8. Troubleshooting

**API Not Working:**
- Check your API key is correct
- Verify you have an active RapidAPI subscription
- Check internet connection
- The app will fall back to sample data if API fails

**No Exercises Showing:**
- Try refreshing the screen
- Check the category mapping logic
- Verify the API is returning data

### 9. Future Enhancements

- Add exercise images/GIFs from the API
- Implement workout plans
- Add exercise history tracking
- Integrate with nutrition goals
- Add voice cues for timer
- Implement exercise difficulty progression

### 10. Files Created/Modified

**New Files:**
- `lib/models/exercise.dart` - Exercise data model
- `lib/services/exercise_service.dart` - API service
- `lib/exercise_category_screen.dart` - Category exercise list
- `lib/exercise_timer_screen.dart` - Timer functionality

**Modified Files:**
- `lib/exercise_screen.dart` - Updated to use new API
- `pubspec.yaml` - Already had http dependency

The implementation is now complete and ready to use with the ExerciseDB API! 