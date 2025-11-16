import joblib
import numpy as np
import pandas as pd
import os
import sqlite3
from typing import Dict, List, Optional, Tuple
import json

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
        
        # Load the model
        self._load_model()
    
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
            
            return {
                "calories": round(predicted_calories, 1),
                "confidence": 0.95,
                "method": "database_lookup",
                "food_name": food_name,
                "category": food_data["category"],
                "serving_size": serving_size
            }
        
        # Use ML model for unknown foods, but validate predictions
        if ingredients is None:
            ingredients = []
        
        # Try ML model first, but validate the prediction
        ml_prediction = None
        try:
            if self.model is not None and hasattr(self.model, 'predict'):
                # Prepare features for ML model
                features = self._prepare_features(
                    food_name, food_category, serving_size, preparation_method, ingredients
                )
                
                # Make prediction
                ml_prediction = self.model.predict([features])[0]
                
                # Validate ML prediction - check if it's reasonable
                # If prediction is too high (>5000 kcal) or doesn't scale with serving size,
                # it's likely the model isn't working correctly
                rule_based_pred = self._rule_based_calorie_prediction(
                    food_name, food_category, serving_size
                )
                
                # If ML prediction is way off (more than 5x rule-based or >2000 kcal), use rule-based instead
                # Also check if prediction doesn't scale with serving size (constant predictions indicate broken model)
                if (ml_prediction > 2000 or 
                    (rule_based_pred > 0 and ml_prediction > rule_based_pred * 5)):
                    ml_prediction = None  # Reject ML prediction
                    
        except Exception as e:
            ml_prediction = None  # ML model failed
        
        # Use rule-based prediction if ML prediction is invalid or unavailable
        if ml_prediction is None:
            prediction = self._rule_based_calorie_prediction(
                food_name, food_category, serving_size
            )
            
            # Adjust for preparation method
            if preparation_method:
                prediction = self._adjust_for_preparation(prediction, preparation_method)
            
            return {
                "calories": round(prediction, 1),
                "confidence": 0.70,
                "method": "rule_based",
                "food_name": food_name,
                "category": food_category,
                "serving_size": serving_size,
                "note": "Using rule-based prediction (ML model prediction was invalid)"
            }
        else:
            # ML prediction is valid, use it
            # ml_prediction is in calories per 100g, so scale by serving_size
            total_calories = (ml_prediction * serving_size) / 100
            
            # Adjust for preparation method
            if preparation_method:
                total_calories = self._adjust_for_preparation(total_calories, preparation_method)
            
            return {
                "calories": round(total_calories, 1),
                "confidence": 0.85,
                "method": "ml_model",
                "food_name": food_name,
                "category": food_category,
                "serving_size": serving_size
            }
    
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
    
    def _prepare_features(self, food_name: str, food_category: str, serving_size: float,
                         preparation_method: str, ingredients: Optional[List[str]]) -> List[float]:
        """Prepare features for ML model prediction"""
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
                if category == "meats":
                    continue
                # Prioritize vegetables, fruits, grains, legumes
                if category not in ["vegetables", "fruits", "grains", "legumes"]:
                    # Skip dairy unless specifically needed
                    if category == "dairy":
                        continue
            
            # Legacy support for vegetarian/vegan if someone manually added it
            if "vegetarian" in prefs_lower and category == "meats":
                continue
            if "vegan" in prefs_lower and category in ["meats", "dairy"]:
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