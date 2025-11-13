import sys, os
sys.path.insert(0, os.getcwd())
from Nutrition.nutrition_model import NutritionModel

nm = NutritionModel(model_path='Nutrition/model/best_regression_model.joblib')
print('MODEL_LOADED:', nm.is_model_loaded())
print('PREDICT_UNKNOWN:', nm.predict_calories('custom dish', food_category='meats', serving_size=150, preparation_method='fried', ingredients=['pork','soy sauce','vinegar']))
print('PREDICT_KNOWN:', nm.predict_calories('adobo', serving_size=150))
