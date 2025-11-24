import joblib
import numpy as np
import pandas as pd
import os
import sqlite3
from typing import Dict, List, Optional, Tuple
import json
from datetime import datetime
from collections import defaultdict

class NutritionModel:
    def __init__(self, model_path: str = "model/best_regression_model.joblib"):
        """
        Initialize the Nutrition Model with the pre-trained regression model
        
        Args:
            model_path: Path to the saved joblib model file
        """
        self.model_path = model_path
        self.model = None
        self.model_loaded = False
        self.filipino_foods_db = self._load_filipino_foods()
        self.expanded_filipino_foods = self._load_expanded_filipino_foods()
        self.nutrition_guidelines = self._load_nutrition_guidelines()
        
        # Monitoring and logging
        self.ml_usage_stats = {
            'total_predictions': 0,
            'ml_predictions': 0,
            'database_lookups': 0,
            'rule_based_predictions': 0,
            'ml_rejections': 0,
            'average_confidence': 0.0,
            'confidence_sum': 0.0,
            'predictions_by_category': defaultdict(int),
            'predictions_by_method': defaultdict(int)
        }
        self.ml_log_file = "instance/ml_predictions_log.jsonl"
        self._ensure_log_directory()
        
        # Load the model
        self._load_model()
    
    def _ensure_log_directory(self):
        """Ensure the log directory exists"""
        log_dir = os.path.dirname(self.ml_log_file)
        if log_dir and not os.path.exists(log_dir):
            os.makedirs(log_dir, exist_ok=True)
    
    def _load_model(self):
        """Load the pre-trained regression model"""
        try:
            if os.path.exists(self.model_path):
                self.model = joblib.load(self.model_path)
                self.model_loaded = True
                print(f"[SUCCESS] Model loaded successfully from {self.model_path}")
            else:
                print(f"[WARNING] Model file not found at {self.model_path}")
                self.model_loaded = False
        except Exception as e:
            print(f"[ERROR] Error loading model: {str(e)}")
            self.model_loaded = False
    
    def _log_prediction(self, food_name: str, method: str, calories: float, 
                       confidence: float = None, category: str = None, 
                       ml_prediction: float = None, rule_based_pred: float = None):
        """Log prediction for monitoring and analysis"""
        try:
            log_entry = {
                'timestamp': datetime.now().isoformat(),
                'food_name': food_name,
                'method': method,
                'calories': calories,
                'confidence': confidence,
                'category': category,
                'ml_prediction': ml_prediction,
                'rule_based_prediction': rule_based_pred
            }
            
            # Append to log file
            with open(self.ml_log_file, 'a', encoding='utf-8') as f:
                f.write(json.dumps(log_entry) + '\n')
        except Exception as e:
            # Don't fail if logging fails
            pass
    
    def get_usage_stats(self) -> Dict:
        """Get ML model usage statistics"""
        stats = self.ml_usage_stats.copy()
        total = stats['total_predictions']
        
        if total > 0:
            stats['ml_usage_percentage'] = round((stats['ml_predictions'] / total) * 100, 2)
            stats['database_usage_percentage'] = round((stats['database_lookups'] / total) * 100, 2)
            stats['rule_based_usage_percentage'] = round((stats['rule_based_predictions'] / total) * 100, 2)
            
            if stats['ml_predictions'] > 0:
                stats['average_confidence'] = round(stats['confidence_sum'] / stats['ml_predictions'], 3)
            else:
                stats['average_confidence'] = 0.0
        else:
            stats['ml_usage_percentage'] = 0.0
            stats['database_usage_percentage'] = 0.0
            stats['rule_based_usage_percentage'] = 0.0
            stats['average_confidence'] = 0.0
        
        return stats
    
    def reset_stats(self):
        """Reset usage statistics (useful for testing or periodic resets)"""
        self.ml_usage_stats = {
            'total_predictions': 0,
            'ml_predictions': 0,
            'database_lookups': 0,
            'rule_based_predictions': 0,
            'ml_rejections': 0,
            'average_confidence': 0.0,
            'confidence_sum': 0.0,
            'predictions_by_category': defaultdict(int),
            'predictions_by_method': defaultdict(int)
        }
    
    def is_model_loaded(self) -> bool:
        """Check if the model is loaded successfully"""
        return self.model_loaded
    
    def _load_expanded_filipino_foods(self) -> List[Dict]:
        """Load expanded Filipino food database from SQLite"""
        try:
            db_path = os.path.join("data", "filipino_foods.db")
            if not os.path.exists(db_path):
                print(f"⚠️ Expanded Filipino foods database not found at {db_path}")
                return []
            
            conn = sqlite3.connect(db_path)
            cursor = conn.cursor()
            
            cursor.execute("""
                SELECT food_name_english, food_name_filipino, food_group, meal_category,
                       energy_kcal, protein_g, fat_total_g, carbohydrates_g, 
                       dietary_fiber_g, calcium_mg, iron_mg, vitamin_c_mg,
                       serving_size_g, household_measure, data_source
                FROM filipino_foods
            """)
            
            foods = []
            for row in cursor.fetchall():
                food = {
                    "name_english": row[0],
                    "name_filipino": row[1],
                    "food_group": row[2],
                    "meal_category": row[3],
                    "calories_per_100g": row[4] or 0,
                    "protein": row[5] or 0,
                    "fat": row[6] or 0,
                    "carbs": row[7] or 0,
                    "fiber": row[8] or 0,
                    "calcium": row[9] or 0,
                    "iron": row[10] or 0,
                    "vitamin_c": row[11] or 0,
                    "serving_size": row[12] or 100,
                    "household_measure": row[13],
                    "data_source": row[14]
                }
                foods.append(food)
            
            conn.close()
            print(f"[SUCCESS] Loaded {len(foods)} foods from expanded Filipino database")
            return foods
            
        except Exception as e:
            print(f"[ERROR] Error loading expanded Filipino foods: {e}")
            return []

    def _load_filipino_foods(self) -> Dict:
        """Load Filipino food database with nutrition information (legacy format)"""
        return {
            # Main Dishes
            "adobo": {
                "category": "meats",
                "calories_per_100g": 320,
                "protein": 25.0,
                "fat": 18.0,
                "carbs": 8.0,
                "iron": 2.5,
                "calcium": 45.0,
                "vitamin_c": 2.0,
                "fiber": 1.5,
                "preparation_methods": ["fried", "braised", "grilled"]
            },
            "sinigang": {
                "category": "soups",
                "calories_per_100g": 180,
                "protein": 15.0,
                "fat": 8.0,
                "carbs": 12.0,
                "iron": 3.2,
                "calcium": 85.0,
                "vitamin_c": 25.0,
                "fiber": 4.5,
                "preparation_methods": ["boiled", "simmered"]
            },
            "kare_kare": {
                "category": "meats",
                "calories_per_100g": 380,
                "protein": 22.0,
                "fat": 25.0,
                "carbs": 15.0,
                "iron": 4.1,
                "calcium": 120.0,
                "vitamin_c": 8.0,
                "fiber": 3.0,
                "preparation_methods": ["braised", "stewed"]
            },
            "tinolang_manok": {
                "category": "soups",
                "calories_per_100g": 220,
                "protein": 28.0,
                "fat": 10.0,
                "carbs": 8.0,
                "iron": 2.8,
                "calcium": 65.0,
                "vitamin_c": 15.0,
                "fiber": 2.5,
                "preparation_methods": ["boiled", "simmered"]
            },
            "ginisang_monggo": {
                "category": "legumes",
                "calories_per_100g": 160,
                "protein": 12.0,
                "fat": 2.0,
                "carbs": 25.0,
                "iron": 4.5,
                "calcium": 55.0,
                "vitamin_c": 5.0,
                "fiber": 8.0,
                "preparation_methods": ["boiled", "stewed"]
            },
            
            # Vegetables
            "ampalaya": {
                "category": "vegetables",
                "calories_per_100g": 20,
                "protein": 1.0,
                "fat": 0.2,
                "carbs": 4.0,
                "iron": 2.8,
                "calcium": 25.0,
                "vitamin_c": 85.0,
                "fiber": 2.5,
                "preparation_methods": ["stir_fried", "boiled", "raw"]
            },
            "malunggay": {
                "category": "vegetables",
                "calories_per_100g": 35,
                "protein": 2.5,
                "fat": 0.5,
                "carbs": 6.0,
                "iron": 4.0,
                "calcium": 185.0,
                "vitamin_c": 51.0,
                "fiber": 2.0,
                "preparation_methods": ["boiled", "stir_fried", "raw"]
            },
            "kangkong": {
                "category": "vegetables",
                "calories_per_100g": 25,
                "protein": 2.0,
                "fat": 0.3,
                "carbs": 4.0,
                "iron": 2.1,
                "calcium": 55.0,
                "vitamin_c": 35.0,
                "fiber": 2.5,
                "preparation_methods": ["stir_fried", "boiled"]
            },
            
            # Fruits
            "mango": {
                "category": "fruits",
                "calories_per_100g": 60,
                "protein": 0.8,
                "fat": 0.4,
                "carbs": 15.0,
                "iron": 0.2,
                "calcium": 10.0,
                "vitamin_c": 36.0,
                "fiber": 1.6,
                "preparation_methods": ["raw", "juiced"]
            },
            "papaya": {
                "category": "fruits",
                "calories_per_100g": 43,
                "protein": 0.5,
                "fat": 0.3,
                "carbs": 11.0,
                "iron": 0.3,
                "calcium": 20.0,
                "vitamin_c": 62.0,
                "fiber": 1.7,
                "preparation_methods": ["raw", "juiced"]
            },
            "saging_na_saba": {
                "category": "fruits",
                "calories_per_100g": 122,
                "protein": 1.3,
                "fat": 0.3,
                "carbs": 32.0,
                "iron": 0.3,
                "calcium": 5.0,
                "vitamin_c": 8.7,
                "fiber": 2.6,
                "preparation_methods": ["boiled", "fried", "raw"]
            },
            
            # Grains
            "white_rice": {
                "category": "grains",
                "calories_per_100g": 130,
                "protein": 2.7,
                "fat": 0.3,
                "carbs": 28.0,
                "iron": 0.2,
                "calcium": 10.0,
                "vitamin_c": 0.0,
                "fiber": 0.4,
                "preparation_methods": ["boiled", "steamed"]
            },
            "brown_rice": {
                "category": "grains",
                "calories_per_100g": 111,
                "protein": 2.6,
                "fat": 0.9,
                "carbs": 23.0,
                "iron": 0.4,
                "calcium": 10.0,
                "vitamin_c": 0.0,
                "fiber": 1.8,
                "preparation_methods": ["boiled", "steamed"]
            },
            "kamote": {
                "category": "grains",
                "calories_per_100g": 86,
                "protein": 1.6,
                "fat": 0.1,
                "carbs": 20.0,
                "iron": 0.7,
                "calcium": 30.0,
                "vitamin_c": 2.4,
                "fiber": 3.0,
                "preparation_methods": ["boiled", "baked", "fried"]
            }
        }
    
    def _load_nutrition_guidelines(self) -> Dict:
        """Load nutrition guidelines for different demographics"""
        return {
            "female": {
                "iron_daily": 18.0,  # mg
                "calcium_daily": 1000.0,  # mg
                "protein_daily": 46.0,  # g
                "fiber_daily": 25.0,  # g
                "vitamin_c_daily": 75.0,  # mg
                "calorie_multiplier": 0.9
            },
            "male": {
                "iron_daily": 8.0,  # mg
                "calcium_daily": 1000.0,  # mg
                "protein_daily": 56.0,  # g
                "fiber_daily": 38.0,  # g
                "vitamin_c_daily": 90.0,  # mg
                "calorie_multiplier": 1.0
            },
            "activity_levels": {
                "sedentary": 1.2,
                "lightly_active": 1.375,
                "moderate": 1.55,
                "very_active": 1.725
            }
        }
    
    def predict_calories(self, food_name: str, food_category: str = "", 
                        serving_size: float = 100, preparation_method: str = "",
                        ingredients: Optional[List[str]] = None) -> Dict:
        """
        Predict calories for a food item
        
        Args:
            food_name: Name of the food
            food_category: Category of the food
            serving_size: Serving size in grams
            preparation_method: How the food is prepared
            ingredients: List of ingredients
            
        Returns:
            Dictionary with prediction results
        """
        if not self.model_loaded:
            return {"error": "Model not loaded"}
        
        # Update statistics
        self.ml_usage_stats['total_predictions'] += 1
        
        # Check if it's a known Filipino food
        food_name_lower = food_name.lower().replace(" ", "_")
        if food_name_lower in self.filipino_foods_db:
            food_data = self.filipino_foods_db[food_name_lower]
            base_calories = food_data["calories_per_100g"]
            
            # Adjust for serving size
            predicted_calories = (base_calories * serving_size) / 100
            
            # Adjust for preparation method
            if preparation_method:
                predicted_calories = self._adjust_for_preparation(
                    predicted_calories, preparation_method
                )
            
            # Update stats
            self.ml_usage_stats['database_lookups'] += 1
            self.ml_usage_stats['predictions_by_method']['database_lookup'] += 1
            self.ml_usage_stats['predictions_by_category'][food_data["category"]] += 1
            
            result = {
                "calories": round(predicted_calories, 1),
                "confidence": 0.95,
                "method": "database_lookup",
                "food_name": food_name,
                "category": food_data["category"],
                "serving_size": serving_size
            }
        
            # Log prediction
            self._log_prediction(food_name, "database_lookup", predicted_calories, 
                               confidence=0.95, category=food_data["category"])
            
            return result
        
        # Use ML model for unknown foods, but validate predictions intelligently
        if ingredients is None:
            ingredients = []
        
        # Enhanced: Auto-detect preparation method from food name if not provided
        if not preparation_method:
            preparation_method = self._detect_preparation_from_name(food_name)
        
        # Enhanced: Extract ingredients from food name if not provided
        if not ingredients:
            ingredient_analysis = self._extract_ingredients_from_name(food_name)
            # Create a simple ingredient list based on detected ingredients
            detected_ingredients = []
            if ingredient_analysis['has_meat']:
                detected_ingredients.append('meat')
            if ingredient_analysis['has_vegetable']:
                detected_ingredients.append('vegetable')
            if ingredient_analysis['has_grain']:
                detected_ingredients.append('grain')
            # Use detected ingredients count for better feature preparation
            if detected_ingredients:
                ingredients = detected_ingredients
        
        # Get rule-based prediction for comparison (needed for validation)
        rule_based_pred = self._rule_based_calorie_prediction(
            food_name, food_category, serving_size
        )
        
        # Try ML model first, but validate the prediction with smarter logic
        ml_prediction = None
        ml_confidence = 0.85  # Default confidence for ML predictions
        try:
            if self.model is not None and hasattr(self.model, 'predict'):
                # Automatically detect which features to use based on model
                # Check if model expects 41 features (enhanced) or 13 features (basic)
                expected_features = None
                if hasattr(self.model, 'n_features_in_'):
                    expected_features = self.model.n_features_in_
                elif hasattr(self.model, 'feature_importances_'):
                    expected_features = len(self.model.feature_importances_)
                
                # Use enhanced features if model expects 41, otherwise use basic (13)
                if expected_features == 41:
                    # Model was trained with enhanced features (41)
                    try:
                        features = self._prepare_enhanced_features(
                            food_name, food_category, serving_size, preparation_method, ingredients
                        )
                    except Exception as e:
                        # Fallback to basic features if enhanced fails
                        print(f"[WARNING] Enhanced features failed, using basic: {e}")
                        features = self._prepare_features(
                            food_name, food_category, serving_size, preparation_method, ingredients
                        )
                else:
                    # Model expects 13 features (basic) or unknown - use basic features
                    features = self._prepare_features(
                        food_name, food_category, serving_size, preparation_method, ingredients
                    )
                
                # Make prediction
                ml_prediction = self.model.predict([features])[0]
                
                # Smarter validation logic:
                # 1. Only reject extreme outliers (>5000 kcal/100g is unrealistic for any food)
                # 2. For high-calorie foods, use category-specific thresholds
                # 3. Use weighted average for uncertain predictions instead of hard rejection
                
                # Category-specific maximums (kcal per 100g)
                category_max_calories = {
                    "meats": 600,      # High-fat meats can be very calorie-dense
                    "snacks": 550,     # Processed snacks can be high
                    "dairy": 400,      # Full-fat dairy products
                    "grains": 400,     # Some grain products
                    "legumes": 350,    # Legumes with added fats
                    "soups": 300,      # Creamy soups
                    "fruits": 150,     # Dried fruits are highest
                    "vegetables": 200  # Some prepared vegetables
                }
                
                # Determine category for validation
                validation_category = food_category.lower() if food_category else "meats"
                max_allowed = category_max_calories.get(validation_category, 500)  # Default 500
                
                # Reject only extreme outliers
                if ml_prediction > 5000:  # Absolute maximum (50 kcal/g is impossible)
                    ml_prediction = None
                    ml_confidence = 0.0
                elif ml_prediction > max_allowed * 2:  # More than 2x category max is suspicious
                    # Use weighted average instead of rejection
                    if rule_based_pred > 0:
                        # Weighted average: favor rule-based for extreme predictions
                        ml_prediction = 0.3 * ml_prediction + 0.7 * rule_based_pred
                        ml_confidence = 0.65  # Lower confidence for weighted predictions
                elif rule_based_pred > 0:
                    # Compare with rule-based prediction
                    ratio = ml_prediction / rule_based_pred if rule_based_pred > 0 else 1.0
                    
                    # If prediction is way off (more than 10x or less than 0.1x), use weighted average
                    if ratio > 10.0 or ratio < 0.1:
                        ml_prediction = 0.6 * ml_prediction + 0.4 * rule_based_pred
                        ml_confidence = 0.70  # Moderate confidence
                    # If prediction is reasonable but different, adjust confidence slightly
                    elif ratio > 3.0 or ratio < 0.33:
                        ml_confidence = 0.75  # Slightly lower confidence
                    # If predictions are close, high confidence
                    elif 0.8 <= ratio <= 1.2:
                        ml_confidence = 0.90  # High confidence when predictions agree
                    
        except Exception as e:
            ml_prediction = None  # ML model failed
            ml_confidence = 0.0
        
        # Use rule-based prediction if ML prediction is invalid or unavailable
        if ml_prediction is None:
            prediction = self._rule_based_calorie_prediction(
                food_name, food_category, serving_size
            )
            
            # Adjust for preparation method
            if preparation_method:
                prediction = self._adjust_for_preparation(prediction, preparation_method)
            
            # Update stats
            self.ml_usage_stats['rule_based_predictions'] += 1
            self.ml_usage_stats['predictions_by_method']['rule_based'] += 1
            if food_category:
                self.ml_usage_stats['predictions_by_category'][food_category] += 1
            
            result = {
                "calories": round(prediction, 1),
                "confidence": 0.70,
                "method": "rule_based",
                "food_name": food_name,
                "category": food_category,
                "serving_size": serving_size,
                "note": "Using rule-based prediction (ML model unavailable or prediction rejected)"
            }
            
            # Log prediction
            self._log_prediction(food_name, "rule_based", prediction, 
                               confidence=0.70, category=food_category)
            
            return result
        else:
            # ML prediction is valid, use it
            # ml_prediction is in calories per 100g, so scale by serving_size
            total_calories = (ml_prediction * serving_size) / 100
            
            # Adjust for preparation method
            if preparation_method:
                total_calories = self._adjust_for_preparation(total_calories, preparation_method)
            
            # Update stats
            self.ml_usage_stats['ml_predictions'] += 1
            self.ml_usage_stats['confidence_sum'] += ml_confidence
            self.ml_usage_stats['predictions_by_method']['ml_model'] += 1
            if food_category:
                self.ml_usage_stats['predictions_by_category'][food_category] += 1
            
            result = {
                "calories": round(total_calories, 1),
                "confidence": round(ml_confidence, 2),
                "method": "ml_model",
                "food_name": food_name,
                "category": food_category,
                "serving_size": serving_size,
                "calories_per_100g": round(ml_prediction, 1)  # Also return per 100g for reference
            }
            
            # Log prediction
            self._log_prediction(food_name, "ml_model", total_calories, 
                               confidence=ml_confidence, category=food_category,
                               ml_prediction=ml_prediction, rule_based_pred=rule_based_pred)
            
            return result
    
    def predict_nutrition(self, food_name: str, food_category: str = "",
                         serving_size: float = 100, user_gender: str = "",
                         user_age: int = 25, user_weight: float = 60,
                         user_height: float = 160, user_activity_level: str = "moderate",
                         user_goal: str = "maintain") -> Dict:
        """
        Predict comprehensive nutrition information with gender-specific insights
        
        Args:
            food_name: Name of the food
            food_category: Category of the food
            serving_size: Serving size in grams
            user_gender: User's gender
            user_age: User's age
            user_weight: User's weight in kg
            user_height: User's height in cm
            user_activity_level: Activity level
            user_goal: User's goal
            
        Returns:
            Dictionary with comprehensive nutrition information
        """
        # Get base nutrition info
        nutrition_info = self._get_nutrition_info(food_name, serving_size)
        
        # Calculate daily needs
        daily_needs = self._calculate_daily_needs(
            user_gender, user_age, user_weight, user_height, user_activity_level
        )
        
        # Add gender-specific insights
        gender_insights = self._get_gender_insights(
            nutrition_info, daily_needs, user_gender, user_goal
        )
        
        # Add goal-specific recommendations
        goal_recommendations = self._get_goal_recommendations(
            nutrition_info, daily_needs, user_goal
        )
        
        return {
            "nutrition_info": nutrition_info,
            "daily_needs": daily_needs,
            "gender_insights": gender_insights,
            "goal_recommendations": goal_recommendations,
            "serving_size": serving_size,
            "food_name": food_name
        }
    
    def recommend_meals(self, user_gender: str, user_age: int, user_weight: float,
                       user_height: float, user_activity_level: str, user_goal: str,
                       dietary_preferences: Optional[List[str]] = None, medical_history: Optional[List[str]] = None) -> Dict:
        """
        Generate meal recommendations based on user profile
        
        Args:
            user_gender: User's gender
            user_age: User's age
            user_weight: User's weight in kg
            user_height: User's height in cm
            user_activity_level: Activity level
            user_goal: User's goal
            dietary_preferences: List of dietary preferences
            medical_history: List of medical conditions
            
        Returns:
            Dictionary with meal recommendations
        """
        if dietary_preferences is None:
            dietary_preferences = []
        if medical_history is None:
            medical_history = []
        
        # Calculate daily needs
        daily_needs = self._calculate_daily_needs(
            user_gender, user_age, user_weight, user_height, user_activity_level
        )
        
        # Filter foods based on dietary preferences
        available_foods = self._filter_foods_by_preferences(
            self.filipino_foods_db, dietary_preferences or []
        )
        
        # Generate meal plan with preferences
        meal_plan = self._generate_meal_plan(
            available_foods, daily_needs, user_gender, user_goal, dietary_preferences
        )
        
        # Add medical considerations
        medical_considerations = self._get_medical_considerations(
            meal_plan, medical_history or []
        )
        
        return {
            "meal_plan": meal_plan,
            "daily_needs": daily_needs,
            "medical_considerations": medical_considerations,
            "recommendations": self._get_meal_recommendations(user_gender, user_goal)
        }
    
    def analyze_food_log(self, food_log: List[Dict], user_gender: str, user_goal: str) -> Dict:
        """
        Analyze a food log and provide insights
        
        Args:
            food_log: List of food items consumed
            user_gender: User's gender
            user_goal: User's goal
            
        Returns:
            Dictionary with analysis results
        """
        if not food_log:
            return {"error": "No food log provided"}
        
        # Calculate total nutrition
        total_nutrition = self._calculate_total_nutrition(food_log)
        
        # Get daily needs for comparison
        daily_needs = self._calculate_daily_needs(
            user_gender, 25, 60, 160, "moderate"  # Default values
        )
        
        # Analyze gaps and excesses
        analysis = self._analyze_nutrition_gaps(total_nutrition, daily_needs, user_gender, user_goal)
        
        # Generate recommendations
        recommendations = self._generate_food_log_recommendations(
            analysis, user_gender, user_goal
        )
        
        return {
            "total_nutrition": total_nutrition,
            "daily_needs": daily_needs,
            "analysis": analysis,
            "recommendations": recommendations
        }
    
    def get_filipino_foods(self) -> List[Dict]:
        """Get list of available Filipino foods from expanded database"""
        # First try expanded database
        if self.expanded_filipino_foods:
            return self.expanded_filipino_foods
        
        # Fallback to legacy database
        foods_list = []
        for food_name, food_data in self.filipino_foods_db.items():
            foods_list.append({
                "name": food_name.replace("_", " ").title(),
                "category": food_data["category"],
                "calories_per_100g": food_data["calories_per_100g"],
                "protein": food_data["protein"],
                "fat": food_data["fat"],
                "carbs": food_data["carbs"],
                "iron": food_data["iron"],
                "calcium": food_data["calcium"]
            })
        return foods_list
    
    def search_filipino_foods(self, query: str) -> List[Dict]:
        """Search Filipino foods by name"""
        query_lower = query.lower()
        results = []
        
        for food in self.expanded_filipino_foods:
            # Search in English name
            if query_lower in food["name_english"].lower():
                results.append(food)
            # Search in Filipino name
            elif food["name_filipino"] and query_lower in food["name_filipino"].lower():
                results.append(food)
            # Search in meal category
            elif food["meal_category"] and query_lower in food["meal_category"].lower():
                results.append(food)
        
        return results
    
    def _extract_ingredients_from_name(self, food_name: str, provided_ingredients: Optional[List[str]] = None) -> Dict:
        """Extract and categorize ingredients from food name and provided list
        
        Returns:
            Dictionary with ingredient counts by category
        """
        if provided_ingredients is None:
            provided_ingredients = []
        
        # Common ingredient keywords by category
        meat_keywords = ['chicken', 'pork', 'beef', 'fish', 'meat', 'turkey', 'duck', 
                        'shrimp', 'crab', 'lobster', 'squid', 'tuna', 'salmon', 'tilapia',
                        'bangus', 'galunggong', 'adobo', 'sinigang', 'tinola']
        vegetable_keywords = ['vegetable', 'veggie', 'cabbage', 'carrot', 'onion', 'garlic',
                             'tomato', 'potato', 'eggplant', 'ampalaya', 'kangkong', 'malunggay',
                             'pechay', 'sitaw', 'okra', 'squash', 'pepper', 'lettuce', 'spinach']
        grain_keywords = ['rice', 'noodle', 'pasta', 'bread', 'wheat', 'corn', 'oats',
                         'pancit', 'bihon', 'canton', 'spaghetti', 'kamote', 'sweet potato']
        dairy_keywords = ['milk', 'cheese', 'butter', 'cream', 'yogurt', 'gata', 'coconut milk']
        legume_keywords = ['bean', 'monggo', 'munggo', 'tofu', 'lentil', 'chickpea', 'peanut']
        
        # Combine food name and ingredients for analysis
        text_to_analyze = ' '.join([food_name.lower()] + [ing.lower() for ing in provided_ingredients])
        
        # Count ingredients by category
        meat_count = sum(1 for keyword in meat_keywords if keyword in text_to_analyze)
        vegetable_count = sum(1 for keyword in vegetable_keywords if keyword in text_to_analyze)
        grain_count = sum(1 for keyword in grain_keywords if keyword in text_to_analyze)
        dairy_count = sum(1 for keyword in dairy_keywords if keyword in text_to_analyze)
        legume_count = sum(1 for keyword in legume_keywords if keyword in text_to_analyze)
        
        # Also count provided ingredients
        total_ingredients = len(provided_ingredients) if provided_ingredients else 0
        
        return {
            'meat_count': float(meat_count),
            'vegetable_count': float(vegetable_count),
            'grain_count': float(grain_count),
            'dairy_count': float(dairy_count),
            'legume_count': float(legume_count),
            'total_ingredients': float(total_ingredients),
            'has_meat': 1.0 if meat_count > 0 else 0.0,
            'has_vegetable': 1.0 if vegetable_count > 0 else 0.0,
            'has_grain': 1.0 if grain_count > 0 else 0.0,
            'has_dairy': 1.0 if dairy_count > 0 else 0.0,
            'has_legume': 1.0 if legume_count > 0 else 0.0
        }
    
    def _detect_preparation_from_name(self, food_name: str, provided_method: str = "") -> str:
        """Detect preparation method from food name if not provided"""
        if provided_method:
            return provided_method.lower()
        
        name_lower = food_name.lower()
        
        preparation_keywords = {
            'fried': ['fried', 'fry', 'prito', 'ginisa'],
            'deep_fried': ['deep fried', 'deep-fried', 'crispy'],
            'grilled': ['grilled', 'grill', 'inasal', 'ihaw'],
            'baked': ['baked', 'bake'],
            'boiled': ['boiled', 'boil', 'nilaga', 'sinigang', 'tinola'],
            'steamed': ['steamed', 'steam'],
            'stir_fried': ['stir', 'ginisang', 'ginisa', 'sauteed'],
            'raw': ['raw', 'fresh', 'sashimi'],
            'braised': ['braised', 'adobo', 'stewed'],
            'roasted': ['roasted', 'roast']
        }
        
        for method, keywords in preparation_keywords.items():
            if any(keyword in name_lower for keyword in keywords):
                return method
        
        return ""
    
    def _analyze_food_name_semantics(self, food_name: str) -> Dict:
        """Analyze food name for semantic features
        
        Returns:
            Dictionary with semantic features
        """
        name_lower = food_name.lower()
        
        # Detect cuisine type
        filipino_keywords = ['adobo', 'sinigang', 'tinola', 'kare-kare', 'pancit', 
                            'lumpia', 'lechon', 'sisig', 'bistek', 'afritada']
        asian_keywords = ['curry', 'stir-fry', 'teriyaki', 'sushi', 'ramen', 'pad thai']
        
        is_filipino = 1.0 if any(kw in name_lower for kw in filipino_keywords) else 0.0
        is_asian = 1.0 if any(kw in name_lower for kw in asian_keywords) else 0.0
        
        # Detect descriptors
        descriptors = {
            'spicy': ['spicy', 'hot', 'chili', 'sili'],
            'sweet': ['sweet', 'honey', 'sugar', 'caramel'],
            'creamy': ['creamy', 'cream', 'gata', 'coconut milk'],
            'sour': ['sour', 'tamarind', 'vinegar', 'calamansi'],
            'salty': ['salted', 'salted', 'patis'],
            'fried': ['fried', 'crispy', 'prito']
        }
        
        descriptor_features = {}
        for desc, keywords in descriptors.items():
            descriptor_features[f'has_{desc}'] = 1.0 if any(kw in name_lower for kw in keywords) else 0.0
        
        # Word count and complexity
        word_count = len(food_name.split())
        has_multiple_words = 1.0 if word_count > 2 else 0.0
        
        return {
            'is_filipino': is_filipino,
            'is_asian': is_asian,
            'word_count': float(word_count),
            'has_multiple_words': has_multiple_words,
            **descriptor_features
        }
    
    def _prepare_features(self, food_name: str, food_category: str, serving_size: float,
                         preparation_method: str, ingredients: Optional[List[str]]) -> List[float]:
        """Prepare features for ML model prediction (13 features - backward compatible)
        
        For enhanced features (20+ features), use _prepare_enhanced_features() instead.
        Note: Enhanced features require model retraining.
        """
        if ingredients is None:
            ingredients = []
        
        # Basic features
        features = [
            len(food_name),  # Name length
            serving_size,    # Serving size
            1.0 if food_category else 0.0,  # Has category
            1.0 if preparation_method else 0.0,  # Has preparation method
            len(ingredients) if ingredients else 0.0  # Number of ingredients
        ]
        
        # Add category encoding
        # IMPORTANT: Keep this list in sync with the categories used during training.
        # The trained RandomForestRegressor expects 13 features total. We build:
        # 5 base features + 8 one-hot category flags = 13.
        categories = [
            "meats",
            "vegetables",
            "fruits",
            "grains",
            "legumes",
            "soups",
            "dairy",
            "snacks",
        ]
        for cat in categories:
            features.append(1.0 if food_category.lower() == cat else 0.0)
        
        return features
    
    def _prepare_enhanced_features(self, food_name: str, food_category: str, serving_size: float,
                                   preparation_method: str, ingredients: Optional[List[str]]) -> List[float]:
        """Prepare enhanced features for ML model (20+ features)
        
        This method creates enhanced features with:
        - Ingredient analysis
        - Better preparation method encoding
        - Food name semantic features
        
        NOTE: This requires model retraining. Current model uses _prepare_features() with 13 features.
        """
        if ingredients is None:
            ingredients = []
        
        # Start with basic features (5)
        features = [
            len(food_name),  # Name length
            serving_size,    # Serving size
            1.0 if food_category else 0.0,  # Has category
            1.0 if preparation_method else 0.0,  # Has preparation method
            len(ingredients) if ingredients else 0.0  # Number of ingredients
        ]
        
        # Enhanced: Detect preparation method from name if not provided
        detected_prep = self._detect_preparation_from_name(food_name, preparation_method)
        
        # Enhanced: Preparation method encoding (10 methods)
        prep_methods = ['fried', 'deep_fried', 'grilled', 'baked', 'boiled', 
                       'steamed', 'stir_fried', 'raw', 'braised', 'roasted']
        for method in prep_methods:
            features.append(1.0 if detected_prep == method else 0.0)
        
        # Enhanced: Ingredient analysis
        ingredient_analysis = self._extract_ingredients_from_name(food_name, ingredients)
        features.extend([
            ingredient_analysis['meat_count'],
            ingredient_analysis['vegetable_count'],
            ingredient_analysis['grain_count'],
            ingredient_analysis['dairy_count'],
            ingredient_analysis['legume_count'],
            ingredient_analysis['has_meat'],
            ingredient_analysis['has_vegetable'],
            ingredient_analysis['has_grain'],
            ingredient_analysis['has_dairy'],
            ingredient_analysis['has_legume']
        ])
        
        # Enhanced: Food name semantic features
        semantics = self._analyze_food_name_semantics(food_name)
        features.extend([
            semantics['is_filipino'],
            semantics['is_asian'],
            semantics['word_count'],
            semantics['has_multiple_words'],
            semantics.get('has_spicy', 0.0),
            semantics.get('has_sweet', 0.0),
            semantics.get('has_creamy', 0.0),
            semantics.get('has_sour', 0.0)
        ])
        
        # Category encoding (8 categories)
        categories = [
            "meats",
            "vegetables",
            "fruits",
            "grains",
            "legumes",
            "soups",
            "dairy",
            "snacks",
        ]
        for cat in categories:
            features.append(1.0 if food_category.lower() == cat else 0.0)
        
        # Total: 5 (basic) + 10 (prep) + 10 (ingredients) + 8 (semantics) + 8 (categories) = 41 features
        return features
    
    def _rule_based_calorie_prediction(self, food_name: str, food_category: str, serving_size: float) -> float:
        """Fallback rule-based calorie prediction"""
        # Base calories per 100g by category
        base_calories = {
            "meats": 250,
            "vegetables": 25,
            "fruits": 60,
            "grains": 130,
            "legumes": 120,
            "soups": 80,
            "dairy": 100,
            "snacks": 300
        }
        
        category = food_category.lower() if food_category else "meats"
        base_cal = base_calories.get(category, 150)
        
        return (base_cal * serving_size) / 100
    
    def _adjust_for_preparation(self, calories: float, preparation_method: str) -> float:
        """Adjust calories based on preparation method"""
        adjustments = {
            "fried": 1.3,
            "deep_fried": 1.5,
            "grilled": 0.9,
            "baked": 0.95,
            "boiled": 0.85,
            "steamed": 0.8,
            "raw": 1.0,
            "stir_fried": 1.2
        }
        
        multiplier = adjustments.get(preparation_method.lower(), 1.0)
        return calories * multiplier
    
    def _get_nutrition_info(self, food_name: str, serving_size: float) -> Dict:
        """Get nutrition information for a food item"""
        # First try expanded database
        for food in self.expanded_filipino_foods:
            if (food_name.lower() in food["name_english"].lower() or 
                (food["name_filipino"] and food_name.lower() in food["name_filipino"].lower())):
                
                multiplier = serving_size / 100
                return {
                    "calories": round(food["calories_per_100g"] * multiplier, 1),
                    "protein": round(food["protein"] * multiplier, 1),
                    "fat": round(food["fat"] * multiplier, 1),
                    "carbs": round(food["carbs"] * multiplier, 1),
                    "iron": round(food["iron"] * multiplier, 1),
                    "calcium": round(food["calcium"] * multiplier, 1),
                    "vitamin_c": round(food["vitamin_c"] * multiplier, 1),
                    "fiber": round(food["fiber"] * multiplier, 1)
                }
        
        # Fallback to legacy database
        food_name_lower = food_name.lower().replace(" ", "_")
        
        if food_name_lower in self.filipino_foods_db:
            food_data = self.filipino_foods_db[food_name_lower]
            multiplier = serving_size / 100
            
            return {
                "calories": round(food_data["calories_per_100g"] * multiplier, 1),
                "protein": round(food_data["protein"] * multiplier, 1),
                "fat": round(food_data["fat"] * multiplier, 1),
                "carbs": round(food_data["carbs"] * multiplier, 1),
                "iron": round(food_data["iron"] * multiplier, 1),
                "calcium": round(food_data["calcium"] * multiplier, 1),
                "vitamin_c": round(food_data["vitamin_c"] * multiplier, 1),
                "fiber": round(food_data["fiber"] * multiplier, 1)
            }
        else:
            # Estimate nutrition for unknown foods
            calories = self.predict_calories(food_name, serving_size=serving_size)["calories"]
            return {
                "calories": calories,
                "protein": round(calories * 0.15 / 4, 1),  # 15% of calories from protein
                "fat": round(calories * 0.25 / 9, 1),      # 25% of calories from fat
                "carbs": round(calories * 0.60 / 4, 1),    # 60% of calories from carbs
                "iron": 1.0,  # Default values
                "calcium": 50.0,
                "vitamin_c": 10.0,
                "fiber": 2.0
            }
    
    def _calculate_daily_needs(self, gender: str, age: int, weight: float, 
                              height: float, activity_level: str) -> Dict:
        """Calculate daily nutritional needs"""
        # Basic Metabolic Rate (BMR) using Mifflin-St Jeor Equation
        if gender.lower() == "female":
            bmr = 10 * weight + 6.25 * height - 5 * age - 161
        else:
            bmr = 10 * weight + 6.25 * height - 5 * age + 5
        
        # Total Daily Energy Expenditure (TDEE)
        activity_multipliers = self.nutrition_guidelines["activity_levels"]
        tdee = bmr * activity_multipliers.get(activity_level.lower(), 1.55)
        
        # Get gender-specific guidelines
        guidelines = self.nutrition_guidelines.get(gender.lower(), self.nutrition_guidelines["male"])
        
        return {
            "calories": round(tdee),
            "protein": guidelines["protein_daily"],
            "iron": guidelines["iron_daily"],
            "calcium": guidelines["calcium_daily"],
            "fiber": guidelines["fiber_daily"],
            "vitamin_c": guidelines["vitamin_c_daily"]
        }
    
    def _get_gender_insights(self, nutrition_info: Dict, daily_needs: Dict, 
                           gender: str, goal: str) -> Dict:
        """Get gender-specific nutrition insights"""
        insights = []
        
        if gender.lower() == "female":
            # Iron insights for women
            iron_percentage = (nutrition_info["iron"] / daily_needs["iron"]) * 100
            if iron_percentage > 15:
                insights.append("✅ Good iron content for women's needs")
            elif iron_percentage < 5:
                insights.append("⚠️ Low iron content - consider iron-rich alternatives")
            
            # Calcium insights
            calcium_percentage = (nutrition_info["calcium"] / daily_needs["calcium"]) * 100
            if calcium_percentage > 10:
                insights.append("✅ Good calcium content for bone health")
        
        elif gender.lower() == "male":
            # Protein insights for men
            protein_percentage = (nutrition_info["protein"] / daily_needs["protein"]) * 100
            if protein_percentage > 20:
                insights.append("✅ Good protein content for muscle building")
        
        return {
            "insights": insights,
            "gender_specific_score": len(insights) * 0.25  # Score based on relevant insights
        }
    
    def _get_goal_recommendations(self, nutrition_info: Dict, daily_needs: Dict, goal: str) -> Dict:
        """Get goal-specific recommendations"""
        recommendations = []
        
        if goal.lower() == "lose weight":
            calorie_percentage = (nutrition_info["calories"] / daily_needs["calories"]) * 100
            if calorie_percentage > 30:
                recommendations.append("⚠️ High calorie content - consider smaller portion")
            elif calorie_percentage < 10:
                recommendations.append("✅ Good for weight loss - low calorie option")
        
        elif goal.lower() == "gain muscle":
            protein_percentage = (nutrition_info["protein"] / daily_needs["protein"]) * 100
            if protein_percentage > 15:
                recommendations.append("✅ Good protein content for muscle building")
            else:
                recommendations.append("💡 Consider adding protein-rich foods")
        
        return {
            "recommendations": recommendations,
            "goal_alignment_score": len(recommendations) * 0.3
        }
    
    def _filter_foods_by_preferences(self, foods_db: Dict, preferences: List[str]) -> Dict:
        """Filter foods based on dietary preferences from onboarding"""
        if not preferences:
            return foods_db
        
        # Normalize preferences to lowercase
        prefs_lower = [p.lower() for p in preferences]
        
        filtered_foods = {}
        for food_name, food_data in foods_db.items():
            category = food_data.get("category", "").lower()
            food_name_lower = food_name.lower()
            
            # Plant-based: Exclude meats, prioritize plant foods
            if "plant_based" in prefs_lower or "plant-based" in prefs_lower:
                # Check category first
                if category == "meats":
                    continue
                # Also check food name for meat keywords (some foods might be mis-categorized)
                meat_keywords = ['adobo', 'sinigang', 'lechon', 'sisig', 'tocino', 'longganisa', 
                                'chicken', 'pork', 'beef', 'fish', 'meat', 'egg', 'seafood',
                                'tinola', 'tinolang', 'manok', 'bangus', 'tilapia', 'galunggong']
                if any(kw in food_name_lower for kw in meat_keywords):
                    # But allow if it's a vegetable dish (e.g., "vegetable sinigang" - though rare)
                    vegetable_keywords = ['vegetable', 'sitaw', 'monggo', 'ampalaya', 'kangkong']
                    if not any(kw in food_name_lower for kw in vegetable_keywords):
                        continue
                
                # Prioritize vegetables, fruits, grains, legumes
                if category not in ["vegetables", "fruits", "grains", "legumes"]:
                    # Skip dairy unless specifically needed
                    if category == "dairy":
                        continue
            
            # Legacy support for vegetarian/vegan if someone manually added it
            if "vegetarian" in prefs_lower:
                if category == "meats":
                    continue
                # Also check name for meat keywords
                meat_keywords = ['adobo', 'sinigang', 'chicken', 'pork', 'beef', 'fish', 'meat',
                                'tinola', 'tinolang', 'manok', 'bangus', 'tilapia']
                if any(kw in food_name_lower for kw in meat_keywords):
                    continue
                    
            if "vegan" in prefs_lower:
                if category in ["meats", "dairy"]:
                    continue
                # Also check name for meat/dairy keywords
                meat_keywords = ['adobo', 'sinigang', 'chicken', 'pork', 'beef', 'fish', 'meat', 'egg',
                                'tinola', 'tinolang', 'manok', 'bangus', 'tilapia']
                dairy_keywords = ['milk', 'cheese', 'butter', 'cream', 'gata']
                if any(kw in food_name_lower for kw in meat_keywords + dairy_keywords):
                    continue
            
            # All other preferences (healthy, comfort, spicy, sweet, protein) 
            # don't filter out foods, they just influence scoring/prioritization
            # These will be handled in scoring logic
            
            filtered_foods[food_name] = food_data
        
        return filtered_foods
    
    def _generate_meal_plan(self, available_foods: Dict, daily_needs: Dict, 
                           gender: str, goal: str, preferences: Optional[List[str]] = None) -> Dict:
        """Generate a meal plan with preference-aware categorization"""
        # This is a simplified meal plan generator
        # In practice, you'd use more sophisticated algorithms
        
        if preferences is None:
            preferences = []
        
        prefs_lower = [p.lower() for p in preferences]
        
        breakfast_foods = []
        lunch_foods = []
        dinner_foods = []
        snack_foods = []
        
        # Categorize foods by meal type with preference awareness
        for food_name, food_data in available_foods.items():
            category = food_data.get("category", "").lower()
            protein = food_data.get("protein", 0)
            calories = food_data.get("calories_per_100g", 0)
            
            # Breakfast: grains, fruits, lighter foods
            if category in ["grains", "fruits"]:
                breakfast_foods.append(food_name)
            # If plant-based preference, prioritize plant foods for breakfast
            elif ("plant_based" in prefs_lower or "plant-based" in prefs_lower) and category in ["vegetables", "legumes"]:
                breakfast_foods.append(food_name)
            
            # Lunch: proteins, vegetables, balanced meals
            elif category in ["meats", "vegetables"]:
                lunch_foods.append(food_name)
            # Protein lovers get high-protein options for all meals (not just lunch)
            elif "protein" in prefs_lower and protein > 10:
                # Add high-protein foods to all meal types
                breakfast_foods.append(food_name)
                lunch_foods.append(food_name)
                dinner_foods.append(food_name)
            
            # Dinner: variety, can include heavier options
            else:
                dinner_foods.append(food_name)
            
            # Snacks: lighter options, fruits for sweet tooth
            if category in ["fruits", "snacks"]:
                snack_foods.append(food_name)
            elif "sweet" in prefs_lower and category == "fruits":
                snack_foods.append(food_name)
            elif calories < 150:  # Light snacks
                snack_foods.append(food_name)
        
        # Ensure we have some foods in each category
        if not breakfast_foods:
            breakfast_foods = [f for f in list(available_foods.keys())[:3]]
        if not lunch_foods:
            lunch_foods = [f for f in list(available_foods.keys())[3:6]]
        if not dinner_foods:
            dinner_foods = [f for f in list(available_foods.keys())[6:9]]
        if not snack_foods:
            snack_foods = [f for f in list(available_foods.keys())[:2]]
        
        return {
            "breakfast": {
                "foods": breakfast_foods[:5],  # Increased from 3 to give more options
                "target_calories": daily_needs["calories"] * 0.25
            },
            "lunch": {
                "foods": lunch_foods[:5],
                "target_calories": daily_needs["calories"] * 0.35
            },
            "dinner": {
                "foods": dinner_foods[:5],
                "target_calories": daily_needs["calories"] * 0.30
            },
            "snacks": {
                "foods": snack_foods[:3],
                "target_calories": daily_needs["calories"] * 0.10
            }
        }
    
    def _get_medical_considerations(self, meal_plan: Dict, medical_history: List[str]) -> List[str]:
        """Get medical considerations for the meal plan"""
        considerations = []
        
        for condition in medical_history:
            if condition.lower() == "diabetes":
                considerations.append("💡 Monitor carbohydrate intake for diabetes management")
            elif condition.lower() == "hypertension":
                considerations.append("💡 Consider low-sodium food options for blood pressure")
            elif condition.lower() == "heart disease":
                considerations.append("💡 Choose heart-healthy, low-fat options")
        
        return considerations
    
    def _get_meal_recommendations(self, gender: str, goal: str) -> List[str]:
        """Get general meal recommendations"""
        recommendations = []
        
        if gender.lower() == "female":
            recommendations.append("🍖 Include iron-rich foods like sinigang and liver")
            recommendations.append("🥛 Consider calcium-rich foods for bone health")
        
        if goal.lower() == "lose weight":
            recommendations.append("🥗 Focus on vegetables and lean proteins")
            recommendations.append("🍚 Choose brown rice over white rice")
        
        return recommendations
    
    def _calculate_total_nutrition(self, food_log: List[Dict]) -> Dict:
        """Calculate total nutrition from food log"""
        total = {
            "calories": 0,
            "protein": 0,
            "fat": 0,
            "carbs": 0,
            "iron": 0,
            "calcium": 0,
            "vitamin_c": 0,
            "fiber": 0
        }
        
        for food_item in food_log:
            food_name = food_item.get("food_name", "")
            serving_size = food_item.get("serving_size", 100)
            
            nutrition = self._get_nutrition_info(food_name, serving_size)
            
            for nutrient, value in nutrition.items():
                total[nutrient] += value
        
        return {k: round(v, 1) for k, v in total.items()}
    
    def _analyze_nutrition_gaps(self, total_nutrition: Dict, daily_needs: Dict, 
                               gender: str, goal: str) -> Dict:
        """Analyze nutrition gaps and excesses"""
        gaps = []
        excesses = []
        
        for nutrient, consumed in total_nutrition.items():
            if nutrient in daily_needs:
                needed = daily_needs[nutrient]
                percentage = (consumed / needed) * 100
                
                if percentage < 80:
                    gaps.append(f"Low {nutrient}: {percentage:.1f}% of daily need")
                elif percentage > 120:
                    excesses.append(f"High {nutrient}: {percentage:.1f}% of daily need")
        
        return {
            "gaps": gaps,
            "excesses": excesses,
            "overall_score": max(0, 100 - len(gaps) * 10 - len(excesses) * 5)
        }
    
    def _generate_food_log_recommendations(self, analysis: Dict, gender: str, goal: str) -> List[str]:
        """Generate recommendations based on food log analysis"""
        recommendations = []
        
        for gap in analysis["gaps"]:
            if "iron" in gap.lower() and gender.lower() == "female":
                recommendations.append("🍖 Add iron-rich foods like sinigang, liver, or ginisang monggo")
            elif "protein" in gap.lower():
                recommendations.append("🥩 Include more protein-rich foods like adobo or tinolang manok")
            elif "fiber" in gap.lower():
                recommendations.append("🥬 Add more vegetables like ampalaya or malunggay")
        
        for excess in analysis["excesses"]:
            if "calories" in excess.lower():
                recommendations.append("🍽️ Consider reducing portion sizes for weight management")
        
        return recommendations 