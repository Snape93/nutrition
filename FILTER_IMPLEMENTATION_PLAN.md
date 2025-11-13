# Food Preference Filtering Implementation Plan

## Overview
Implement real-time multi-select food preference filtering in the Food Log screen, allowing users to filter recommendations by selecting one or more preferences (Healthy, Comfort Food, Spicy, Sweet Tooth, Protein Lover, Plant-Based).

---

## Phase 1: Frontend UI (Flutter) - Filter Chip Interface

### 1.1 Add Filter State Management
**File:** `lib/food_log_screen.dart`

**Add to State Class:**
```dart
Set<String> _selectedFilters = {}; // Stores active filter selections
bool _showFilters = true; // Toggle to show/hide filter section
```

### 1.2 Create Filter Chip Widget
**Add Method:**
```dart
Widget _buildFilterChips() {
  final filterOptions = [
    {'label': 'Healthy', 'value': 'healthy', 'emoji': '🥗', 'color': Colors.green},
    {'label': 'Comfort Food', 'value': 'comfort', 'emoji': '🍕', 'color': Colors.orange},
    {'label': 'Spicy', 'value': 'spicy', 'emoji': '🌶️', 'color': Colors.red},
    {'label': 'Sweet Tooth', 'value': 'sweet', 'emoji': '🍰', 'color': Colors.pink},
    {'label': 'Protein Lover', 'value': 'protein', 'emoji': '🥩', 'color': Colors.brown},
    {'label': 'Plant-Based', 'value': 'plant_based', 'emoji': '🥕', 'color': Colors.green.shade700},
  ];

  return Wrap(
    spacing: 8.0,
    runSpacing: 8.0,
    children: filterOptions.map((filter) {
      final isSelected = _selectedFilters.contains(filter['value']);
      return FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(filter['emoji']!),
            SizedBox(width: 4),
            Text(filter['label']!),
          ],
        ),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            if (selected) {
              _selectedFilters.add(filter['value']!);
            } else {
              _selectedFilters.remove(filter['value']!);
            }
            // Auto-refresh recommendations when filters change
            fetchRecommendedFoods();
          });
        },
        selectedColor: filter['color'] as Color,
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      );
    }).toList(),
  );
}
```

### 1.3 Update UI Layout
**Location:** In the `build()` method, add filter section above recommendations

```dart
// Add filter section
Container(
  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Filter by Preference',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _primaryColor,
            ),
          ),
          IconButton(
            icon: Icon(_showFilters ? Icons.expand_less : Icons.expand_more),
            onPressed: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
          ),
        ],
      ),
      if (_showFilters) _buildFilterChips(),
      if (_selectedFilters.isNotEmpty)
        Padding(
          padding: EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Text(
                '${_selectedFilters.length} filter(s) active',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedFilters.clear();
                    fetchRecommendedFoods();
                  });
                },
                child: Text('Clear All'),
              ),
            ],
          ),
        ),
    ],
  ),
),
```

### 1.4 Update API Call with Filters
**Modify `fetchRecommendedFoods()` method:**

```dart
Future<void> fetchRecommendedFoods() async {
  if (!mounted) return;
  setState(() {
    _isLoadingRecommendations = true;
    _recommendationError = null;
  });
  
  try {
    final user = widget.usernameOrEmail;
    final mealType = _selectedMeal?.toLowerCase() ?? 'breakfast';
    
    // Build URL with optional filter parameters
    final uriBuilder = Uri.parse('$apiBase/foods/recommend');
    final queryParams = <String, String>{
      'user': user,
      'meal_type': mealType,
    };
    
    // Add filters if any selected
    if (_selectedFilters.isNotEmpty) {
      queryParams['filters'] = _selectedFilters.join(',');
    }
    
    final uri = uriBuilder.replace(queryParameters: queryParams);
    
    debugPrint('DEBUG: [Food Recommendations] Starting request');
    debugPrint('DEBUG: [Food Recommendations] User: $user');
    debugPrint('DEBUG: [Food Recommendations] Meal Type: $mealType');
    debugPrint('DEBUG: [Food Recommendations] Selected Filters: $_selectedFilters');
    debugPrint('DEBUG: [Food Recommendations] API URL: $uri');
    
    // ... rest of existing code
  }
}
```

---

## Phase 2: Backend API Enhancement (Python/Flask)

### 2.1 Update `/foods/recommend` Endpoint
**File:** `app.py` (around line 2920)

**Add Filter Parameter Parsing:**
```python
@app.route('/foods/recommend')
def foods_recommend():
    """Compatibility endpoint for the Flutter UI to fetch recommended foods.

    Query params: 
        - user: username
        - meal_type: breakfast|lunch|dinner|snacks
        - filters: comma-separated list (e.g., "healthy,spicy,protein")
    Returns: { recommended: [ { name, calories, ... } ] }
    """
    try:
        username = request.args.get('user')
        meal_type = (request.args.get('meal_type') or 'breakfast').lower()
        
        # Parse active filters from query params (real-time selections)
        filters_param = request.args.get('filters', '')
        active_filters = []
        if filters_param:
            active_filters = [f.strip().lower() for f in filters_param.split(',') if f.strip()]
        
        if not username:
            return jsonify({'recommended': []}), 200

        user_obj = User.query.filter_by(username=username).first()
        if not user_obj:
            return jsonify({'recommended': []}), 200

        # Parse saved user preferences from DB (from onboarding)
        def parse_list(val):
            if not val or val == '[]':
                return []
            try:
                return eval(val) if val.startswith('[') else val.split(',')
            except:
                return []
        
        saved_preferences = parse_list(getattr(user_obj, 'dietary_preferences', None) or 
                                       getattr(user_obj, 'diet_type', None) or [])
        
        # Priority: Use active_filters if provided, otherwise fall back to saved preferences
        # If both exist, combine them (active filters take precedence)
        if active_filters:
            all_preferences = active_filters
        else:
            all_preferences = saved_preferences
        
        debug_print(f"DEBUG: [Food Recommendations] Active filters: {active_filters}")
        debug_print(f"DEBUG: [Food Recommendations] Saved preferences: {saved_preferences}")
        debug_print(f"DEBUG: [Food Recommendations] Combined preferences: {all_preferences}")
        
        # Continue with existing recommendation logic...
        rec = nutrition_model.recommend_meals(
            user_gender=user_obj.sex or 'male',
            user_age=int(user_obj.age),
            user_weight=float(user_obj.weight_kg),
            user_height=float(user_obj.height_cm),
            user_activity_level=str(user_obj.activity_level),
            user_goal=str(user_obj.goal),
            dietary_preferences=all_preferences,
            medical_history=parse_list(getattr(user_obj, 'medical_history', None) or [])
        )
        
        # Apply additional filtering based on active filters
        foods = rec.get('meal_plan', {}).get(meal_type, {}).get('foods', [])
        
        # Filter and score foods based on active filters
        filtered_foods = _apply_preference_filtering(
            foods, 
            active_filters, 
            meal_type,
            user_obj
        )
        
        # ... rest of existing scoring logic
```

### 2.2 Create Smart Filtering Function
**File:** `app.py` (add new function)

```python
def _apply_preference_filtering(foods_list, active_filters, meal_type, user_obj):
    """
    Apply intelligent filtering when multiple preferences are selected.
    
    Strategy:
    - Plant-Based: Hard exclusion (remove meats, dairy if selected)
    - Other filters: Scoring system (foods matching more filters score higher)
    - If no filters: Return all foods
    """
    if not active_filters:
        return foods_list
    
    # Normalize filters
    filters_lower = [f.lower().strip() for f in active_filters]
    
    # Hard exclusions for plant_based
    plant_based = 'plant_based' in filters_lower or 'plant-based' in filters_lower
    
    filtered = []
    food_df = nutrition_model.food_df  # Access food database
    
    for food_name in foods_list:
        # Normalize food name
        food_name_normalized = food_name.lower().replace('_', ' ').replace('-', ' ').strip()
        
        # Try to get food data
        food_row = food_df[
            food_df['Food Name'].str.lower().str.replace('_', ' ', regex=False)
            .str.replace('-', ' ', regex=False).str.strip() == food_name_normalized
        ]
        
        if food_row.empty:
            # Fallback: use name-based heuristics
            food_category = _infer_category_from_name(food_name_normalized)
        else:
            food_category = food_row.iloc[0].get('Category', '').lower()
            calories = food_row.iloc[0].get('Calories', 0)
            protein = food_row.iloc[0].get('Protein (g)', 0)
        else:
            # Use heuristics
            food_category = _infer_category_from_name(food_name_normalized)
            calories = 0
            protein = 0
        
        # Hard exclusion: Plant-based
        if plant_based:
            meat_keywords = ['chicken', 'pork', 'beef', 'fish', 'meat', 'egg', 'seafood']
            if any(kw in food_name_normalized for kw in meat_keywords) or food_category == 'meats':
                continue
        
        # Calculate match score for other filters
        match_score = 0
        matched_filters = []
        
        # Healthy filter
        if 'healthy' in filters_lower:
            if food_category in ['vegetables', 'fruits', 'grains'] or \
               'salad' in food_name_normalized or 'vegetable' in food_name_normalized:
                match_score += 2
                matched_filters.append('healthy')
            elif calories > 0 and calories < 200:
                match_score += 1
                matched_filters.append('healthy')
        
        # Comfort food filter
        if 'comfort' in filters_lower:
            comfort_keywords = ['rice', 'noodles', 'soup', 'stew', 'adobo', 'sinigang']
            if any(kw in food_name_normalized for kw in comfort_keywords):
                match_score += 2
                matched_filters.append('comfort')
        
        # Spicy filter
        if 'spicy' in filters_lower:
            spicy_keywords = ['spicy', 'sili', 'chili', 'curry', 'sinigang', 'ginataang']
            if any(kw in food_name_normalized for kw in spicy_keywords):
                match_score += 2
                matched_filters.append('spicy')
        
        # Sweet filter
        if 'sweet' in filters_lower:
            sweet_keywords = ['sweet', 'cake', 'dessert', 'mango', 'banana', 'sugar']
            if food_category == 'fruits' or any(kw in food_name_normalized for kw in sweet_keywords):
                match_score += 2
                matched_filters.append('sweet')
        
        # Protein filter
        if 'protein' in filters_lower:
            if protein > 10 or food_category in ['meats', 'protein'] or \
               any(kw in food_name_normalized for kw in ['chicken', 'pork', 'beef', 'egg', 'tofu']):
                match_score += 2
                matched_filters.append('protein')
        
        # Only include foods that match at least one filter (or all if user wants strict AND)
        # Strategy: If multiple filters selected, require at least 50% match
        non_plant_filters = [f for f in filters_lower if f not in ['plant_based', 'plant-based']]
        
        if non_plant_filters:
            min_matches_required = max(1, len(non_plant_filters) // 2)  # At least 50% match
            if match_score < min_matches_required:
                continue
        
        filtered.append({
            'name': food_name,
            'match_score': match_score,
            'matched_filters': matched_filters,
        })
    
    # Sort by match score (higher = better match)
    filtered.sort(key=lambda x: x['match_score'], reverse=True)
    
    # Return just the food names, sorted by relevance
    return [f['name'] for f in filtered]

def _infer_category_from_name(food_name):
    """Infer food category from name (fallback when not in database)"""
    name_lower = food_name.lower()
    
    if any(kw in name_lower for kw in ['chicken', 'pork', 'beef', 'fish', 'meat']):
        return 'meats'
    elif any(kw in name_lower for kw in ['rice', 'noodles', 'bread']):
        return 'staple'
    elif any(kw in name_lower for kw in ['mango', 'banana', 'apple', 'papaya']):
        return 'fruits'
    elif any(kw in name_lower for kw in ['vegetable', 'salad', 'ampalaya', 'malunggay']):
        return 'vegetables'
    else:
        return ''
```

---

## Phase 3: Enhanced Filtering Logic

### 3.1 Filter Combination Strategies

**Option A: AND Logic (Strict)**
- User selects: Healthy + Spicy
- Result: Only foods that are BOTH healthy AND spicy
- Use when: `filters_param` includes `strict=true`

**Option B: OR Logic (Relaxed) - DEFAULT**
- User selects: Healthy + Spicy  
- Result: Foods that are EITHER healthy OR spicy (prioritized by match score)
- Better for: Getting more results when multiple filters selected

**Option C: Hybrid (Recommended)**
- Plant-based: Hard exclusion (AND)
- Others: Scoring system (OR with priority)
- Foods matching more filters appear higher in results

### 3.2 Implementation

**In `_apply_preference_filtering()` function:**

```python
def _apply_preference_filtering(foods_list, active_filters, meal_type, user_obj, strict_mode=False):
    """
    strict_mode: If True, use AND logic (all filters must match)
                 If False, use OR logic with scoring (default)
    """
    # ... existing code ...
    
    if strict_mode:
        # AND Logic: Food must match ALL selected filters
        for food_name in foods_list:
            matches_all = True
            for filter_type in filters_lower:
                if not _food_matches_filter(food_name, filter_type):
                    matches_all = False
                    break
            if matches_all:
                filtered.append(food_name)
    else:
        # OR Logic with Scoring: Food can match ANY filter, sorted by score
        # ... existing scoring logic ...
```

---

## Phase 4: UI/UX Enhancements

### 4.1 Visual Feedback
- Selected filters: Highlighted with color
- Loading state: Show spinner when filters change
- Empty state: Show message when no foods match filters

### 4.2 Filter Persistence (Optional)
- Save last selected filters to local storage
- Restore on screen load
- OR: Always start with saved preferences from onboarding

### 4.3 Filter Count Display
```dart
if (_selectedFilters.isNotEmpty)
  Chip(
    label: Text('${_selectedFilters.length} active'),
    avatar: Icon(Icons.filter_list),
  ),
```

---

## Phase 5: Testing Checklist

### 5.1 Frontend Tests
- [ ] Single filter selection works
- [ ] Multiple filter selection works
- [ ] Filter deselection works
- [ ] Clear all button works
- [ ] API call includes correct filter parameters
- [ ] Loading state shows during filter change
- [ ] Empty state shows when no results

### 5.2 Backend Tests
- [ ] No filters: Returns all recommendations
- [ ] Single filter: Returns filtered results
- [ ] Multiple filters: Returns scored/sorted results
- [ ] Plant-based: Excludes meats correctly
- [ ] Filter parameter parsing handles edge cases
- [ ] Debug logs show correct filter values

### 5.3 Integration Tests
- [ ] Filter + Meal Type combination works
- [ ] Filter + Search combination works
- [ ] Filter persistence across app restarts (if implemented)
- [ ] Performance: Filtering doesn't slow down recommendations

---

## Phase 6: Performance Optimizations

### 6.1 Debouncing
**Add to Flutter:**
```dart
Timer? _filterDebounceTimer;

void _onFilterChanged() {
  _filterDebounceTimer?.cancel();
  _filterDebounceTimer = Timer(Duration(milliseconds: 500), () {
    fetchRecommendedFoods();
  });
}
```

### 6.2 Caching
- Cache filtered results per filter combination
- Invalidate cache when user data changes
- Use cached results if filters haven't changed

### 6.3 Backend Optimization
- Pre-index foods by category/tags
- Use database queries instead of in-memory filtering for large datasets

---

## Implementation Order

1. **Week 1: Frontend UI** (Phase 1)
   - Add filter chips
   - Wire up state management
   - Update API calls

2. **Week 2: Backend Enhancement** (Phase 2)
   - Update endpoint to accept filters
   - Implement smart filtering function
   - Add debug logging

3. **Week 3: Testing & Refinement** (Phases 3-4)
   - Test filter combinations
   - Refine scoring logic
   - UI/UX polish

4. **Week 4: Optimization** (Phase 6)
   - Performance tuning
   - Edge case handling
   - Documentation

---

## Expected User Experience

1. User opens Food Log screen
2. Sees 6 filter chips above recommendations
3. Taps "Healthy" and "Spicy"
4. Recommendations refresh automatically
5. Results show foods that match healthy OR spicy (prioritized by match score)
6. User can tap filters again to deselect
7. "Clear All" resets to default recommendations

---

## Notes

- **Filter Values:** Must match exactly: `healthy`, `comfort`, `spicy`, `sweet`, `protein`, `plant_based`
- **Backward Compatibility:** Existing API calls without filters continue to work
- **Default Behavior:** If no filters selected, use saved preferences from onboarding (if any)



