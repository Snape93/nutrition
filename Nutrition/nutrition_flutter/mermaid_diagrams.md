# Mermaid Diagrams for Nutrition App

## 1. User Authentication Sequence Diagram

```mermaid
sequenceDiagram
    participant U as User
    participant A as App
    participant DB as Database
    participant API as Backend API

    U->>A: Open App
    A->>U: Show Landing Screen
    
    alt Login Flow
        U->>A: Enter Credentials
        A->>DB: Query User Data
        DB-->>A: Return User Info
        A->>API: Validate Credentials
        API-->>A: Authentication Result
        A->>U: Navigate to Home/Dashboard
    else Registration Flow
        U->>A: Fill Registration Form
        A->>DB: Check Email/Username
        DB-->>A: Availability Status
        A->>DB: Create New User
        DB-->>A: User Created
        A->>U: Show Profile Setup
    end
```

## 2. Food Logging Process Flow

```mermaid
flowchart TD
    A[User Opens Food Logging] --> B{Manual Entry or API?}
    B -->|Manual| C[Enter Food Name]
    B -->|API| D[Search Food Database]
    
    C --> E[Enter Calories]
    C --> F[Enter Portion Size]
    C --> G[Add Notes]
    
    D --> H[Select Food Item]
    H --> I[API Returns Nutrition Data]
    I --> J[Auto-fill Nutrition Info]
    
    E --> K[Save to Database]
    F --> K
    G --> K
    J --> K
    
    K --> L[Update Daily Totals]
    L --> M[Show Success Message]
    M --> N[Return to Dashboard]
```

## 3. API Integration Architecture

```mermaid
graph TB
    subgraph "Flutter App"
        A[UI Layer]
        B[Business Logic]
        C[Data Layer]
    end
    
    subgraph "Backend API"
        D[Flask Server]
        E[ML Model]
        F[Database]
    end
    
    subgraph "External APIs"
        G[Nutrition API]
        H[Food Database]
    end
    
    A --> B
    B --> C
    C --> D
    D --> E
    D --> F
    D --> G
    D --> H
    
    style A fill:#e1f5fe
    style D fill:#f3e5f5
    style G fill:#fff3e0
    style H fill:#fff3e0
```

## 4. Database Schema Diagram

```mermaid
erDiagram
    USERS {
        int id PK
        string username
        string email
        string password_hash
        string full_name
        int age
        string sex
        float height
        float weight
        string activity_level
        string goal
        string dietary_preferences
        string medical_history
        string lifestyle_factors
        int daily_calorie_goal
        boolean tutorial_completed
        datetime created_at
        datetime updated_at
    }
    
    FOOD_LOGS {
        int id PK
        int user_id FK
        string food_name
        float calories
        float protein
        float carbs
        float fat
        float fiber
        string portion_size
        string notes
        datetime logged_at
        datetime created_at
    }
    
    EXERCISE_LOGS {
        int id PK
        int user_id FK
        string exercise_name
        int duration_minutes
        float calories_burned
        string notes
        datetime logged_at
        datetime created_at
    }
    
    USERS ||--o{ FOOD_LOGS : "logs"
    USERS ||--o{ EXERCISE_LOGS : "logs"
```

## 5. User Journey Flow

```mermaid
journey
    title Nutrition App User Journey
    section First Time User
      Download App: 5: User
      Open App: 4: User
      Create Account: 3: User
      Complete Profile: 2: User
      Watch Tutorial: 1: User
    section Daily Usage
      Log Food: 5: User
      Check Progress: 4: User
      Update Goals: 3: User
      View Analytics: 2: User
    section Weekly Review
      Review Progress: 4: User
      Adjust Goals: 3: User
      Plan Meals: 2: User
```

## 6. State Management Flow

```mermaid
stateDiagram-v2
    [*] --> AppLaunch
    AppLaunch --> Authentication
    Authentication --> ProfileSetup : New User
    Authentication --> HomeScreen : Existing User
    ProfileSetup --> Tutorial
    Tutorial --> HomeScreen
    HomeScreen --> FoodLogging
    HomeScreen --> ProfileView
    HomeScreen --> Settings
    FoodLogging --> HomeScreen
    ProfileView --> ProfileEdit
    ProfileEdit --> HomeScreen
    Settings --> HomeScreen
    HomeScreen --> Authentication : Logout
```

## 7. Error Handling Flow

```mermaid
flowchart TD
    A[User Action] --> B{Validation}
    B -->|Pass| C[Process Action]
    B -->|Fail| D[Show Error Message]
    
    C --> E{API Call}
    E -->|Success| F[Update UI]
    E -->|Network Error| G[Show Network Error]
    E -->|Server Error| H[Show Server Error]
    E -->|Timeout| I[Show Timeout Error]
    
    D --> J[User Retry]
    G --> J
    H --> J
    I --> J
    
    J --> A
    
    style D fill:#ffebee
    style G fill:#ffebee
    style H fill:#ffebee
    style I fill:#ffebee
```

## 8. Data Flow Architecture

```mermaid
graph LR
    subgraph "Frontend (Flutter)"
        A[UI Components]
        B[State Management]
        C[Local Storage]
    end
    
    subgraph "Backend (Python/Flask)"
        D[API Endpoints]
        E[Business Logic]
        F[ML Models]
        G[Database]
    end
    
    subgraph "External Services"
        H[Nutrition APIs]
        I[Authentication]
    end
    
    A --> B
    B --> C
    A --> D
    D --> E
    E --> F
    E --> G
    E --> H
    E --> I
    
    style A fill:#e8f5e8
    style D fill:#f3e5f5
    style H fill:#fff3e0
```

## 9. Feature Dependency Graph

```mermaid
graph TD
    A[User Authentication] --> B[Profile Management]
    A --> C[Food Logging]
    A --> D[Progress Tracking]
    
    B --> E[Calorie Goal Calculation]
    C --> F[Daily Totals]
    C --> G[Nutrition Analysis]
    
    E --> H[Dashboard]
    F --> H
    G --> H
    
    D --> I[Analytics]
    H --> I
    
    style A fill:#e1f5fe
    style H fill:#f3e5f5
    style I fill:#fff3e0
```

## 10. API Endpoint Structure

```mermaid
graph TB
    subgraph "Authentication"
        A1[POST /auth/register]
        A2[POST /auth/login]
        A3[POST /auth/forgot-password]
    end
    
    subgraph "User Management"
        B1[GET /user/profile]
        B2[PUT /user/profile]
        B3[POST /user/calculate-goal]
    end
    
    subgraph "Food & Nutrition"
        C1[POST /predict/calories]
        C2[POST /predict/nutrition]
        C3[GET /foods/filipino]
        C4[POST /log/food]
    end
    
    subgraph "Analytics"
        D1[GET /analytics/progress]
        D2[POST /analyze/food-log]
        D3[GET /recommend/meals]
    end
    
    subgraph "Health"
        E1[GET /health]
        E2[POST /log/exercise]
    end
    
    style A1 fill:#e8f5e8
    style C1 fill:#f3e5f5
    style D1 fill:#fff3e0
```

## Usage Instructions

To use these Mermaid diagrams:

1. **Copy the code** between the ```mermaid blocks
2. **Paste into** any Mermaid-compatible editor:
   - GitHub (in markdown files)
   - GitLab
   - Notion
   - Mermaid Live Editor (https://mermaid.live)
   - VS Code with Mermaid extension

3. **Customize** the diagrams by:
   - Changing colors (style fill:#color)
   - Adding/modifying nodes and connections
   - Updating text and labels
   - Adjusting layout and flow

4. **Export** as PNG, SVG, or PDF from the Mermaid Live Editor 