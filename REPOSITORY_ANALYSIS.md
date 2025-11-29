# Repository Analysis: Nutritionist App

**Repository:** https://github.com/Snape93/nutrition-app  
**Analysis Date:** January 2025  
**Language Distribution:** Dart (69.6%), Python (25.1%), C++ (2.2%), CMake (1.7%), Kotlin (1.0%), Swift (0.2%)

---

## 📋 Executive Summary

This is a **full-stack nutrition and fitness tracking application** with:
- **Backend:** Flask (Python) REST API with machine learning capabilities
- **Frontend:** Flutter mobile app (Android & iOS)
- **Database:** PostgreSQL (Neon) with SQLAlchemy ORM
- **Deployment:** Azure App Service (production), with guides for Railway/Render
- **Status:** ✅ Production-ready and deployed

---

## 🏗️ Architecture Overview

### System Architecture
```
┌─────────────────┐
│  Flutter App    │  (Mobile - Android/iOS)
│  (Dart)         │
└────────┬────────┘
         │ HTTP/REST API
         ▼
┌─────────────────┐
│  Flask Backend  │  (Python)
│  (app.py)       │
└────────┬────────┘
         │
    ┌────┴────┐
    │         │
    ▼         ▼
┌────────┐ ┌──────────────┐
│ Neon   │ │ ML Model     │
│ Postgres│ │ (scikit-learn)│
└────────┘ └──────────────┘
```

### Key Components

1. **Backend API** (`app.py` - 9,193 lines)
   - Flask REST API with 95+ endpoints
   - Machine learning model integration
   - Email verification system
   - Authentication & authorization

2. **Mobile App** (`nutrition_flutter/`)
   - Flutter/Dart application
   - Health integration (Health Connect, Google Fit)
   - Offline connectivity detection
   - Material Design UI

3. **ML Model** (`nutrition_model.py`)
   - Pre-trained regression model for calorie prediction
   - Filipino food database integration
   - Nutrition guidelines engine

---

## 🛠️ Tech Stack

### Backend
| Technology | Version | Purpose |
|------------|---------|---------|
| Flask | 2.3.3 | Web framework |
| SQLAlchemy | 3.1.1 | ORM |
| PostgreSQL | - | Database (via Neon) |
| scikit-learn | 1.6.1 | ML model |
| pandas | 2.0.3 | Data processing |
| Gunicorn | 21.2.0 | WSGI server |
| Flask-CORS | 4.0.0 | CORS handling |

### Frontend
| Technology | Version | Purpose |
|------------|---------|---------|
| Flutter | SDK 3.7.2+ | Mobile framework |
| Dart | 3.7.2+ | Programming language |
| http | ^1.2.0 | HTTP client |
| fl_chart | ^1.0.0 | Charts/graphs |
| health | ^13.2.0 | Health data integration |
| google_sign_in | ^6.2.1 | Google authentication |
| connectivity_plus | ^6.0.0 | Network detection |

### Infrastructure
- **Database:** Neon PostgreSQL (serverless)
- **Deployment:** Azure App Service for Containers
- **Container:** Docker
- **Email:** Gmail SMTP
- **External APIs:** 
  - ExerciseDB (RapidAPI)
  - Groq AI (optional, for AI Coach)

---

## 🎯 Key Features

### 1. User Management
- ✅ User registration with email verification
- ✅ Login/authentication
- ✅ Password reset with verification
- ✅ Email change with verification
- ✅ Account deletion with verification
- ✅ Profile management

### 2. Nutrition Tracking
- ✅ Food logging (Filipino foods database)
- ✅ Calorie tracking
- ✅ Daily calorie goal calculation
- ✅ Meal recommendations (ML-powered)
- ✅ Custom recipes
- ✅ Food search and filtering
- ✅ Nutrition analysis

### 3. Exercise Tracking
- ✅ Exercise logging
- ✅ Exercise sessions
- ✅ Exercise categories (Cardio, Strength, Flexibility/Mobility)
- ✅ Custom exercise submissions
- ✅ Exercise timer
- ✅ Integration with ExerciseDB API

### 4. Progress & Analytics
- ✅ Weight tracking
- ✅ Progress summaries (daily/weekly/monthly)
- ✅ Streak tracking (calories & exercise)
- ✅ Achievement system
- ✅ Charts and visualizations
- ✅ Goal history

### 5. AI Features
- ✅ AI Coach chat (Groq integration)
- ✅ Daily summary generation
- ✅ Meal recommendations
- ✅ "What to eat next" suggestions

### 6. Health Integration
- ✅ Health Connect (Android)
- ✅ Google Fit integration
- ✅ Health data synchronization

### 7. Mobile Features
- ✅ Offline connectivity detection
- ✅ Onboarding flow
- ✅ Tutorial system
- ✅ Theme support
- ✅ Responsive design

---

## 🗄️ Database Schema

### Core Models (17 total)

1. **User** - User accounts and profiles
   - Authentication credentials
   - Profile data (age, sex, weight, height, activity level)
   - Daily calorie goal
   - Tutorial completion status

2. **FoodLog** - Food consumption records
   - User, date, food name
   - Calories, macros (protein, carbs, fats)
   - Meal type

3. **ExerciseLog** - Exercise records
   - User, date, exercise name
   - Duration, calories burned
   - MET value

4. **ExerciseSession** - Grouped exercise sessions
   - Start/end times
   - Total duration and calories
   - Exercise category

5. **WeightLog** - Weight tracking
   - User, date, weight value

6. **Streak** - Streak tracking
   - Current/longest streak
   - Streak type (calories/exercise)
   - Activity dates

7. **GoalHistory** - Historical goal changes
   - Goal type, old/new values
   - Change date

8. **CustomRecipe** - User-created recipes
   - Recipe name, ingredients
   - Nutrition totals

9. **RecipeLog** - Recipe consumption logs

10. **Exercise** - Exercise database
    - Name, category, MET value
    - Description

11. **UserExerciseSubmission** - Custom exercise submissions
    - Status (pending/approved/rejected)

12. **PendingRegistration** - Email verification for signup

13. **PendingEmailChange** - Email change verification

14. **PendingPasswordChange** - Password change verification

15. **PendingAccountDeletion** - Account deletion verification

16. **WorkoutLog** - Legacy workout tracking (deprecated?)

---

## 🔌 API Endpoints (95+ endpoints)

### Authentication & User Management
- `POST /register` - User registration
- `POST /login` - User login
- `GET /auth/check-username` - Username availability
- `GET /auth/check-email` - Email availability
- `POST /auth/verify-code` - Verify email code
- `POST /auth/resend-code` - Resend verification code
- `POST /auth/reset-password` - Password reset request
- `POST /auth/password-reset/verify` - Verify password reset
- `GET /user/<username>` - Get user profile
- `PUT /user/<username>` - Update user profile
- `DELETE /user/<username>` - Delete user account

### Food & Nutrition
- `POST /log/food` - Log food consumption
- `GET /log/food` - Get food logs
- `PUT /log/food/<id>` - Update food log
- `DELETE /log/food/<id>` - Delete food log
- `GET /foods/search` - Search foods
- `GET /foods/info` - Get food information
- `GET /foods/filipino` - Get Filipino foods
- `POST /recommend/meals` - Get meal recommendations
- `POST /recommendations/meals` - ML-powered recommendations
- `POST /recommendations/foods/search` - Search recommendations
- `GET /foods/recommend` - Food recommendations

### Exercise
- `GET /exercises` - List exercises
- `GET /exercises/categories` - Get exercise categories
- `POST /exercises/calculate` - Calculate exercise calories
- `POST /exercises/session` - Create exercise session
- `GET /exercises/sessions` - Get exercise sessions
- `DELETE /exercises/session/<id>` - Delete session
- `POST /log/exercise` - Log exercise
- `GET /log/exercise` - Get exercise logs
- `POST /api/exercises/custom` - Submit custom exercise
- `GET /api/exercises/custom` - Get custom exercises

### Progress & Analytics
- `GET /progress/weight` - Weight progress
- `GET /progress/calories` - Calorie progress
- `GET /progress/workouts` - Workout progress
- `GET /progress/summary` - Overall summary
- `GET /progress/daily-summary` - Daily summary
- `GET /progress/weekly-summary` - Weekly summary
- `GET /progress/monthly-summary` - Monthly summary
- `GET /progress/goals` - Get goals
- `POST /progress/goals` - Set goals
- `GET /progress/achievements` - Get achievements
- `GET /remaining` - Get remaining calories
- `GET /api/streaks` - Get streaks
- `POST /api/streaks/update` - Update streaks

### AI Features
- `POST /ai/summary/daily` - Generate daily AI summary
- `POST /ai/what-to-eat-next` - AI meal suggestions
- `POST /ai/coach/chat` - AI coach chat

### ML & Predictions
- `POST /predict/calories` - Predict calories
- `POST /predict/nutrition` - Predict nutrition
- `GET /ml/stats` - ML model statistics

### Recipes
- `POST /recipes` - Create recipe
- `GET /recipes` - Get recipes
- `DELETE /recipes/<id>` - Delete recipe
- `POST /log/recipe` - Log recipe consumption

### Utilities
- `GET /health` - Health check
- `GET /calculate/daily_goal` - Calculate daily calorie goal
- `POST /log/weight` - Log weight
- `GET /log/weight` - Get weight logs
- `POST /log/custom-meal` - Log custom meal
- `GET /custom-meals` - Get custom meals

---

## 📱 Mobile App Structure

### Main Screens
- `landing.dart` - Landing/onboarding
- `login.dart` - Login screen
- `register.dart` - Registration
- `home.dart` - Main dashboard
- `food_log_screen.dart` - Food logging
- `exercise_category_screen.dart` - Exercise categories
- `your_exercise_screen.dart` - Exercise list
- `history_screen.dart` - History view
- `profile_view.dart` - User profile
- `settings.dart` - App settings
- `account_settings.dart` - Account management

### Services Layer
- `connectivity_service.dart` - Network detection
- `health_service.dart` - Health data integration
- `google_fit_service.dart` - Google Fit sync
- `exercise_service.dart` - Exercise API calls
- `progress_data_service.dart` - Progress data
- `ai_coach_service.dart` - AI coach integration
- `streak_service.dart` - Streak tracking
- `remaining_service.dart` - Remaining calories

### Widgets
- Custom widgets for UI components
- Design system implementation
- Logo loading dialog
- Streak card widget

### Models
- Data models for API responses
- Local database models

---

## 🚀 Deployment Status

### Current Deployment
- **Backend:** Azure App Service for Containers
  - URL: `https://nutritionist-app-backend-dnbgf8bzf4h3hhhn.southeastasia-01.azurewebsites.net`
- **Database:** Neon PostgreSQL
- **Mobile App:** Android APK/AAB available

### Deployment Options
1. **Azure** (Primary) - `DEPLOY_TO_AZURE.md`
2. **Railway** - `DEPLOY_TO_RAILWAY_NOW.md`
3. **Render** - `DEPLOY_TO_RENDER.md`
4. **GitHub Pages** - `GITHUB_DEPLOYMENT.md`

### Environment Variables Required
- `SECRET_KEY` - Flask secret key
- `NEON_DATABASE_URL` - PostgreSQL connection
- `GMAIL_USERNAME` - Email service
- `GMAIL_APP_PASSWORD` - Gmail app password
- `EXERCISEDB_API_KEY` - ExerciseDB API key
- `GROQ_API_KEY` - (Optional) AI features
- `FLASK_ENV` - Environment (production/development)
- `ALLOWED_ORIGINS` - CORS origins

---

## 📊 Code Quality & Organization

### Strengths ✅
1. **Comprehensive Documentation**
   - Extensive markdown guides (67+ .md files)
   - Deployment guides for multiple platforms
   - Testing guides
   - Implementation summaries

2. **Well-Structured API**
   - RESTful design
   - Consistent error handling
   - Comprehensive endpoint coverage

3. **Security Features**
   - Email verification for all critical actions
   - Password hashing (Werkzeug)
   - CORS configuration
   - Environment-based configuration

4. **ML Integration**
   - Pre-trained model for predictions
   - Filipino food database
   - Nutrition guidelines

5. **Mobile App Features**
   - Health integration
   - Offline detection
   - Modern UI/UX

### Areas for Improvement ⚠️

1. **Code Size**
   - `app.py` is very large (9,193 lines)
   - Should be split into blueprints/modules
   - Consider: `auth.py`, `food.py`, `exercise.py`, `progress.py`, `ai.py`

2. **Testing**
   - Limited test coverage visible
   - Only a few test files in `nutrition_flutter/test/`
   - No backend test files visible

3. **Error Handling**
   - Some endpoints may need more robust error handling
   - Consider centralized error handling middleware

4. **API Documentation**
   - No OpenAPI/Swagger documentation
   - Consider adding API documentation endpoint

5. **Database Migrations**
   - Multiple migration scripts present
   - Consider using Flask-Migrate for version control

6. **Code Duplication**
   - Some repeated patterns in endpoints
   - Could benefit from helper functions/decorators

7. **Configuration Management**
   - Hardcoded API keys in some places
   - Should all be environment variables

8. **Logging**
   - Limited structured logging
   - Consider adding proper logging framework

---

## 🔍 Security Analysis

### Security Features ✅
- Password hashing (Werkzeug)
- Email verification for sensitive operations
- CORS configuration
- Environment variable usage
- SQL injection protection (SQLAlchemy)

### Security Concerns ⚠️
1. **Hardcoded API Key**
   - `config.py` has a default ExerciseDB API key
   - Should be removed or clearly marked as example

2. **Secret Key**
   - Default secret key in development
   - Should enforce strong secret in production

3. **CORS**
   - Default allows all origins (`*`)
   - Should restrict in production

4. **Rate Limiting**
   - No visible rate limiting
   - Consider adding for API endpoints

5. **Input Validation**
   - Some endpoints may need more validation
   - Consider using Flask-WTF or similar

---

## 📈 Performance Considerations

1. **Database Queries**
   - Some endpoints may have N+1 query issues
   - Consider eager loading where needed

2. **ML Model Loading**
   - Model loaded on startup
   - Good for performance, but increases memory

3. **Caching**
   - No visible caching strategy
   - Consider Redis for frequently accessed data

4. **API Response Size**
   - Some endpoints return large datasets
   - Consider pagination

---

## 🎓 Learning Resources

The repository includes extensive documentation:
- `START_HERE.md` - Getting started guide
- `QUICK_START.md` - Quick setup
- `TESTING_GUIDE.md` - Testing instructions
- `UNIT_TESTING_GUIDE.md` - Unit testing guide
- Multiple deployment guides
- Implementation summaries

---

## 🚦 Recommendations

### High Priority
1. **Refactor `app.py`** - Split into blueprints
2. **Add API Documentation** - OpenAPI/Swagger
3. **Improve Testing** - Add backend tests
4. **Remove Hardcoded Keys** - Use environment variables only
5. **Add Rate Limiting** - Protect API endpoints

### Medium Priority
1. **Add Logging** - Structured logging framework
2. **Database Migrations** - Use Flask-Migrate
3. **Add Caching** - Redis for performance
4. **Input Validation** - Use validation library
5. **Error Handling** - Centralized error handling

### Low Priority
1. **Code Documentation** - Add docstrings
2. **Type Hints** - Add type hints to Python code
3. **CI/CD** - Add GitHub Actions
4. **Monitoring** - Add application monitoring
5. **Performance Testing** - Load testing

---

## 📝 Conclusion

This is a **well-featured, production-ready application** with:
- ✅ Comprehensive functionality
- ✅ Good documentation
- ✅ Multiple deployment options
- ✅ Modern tech stack
- ⚠️ Needs refactoring for maintainability
- ⚠️ Needs better testing coverage
- ⚠️ Security improvements recommended

**Overall Assessment:** Solid foundation with room for architectural improvements and enhanced testing.

---

## 🔗 Key Files Reference

- **Backend Entry:** `app.py`
- **ML Model:** `nutrition_model.py`
- **Config:** `config.py`
- **Email Service:** `email_service.py`
- **Flutter Entry:** `nutrition_flutter/lib/main.dart`
- **Flutter Config:** `nutrition_flutter/lib/config.dart`
- **Docker:** `Dockerfile`
- **Requirements:** `requirements.txt`
- **Flutter Dependencies:** `nutrition_flutter/pubspec.yaml`

---

*Analysis generated: January 2025*

