"""
ML Model Training Script with Experimentation
Trains multiple models and compares their performance for calorie prediction
"""

# %% [markdown]
# # ML Model Training for Calorie Prediction
# 
# This notebook trains multiple machine learning models to predict calories in Filipino foods.
# 
# ## Models to Train:
# - Linear Regression
# - Random Forest
# - Decision Tree
# - XGBoost
# - K-Nearest Neighbors (KNN)

# %% [markdown]
# ## 1. Import Libraries
# 
# **Note for Google Colab:** Make sure to upload the dataset file `Filipino_Food_Nutrition_Dataset.csv` to your Colab session.

# %%
import pandas as pd
import numpy as np
import joblib
import os
import re
from sklearn.model_selection import train_test_split, cross_val_score, GridSearchCV, learning_curve
from sklearn.ensemble import RandomForestRegressor
from sklearn.linear_model import LinearRegression
from sklearn.tree import DecisionTreeRegressor
from sklearn.neighbors import KNeighborsRegressor
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler, RobustScaler
try:
    from xgboost import XGBRegressor
    XGBOOST_AVAILABLE = True
except ImportError:
    XGBOOST_AVAILABLE = False
    print("Warning: XGBoost not available. Install with: pip install xgboost")

from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score, mean_absolute_percentage_error, explained_variance_score
from sklearn.preprocessing import StandardScaler
import matplotlib.pyplot as plt
import seaborn as sns
import warnings
warnings.filterwarnings('ignore')

# Set style for better-looking plots
plt.style.use('seaborn-v0_8-darkgrid')
sns.set_palette("husl")

# %% [markdown]
# ## 2. Define CalorieModelTrainer Class

# %%
class CalorieModelTrainer:
    def __init__(self, csv_path: str = "data/Filipino_Food_Nutrition_Dataset.csv"):
        self.csv_path = csv_path
        self.df = None
        self.X = None
        self.y = None
        self.X_train = None
        self.X_test = None
        self.y_train = None
        self.y_test = None
        self.scaler = None
        self.models = {}
        self.results = {}
        self.training_times = {}
        self.output_dir = "training_results"
        
        # Category mapping from dataset categories to model categories
        self.category_mapping = {
            'main dish': 'meats',
            'meat': 'meats',
            'protein': 'meats',
            'fish': 'meats',
            'seafood': 'meats',
            'vegetable': 'vegetables',
            'vegetable dish': 'vegetables',
            'fruit': 'fruits',
            'staple': 'grains',
            'bread': 'grains',
            'cereal': 'grains',
            'noodles': 'grains',
            'noodle dish': 'grains',
            'porridge': 'grains',
            'soup': 'soups',
            'stew': 'soups',
            'dairy': 'dairy',
            'snack': 'snacks',
            'dessert': 'snacks',
            'appetizer': 'snacks',
            'street food': 'snacks',
            'beverage': 'snacks',
            'condiment': 'snacks',
            'spread': 'snacks',
            'salad': 'vegetables',
            'sandwich': 'snacks',
            'breakfast': 'grains',
        }
        
        # Model categories expected by the model
        self.model_categories = [
            "meats", "vegetables", "fruits", "grains", 
            "legumes", "soups", "dairy", "snacks"
        ]
    
    def load_data(self):
        """Load and inspect the dataset"""
        print("=" * 70)
        print("LOADING DATA")
        print("=" * 70)
        
        if not os.path.exists(self.csv_path):
            raise FileNotFoundError(f"Dataset not found at {self.csv_path}")
        
        self.df = pd.read_csv(self.csv_path, encoding='utf-8')
        print(f"Loaded {len(self.df)} food items")
        print(f"Columns: {list(self.df.columns)}")
        print(f"\nFirst few rows:")
        print(self.df.head(3))
        return self
    
    def extract_serving_size_grams(self, serving_size_str):
        """Extract serving size in grams from string like '1 cup (158g)'"""
        if pd.isna(serving_size_str):
            return 100.0  # Default
        
        serving_size_str = str(serving_size_str).lower()
        
        # Try to find number followed by 'g' in parentheses
        match = re.search(r'\((\d+(?:\.\d+)?)\s*g\)', serving_size_str)
        if match:
            return float(match.group(1))
        
        # Try to find number followed by 'g' anywhere
        match = re.search(r'(\d+(?:\.\d+)?)\s*g', serving_size_str)
        if match:
            return float(match.group(1))
        
        # Try to find any number (fallback)
        match = re.search(r'(\d+(?:\.\d+)?)', serving_size_str)
        if match:
            return float(match.group(1))
        
        return 100.0  # Default if nothing found
    
    # %% [markdown]
    # ### 2.2 Feature Engineering Methods
    
    def map_category(self, category_str):
        """Map dataset category to model category"""
        if pd.isna(category_str):
            return 'meats'  # Default
        
        category_lower = str(category_str).lower().strip()
        
        # Direct match
        if category_lower in self.model_categories:
            return category_lower
        
        # Check mapping
        for key, value in self.category_mapping.items():
            if key in category_lower:
                return value
        
        # Check for legumes
        if 'legume' in category_lower or 'monggo' in category_lower or 'beans' in category_lower:
            return 'legumes'
        
        return 'meats'  # Default fallback
    
    def detect_preparation_method(self, food_name):
        """Detect preparation method from food name"""
        if pd.isna(food_name):
            return ''
        
        name_lower = str(food_name).lower()
        
        preparation_keywords = {
            'fried': ['fried', 'fry'],
            'boiled': ['boiled', 'boil'],
            'grilled': ['grilled', 'grill', 'inasal'],
            'baked': ['baked', 'bake'],
            'steamed': ['steamed', 'steam'],
            'stir_fried': ['stir', 'ginisang', 'ginisa'],
            'raw': ['raw', 'fresh'],
        }
        
        for method, keywords in preparation_keywords.items():
            if any(keyword in name_lower for keyword in keywords):
                return method
        
        return ''
    
    # %% [markdown]
    # ### 2.3 Data Preparation Methods
    
    def prepare_features(self):
        """Extract features from dataset"""
        print("\n" + "=" * 70)
        print("PREPARING FEATURES")
        print("=" * 70)
        
        features_list = []
        calories_list = []
        
        for idx, row in self.df.iterrows():
            try:
                # Extract features
                food_name = str(row.get('Food Name', ''))
                category = str(row.get('Category', ''))
                serving_size_str = str(row.get('Serving Size', ''))
                calories = float(row.get('Calories', 0))
                
                # Skip invalid rows
                if calories <= 0 or calories > 5000:
                    continue
                
                # Extract serving size in grams
                serving_size_g = self.extract_serving_size_grams(serving_size_str)
                
                # Normalize calories to per 100g
                calories_per_100g = (calories / serving_size_g) * 100
                
                # Map category
                mapped_category = self.map_category(category)
                
                # Detect preparation method
                preparation = self.detect_preparation_method(food_name)
                
                # Build feature vector (13 features)
                features = [
                    len(food_name),  # Name length
                    serving_size_g,  # Serving size in grams
                    1.0 if category else 0.0,  # Has category
                    1.0 if preparation else 0.0,  # Has preparation method
                    0.0,  # Number of ingredients (not available in dataset)
                ]
                
                # Add category flags (8 categories)
                for cat in self.model_categories:
                    features.append(1.0 if mapped_category == cat else 0.0)
                
                features_list.append(features)
                calories_list.append(calories_per_100g)  # Use per 100g for training
                
            except Exception as e:
                print(f"Warning: Skipping row {idx} due to error: {e}")
                continue
        
        self.X = np.array(features_list)
        self.y = np.array(calories_list)
        
        print(f"Prepared {len(self.X)} samples")
        print(f"Feature shape: {self.X.shape}")
        print(f"Target shape: {self.y.shape}")
        print(f"Calories range: {self.y.min():.1f} - {self.y.max():.1f} kcal/100g")
        print(f"Mean calories: {self.y.mean():.1f} kcal/100g")
        
        return self
    
    def split_data(self, test_size=0.2, random_state=42):
        """Split data into training and testing sets"""
        print("\n" + "=" * 70)
        print("SPLITTING DATA")
        print("=" * 70)
        
        self.X_train, self.X_test, self.y_train, self.y_test = train_test_split(
            self.X, self.y, test_size=test_size, random_state=random_state
        )
        
        print(f"Training set: {len(self.X_train)} samples")
        print(f"Testing set: {len(self.X_test)} samples")
        
        return self
    
    # %% [markdown]
    # ### 2.4 Model Initialization
    
    def initialize_models(self, use_pipeline=True, use_hyperparameter_tuning=False):
        """Initialize models with pipelines for experimentation"""
        print("\n" + "=" * 70)
        print("INITIALIZING MODELS")
        print("=" * 70)
        
        if use_pipeline:
            print("Using Pipeline with StandardScaler for preprocessing")
        
        self.use_pipeline = use_pipeline
        self.use_hyperparameter_tuning = use_hyperparameter_tuning
        self.models = {}
        self.param_grids = {}
        
        # Linear Regression with pipeline
        if use_pipeline:
            self.models['Linear Regression'] = Pipeline([
                ('scaler', StandardScaler()),
                ('regressor', LinearRegression())
            ])
        else:
            self.models['Linear Regression'] = LinearRegression()
        
        # Random Forest (tree-based, doesn't need scaling)
        self.models['Random Forest'] = RandomForestRegressor(
            n_estimators=100,
            max_depth=10,
            random_state=42,
            n_jobs=-1
        )
        if use_hyperparameter_tuning:
            self.param_grids['Random Forest'] = {
                'n_estimators': [50, 100, 200],
                'max_depth': [5, 10, 15, None],
                'min_samples_split': [2, 5, 10]
            }
        
        # Decision Tree
        self.models['Decision Tree'] = DecisionTreeRegressor(random_state=42, max_depth=10)
        if use_hyperparameter_tuning:
            self.param_grids['Decision Tree'] = {
                'max_depth': [5, 10, 15, 20, None],
                'min_samples_split': [2, 5, 10],
                'min_samples_leaf': [1, 2, 4]
            }
        
        # XGBoost
        if XGBOOST_AVAILABLE:
            self.models['XGBoost'] = XGBRegressor(
                n_estimators=100,
                max_depth=5,
                learning_rate=0.1,
                random_state=42,
                n_jobs=-1
            )
            if use_hyperparameter_tuning:
                self.param_grids['XGBoost'] = {
                    'n_estimators': [50, 100, 200],
                    'max_depth': [3, 5, 7],
                    'learning_rate': [0.01, 0.1, 0.2]
                }
        else:
            print("Warning: XGBoost not available, skipping...")
        
        # K-Nearest Neighbors with pipeline
        if use_pipeline:
            self.models['K-Nearest Neighbors (KNN)'] = Pipeline([
                ('scaler', StandardScaler()),
                ('regressor', KNeighborsRegressor(
                    n_neighbors=5,
                    weights='distance',
                    algorithm='auto'
                ))
            ])
            if use_hyperparameter_tuning:
                self.param_grids['K-Nearest Neighbors (KNN)'] = {
                    'regressor__n_neighbors': [3, 5, 7, 10],
                    'regressor__weights': ['uniform', 'distance'],
                    'regressor__algorithm': ['auto', 'ball_tree', 'kd_tree']
                }
        else:
            self.models['K-Nearest Neighbors (KNN)'] = KNeighborsRegressor(
                n_neighbors=5,
                weights='distance',
                algorithm='auto'
            )
            if use_hyperparameter_tuning:
                self.param_grids['K-Nearest Neighbors (KNN)'] = {
                    'n_neighbors': [3, 5, 7, 10],
                    'weights': ['uniform', 'distance']
                }
        
        print(f"Initialized {len(self.models)} models:")
        for name in self.models.keys():
            print(f"  - {name}")
        if use_hyperparameter_tuning:
            print(f"\nHyperparameter tuning enabled for {len(self.param_grids)} models")
        
        return self
    
    # %% [markdown]
    # ### 2.5 Model Training and Evaluation
    
    def train_and_evaluate_models(self):
        """Train all models and evaluate their performance"""
        print("\n" + "=" * 70)
        print("TRAINING AND EVALUATING MODELS")
        print("=" * 70)
        
        # Create output directory for visualizations
        os.makedirs(self.output_dir, exist_ok=True)
        
        self.results = {}
        self.training_times = {}
        
        for name, model in self.models.items():
            print(f"\n{'='*70}")
            print(f"Training: {name}")
            print(f"{'='*70}")
            
            try:
                # Track training time
                import time
                start_time = time.time()
                
                # Hyperparameter tuning if enabled
                if hasattr(self, 'use_hyperparameter_tuning') and self.use_hyperparameter_tuning and name in self.param_grids:
                    print(f"  Performing hyperparameter tuning...")
                    grid_search = GridSearchCV(
                        model,
                        self.param_grids[name],
                        cv=5,
                        scoring='r2',
                        n_jobs=-1,
                        verbose=0
                    )
                    grid_search.fit(self.X_train, self.y_train)
                    model = grid_search.best_estimator_
                    print(f"  Best params: {grid_search.best_params_}")
                    print(f"  Best CV score: {grid_search.best_score_:.4f}")
                
                # Train model
                model.fit(self.X_train, self.y_train)
                
                training_time = time.time() - start_time
                self.training_times[name] = training_time
                print(f"Training time: {training_time:.2f} seconds")
                
                # Make predictions
                y_train_pred = model.predict(self.X_train)
                y_test_pred = model.predict(self.X_test)
                
                # Calculate comprehensive metrics
                train_mae = mean_absolute_error(self.y_train, y_train_pred)
                test_mae = mean_absolute_error(self.y_test, y_test_pred)
                train_rmse = np.sqrt(mean_squared_error(self.y_train, y_train_pred))
                test_rmse = np.sqrt(mean_squared_error(self.y_test, y_test_pred))
                train_r2 = r2_score(self.y_train, y_train_pred)
                test_r2 = r2_score(self.y_test, y_test_pred)
                
                # Additional metrics
                try:
                    train_mape = mean_absolute_percentage_error(self.y_train, y_train_pred)
                    test_mape = mean_absolute_percentage_error(self.y_test, y_test_pred)
                except:
                    train_mape = np.nan
                    test_mape = np.nan
                
                train_evs = explained_variance_score(self.y_train, y_train_pred)
                test_evs = explained_variance_score(self.y_test, y_test_pred)
                
                # Cross-validation score
                cv_scores = cross_val_score(model, self.X_train, self.y_train, 
                                          cv=5, scoring='r2', n_jobs=-1)
                cv_mean = cv_scores.mean()
                cv_std = cv_scores.std()
                
                self.results[name] = {
                    'model': model,
                    'train_mae': train_mae,
                    'test_mae': test_mae,
                    'train_rmse': train_rmse,
                    'test_rmse': test_rmse,
                    'train_r2': train_r2,
                    'test_r2': test_r2,
                    'train_mape': train_mape,
                    'test_mape': test_mape,
                    'train_evs': train_evs,
                    'test_evs': test_evs,
                    'cv_mean': cv_mean,
                    'cv_std': cv_std,
                    'y_test_pred': y_test_pred,
                    'y_train_pred': y_train_pred
                }
                
                print(f"Train MAE: {train_mae:.2f} kcal/100g")
                print(f"Test MAE:  {test_mae:.2f} kcal/100g")
                print(f"Train RMSE: {train_rmse:.2f} kcal/100g")
                print(f"Test RMSE:  {test_rmse:.2f} kcal/100g")
                print(f"Train R²:  {train_r2:.4f}")
                print(f"Test R²:   {test_r2:.4f}")
                if not np.isnan(test_mape):
                    print(f"Test MAPE: {test_mape:.2f}%")
                print(f"Test EVS:  {test_evs:.4f}")
                print(f"CV R²:     {cv_mean:.4f} (+/- {cv_std:.4f})")
                
            except Exception as e:
                print(f"Error training {name}: {e}")
                continue
        
        return self
    
    # %% [markdown]
    # ### 2.6 Model Comparison and Selection
    
    def print_comparison_table(self):
        """Print comparison table of all models"""
        print("\n" + "=" * 70)
        print("MODEL COMPARISON TABLE")
        print("=" * 70)
        
        # Create comparison DataFrame
        comparison_data = []
        for name, metrics in self.results.items():
            comparison_data.append({
                'Model': name,
                'Test MAE': f"{metrics['test_mae']:.2f}",
                'Test RMSE': f"{metrics['test_rmse']:.2f}",
                'Test R²': f"{metrics['test_r2']:.4f}",
                'CV R² Mean': f"{metrics['cv_mean']:.4f}",
                'CV R² Std': f"{metrics['cv_std']:.4f}",
            })
        
        comparison_df = pd.DataFrame(comparison_data)
        print("\n" + comparison_df.to_string(index=False))
        
        return self
    
    def select_best_model(self):
        """Select the best model based on test R² score"""
        print("\n" + "=" * 70)
        print("SELECTING BEST MODEL")
        print("=" * 70)
        
        if not self.results:
            print("No models to compare!")
            return None
        
        # Sort by test R² score
        sorted_results = sorted(
            self.results.items(),
            key=lambda x: x[1]['test_r2'],
            reverse=True
        )
        
        best_name, best_metrics = sorted_results[0]
        
        print(f"\nBest Model: {best_name}")
        print(f"  Test R²:  {best_metrics['test_r2']:.4f}")
        print(f"  Test MAE: {best_metrics['test_mae']:.2f} kcal/100g")
        print(f"  Test RMSE: {best_metrics['test_rmse']:.2f} kcal/100g")
        print(f"  CV R²:    {best_metrics['cv_mean']:.4f} (+/- {best_metrics['cv_std']:.4f})")
        
        return best_name, best_metrics['model']
    
    # %% [markdown]
    # ### 2.7 Prediction Testing
    
    def test_predictions(self, model, model_name):
        """Test model predictions with sample inputs"""
        print("\n" + "=" * 70)
        print(f"TESTING PREDICTIONS: {model_name}")
        print("=" * 70)
        
        test_cases = [
            {"name": "test_meat", "category": "meats", "serving": 150},
            {"name": "test_vegetable", "category": "vegetables", "serving": 100},
            {"name": "test_fruit", "category": "fruits", "serving": 200},
            {"name": "test_grains", "category": "grains", "serving": 100},
        ]
        
        print("\nSample Predictions (calories per 100g):")
        for case in test_cases:
            # Prepare features
            features = [
                len(case["name"]),
                case["serving"],
                1.0,  # has category
                0.0,  # has preparation
                0.0,  # num ingredients
            ]
            
            # Add category flags
            for cat in self.model_categories:
                features.append(1.0 if case["category"] == cat else 0.0)
            
            # Predict (this gives calories per 100g)
            prediction = model.predict([features])[0]
            
            # Convert to total calories for the serving size
            total_calories = (prediction * case["serving"]) / 100
            
            print(f"  {case['name']} ({case['category']}, {case['serving']}g): "
                  f"{prediction:.1f} kcal/100g = {total_calories:.1f} kcal total")
        
        return self
    
    # %% [markdown]
    # ### 2.8 Model Saving
    
    def save_model(self, model, model_name, output_path="model/best_regression_model.joblib"):
        """Save the best model"""
        print("\n" + "=" * 70)
        print("SAVING MODEL")
        print("=" * 70)
        
        # Create model directory if it doesn't exist
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        
        # Save model
        joblib.dump(model, output_path)
        print(f"Model saved to: {output_path}")
        print(f"Model type: {type(model).__name__}")
        
        return self
    
    # %% [markdown]
    # ### 2.9 Visualization Methods
    
    def create_visualizations(self):
        """Create visualizations of training results"""
        print("\n" + "=" * 70)
        print("CREATING VISUALIZATIONS")
        print("=" * 70)
        
        if not self.results:
            print("No results to visualize!")
            return self
        
        # 1. Model Comparison Bar Chart
        self._plot_model_comparison()
        
        # 2. Prediction vs Actual Scatter Plots
        self._plot_prediction_scatter()
        
        # 3. Feature Importance (for tree-based models)
        self._plot_feature_importance()
        
        # 4. Training Time Comparison
        self._plot_training_times()
        
        # 5. Residual Plots
        self._plot_residuals()
        
        # 6. Learning Curves
        self._plot_learning_curves()
        
        # 7. Error Distribution
        self._plot_error_distribution()
        
        print(f"\nVisualizations saved to: {self.output_dir}/")
        return self
    
    def _plot_model_comparison(self):
        """Create bar chart comparing all models"""
        fig, axes = plt.subplots(2, 2, figsize=(15, 12))
        fig.suptitle('Model Performance Comparison', fontsize=16, fontweight='bold')
        
        models = list(self.results.keys())
        metrics = {
            'Test R²': [self.results[m]['test_r2'] for m in models],
            'Test MAE': [self.results[m]['test_mae'] for m in models],
            'Test RMSE': [self.results[m]['test_rmse'] for m in models],
            'CV R² Mean': [self.results[m]['cv_mean'] for m in models]
        }
        
        for idx, (metric_name, values) in enumerate(metrics.items()):
            ax = axes[idx // 2, idx % 2]
            bars = ax.barh(models, values, color=sns.color_palette("husl", len(models)))
            ax.set_xlabel(metric_name, fontweight='bold')
            ax.set_title(f'{metric_name} Comparison', fontweight='bold')
            ax.grid(axis='x', alpha=0.3)
            
            # Add value labels on bars
            for i, (bar, val) in enumerate(zip(bars, values)):
                ax.text(val, i, f' {val:.4f}' if 'R²' in metric_name else f' {val:.2f}',
                       va='center', fontweight='bold')
        
        plt.tight_layout()
        plt.savefig(f'{self.output_dir}/model_comparison.png', dpi=300, bbox_inches='tight')
        plt.close()
        print("[OK] Model comparison chart saved")
    
    def _plot_prediction_scatter(self):
        """Create scatter plots of predicted vs actual for all models"""
        n_models = len(self.results)
        cols = 3
        rows = (n_models + cols - 1) // cols
        
        fig, axes = plt.subplots(rows, cols, figsize=(15, 5*rows))
        if n_models == 1:
            axes = [axes]
        else:
            axes = axes.flatten()
        
        fig.suptitle('Predicted vs Actual Calories (Test Set)', fontsize=16, fontweight='bold')
        
        for idx, (name, metrics) in enumerate(self.results.items()):
            ax = axes[idx] if n_models > 1 else axes[0]
            y_pred = metrics['y_test_pred']
            
            ax.scatter(self.y_test, y_pred, alpha=0.6, s=50)
            
            # Perfect prediction line
            min_val = min(self.y_test.min(), y_pred.min())
            max_val = max(self.y_test.max(), y_pred.max())
            ax.plot([min_val, max_val], [min_val, max_val], 'r--', lw=2, label='Perfect Prediction')
            
            ax.set_xlabel('Actual Calories (kcal/100g)', fontweight='bold')
            ax.set_ylabel('Predicted Calories (kcal/100g)', fontweight='bold')
            ax.set_title(f'{name}\nR² = {metrics["test_r2"]:.4f}', fontweight='bold')
            ax.legend()
            ax.grid(alpha=0.3)
        
        # Hide unused subplots
        for idx in range(n_models, len(axes)):
            axes[idx].axis('off')
        
        plt.tight_layout()
        plt.savefig(f'{self.output_dir}/prediction_scatter.png', dpi=300, bbox_inches='tight')
        plt.close()
        print("[OK] Prediction scatter plots saved")
    
    def _plot_feature_importance(self):
        """Plot feature importance for tree-based models"""
        tree_models = {
            'Random Forest': 'Random Forest',
            'Decision Tree': 'Decision Tree',
            'XGBoost': 'XGBoost'
        }
        
        feature_names = [
            'Name Length', 'Serving Size', 'Has Category', 'Has Preparation', 'Num Ingredients',
            'Meats', 'Vegetables', 'Fruits', 'Grains', 'Legumes', 'Soups', 'Dairy', 'Snacks'
        ]
        
        available_models = {k: v for k, v in tree_models.items() if k in self.results}
        
        if not available_models:
            return
        
        n_models = len(available_models)
        fig, axes = plt.subplots(1, n_models, figsize=(6*n_models, 8))
        if n_models == 1:
            axes = [axes]
        
        fig.suptitle('Feature Importance Analysis', fontsize=16, fontweight='bold')
        
        for idx, (name, model_name) in enumerate(available_models.items()):
            model = self.results[name]['model']
            
            if hasattr(model, 'feature_importances_'):
                importances = model.feature_importances_
                indices = np.argsort(importances)[::-1]
                
                ax = axes[idx]
                ax.barh(range(len(importances)), importances[indices], color=sns.color_palette("husl", len(importances)))
                ax.set_yticks(range(len(importances)))
                ax.set_yticklabels([feature_names[i] for i in indices])
                ax.set_xlabel('Importance', fontweight='bold')
                ax.set_title(f'{name}\nFeature Importance', fontweight='bold')
                ax.grid(axis='x', alpha=0.3)
        
        plt.tight_layout()
        plt.savefig(f'{self.output_dir}/feature_importance.png', dpi=300, bbox_inches='tight')
        plt.close()
        print("[OK] Feature importance plots saved")
    
    def _plot_training_times(self):
        """Plot training time comparison"""
        if not self.training_times:
            return
        
        fig, ax = plt.subplots(figsize=(10, 6))
        
        models = list(self.training_times.keys())
        times = list(self.training_times.values())
        
        bars = ax.barh(models, times, color=sns.color_palette("husl", len(models)))
        ax.set_xlabel('Training Time (seconds)', fontweight='bold')
        ax.set_title('Model Training Time Comparison', fontsize=14, fontweight='bold')
        ax.grid(axis='x', alpha=0.3)
        
        # Add value labels
        for bar, time_val in zip(bars, times):
            ax.text(time_val, bar.get_y() + bar.get_height()/2, 
                   f' {time_val:.2f}s', va='center', fontweight='bold')
        
        plt.tight_layout()
        plt.savefig(f'{self.output_dir}/training_times.png', dpi=300, bbox_inches='tight')
        plt.close()
        print("[OK] Training time comparison saved")
    
    def _plot_residuals(self):
        """Plot residual analysis for best model"""
        if not self.results:
            return
        
        # Get best model
        best_name = max(self.results.items(), key=lambda x: x[1]['test_r2'])[0]
        best_metrics = self.results[best_name]
        y_pred = best_metrics['y_test_pred']
        residuals = self.y_test - y_pred
        
        fig, axes = plt.subplots(1, 2, figsize=(15, 6))
        fig.suptitle(f'Residual Analysis: {best_name}', fontsize=16, fontweight='bold')
        
        # Residual scatter plot
        axes[0].scatter(y_pred, residuals, alpha=0.6, s=50)
        axes[0].axhline(y=0, color='r', linestyle='--', lw=2)
        axes[0].set_xlabel('Predicted Calories (kcal/100g)', fontweight='bold')
        axes[0].set_ylabel('Residuals (Actual - Predicted)', fontweight='bold')
        axes[0].set_title('Residuals vs Predicted', fontweight='bold')
        axes[0].grid(alpha=0.3)
        
        # Residual distribution
        axes[1].hist(residuals, bins=30, edgecolor='black', alpha=0.7, color=sns.color_palette("husl", 1)[0])
        axes[1].axvline(x=0, color='r', linestyle='--', lw=2)
        axes[1].set_xlabel('Residuals (Actual - Predicted)', fontweight='bold')
        axes[1].set_ylabel('Frequency', fontweight='bold')
        axes[1].set_title('Residual Distribution', fontweight='bold')
        axes[1].grid(alpha=0.3)
        
        plt.tight_layout()
        plt.savefig(f'{self.output_dir}/residual_analysis.png', dpi=300, bbox_inches='tight')
        plt.close()
        print("[OK] Residual analysis plots saved")
    
    def _plot_learning_curves(self):
        """Plot learning curves for best model"""
        if not self.results:
            return
        
        # Get best model
        best_name = max(self.results.items(), key=lambda x: x[1]['test_r2'])[0]
        best_model = self.results[best_name]['model']
        
        # Generate learning curve data
        train_sizes, train_scores, val_scores = learning_curve(
            best_model, self.X_train, self.y_train,
            cv=5, n_jobs=-1, train_sizes=np.linspace(0.1, 1.0, 10),
            scoring='r2'
        )
        
        train_mean = np.mean(train_scores, axis=1)
        train_std = np.std(train_scores, axis=1)
        val_mean = np.mean(val_scores, axis=1)
        val_std = np.std(val_scores, axis=1)
        
        fig, ax = plt.subplots(figsize=(10, 6))
        ax.plot(train_sizes, train_mean, 'o-', color='blue', label='Training Score')
        ax.fill_between(train_sizes, train_mean - train_std, train_mean + train_std, alpha=0.1, color='blue')
        ax.plot(train_sizes, val_mean, 'o-', color='red', label='Validation Score')
        ax.fill_between(train_sizes, val_mean - val_std, val_mean + val_std, alpha=0.1, color='red')
        
        ax.set_xlabel('Training Set Size', fontweight='bold')
        ax.set_ylabel('R² Score', fontweight='bold')
        ax.set_title(f'Learning Curves: {best_name}', fontsize=14, fontweight='bold')
        ax.legend()
        ax.grid(alpha=0.3)
        
        plt.tight_layout()
        plt.savefig(f'{self.output_dir}/learning_curves.png', dpi=300, bbox_inches='tight')
        plt.close()
        print("[OK] Learning curves saved")
    
    def _plot_error_distribution(self):
        """Plot error distribution for all models"""
        if not self.results:
            return
        
        fig, axes = plt.subplots(len(self.results), 1, figsize=(12, 4*len(self.results)))
        if len(self.results) == 1:
            axes = [axes]
        
        fig.suptitle('Error Distribution (Actual - Predicted)', fontsize=16, fontweight='bold')
        
        for idx, (name, metrics) in enumerate(self.results.items()):
            errors = self.y_test - metrics['y_test_pred']
            
            axes[idx].hist(errors, bins=30, edgecolor='black', alpha=0.7, color=sns.color_palette("husl", len(self.results))[idx])
            axes[idx].axvline(x=0, color='r', linestyle='--', lw=2, label='Zero Error')
            axes[idx].axvline(x=np.mean(errors), color='g', linestyle='--', lw=2, label=f'Mean: {np.mean(errors):.2f}')
            axes[idx].set_xlabel('Error (Actual - Predicted) kcal/100g', fontweight='bold')
            axes[idx].set_ylabel('Frequency', fontweight='bold')
            axes[idx].set_title(f'{name} - MAE: {metrics["test_mae"]:.2f}, RMSE: {metrics["test_rmse"]:.2f}', fontweight='bold')
            axes[idx].legend()
            axes[idx].grid(alpha=0.3)
        
        plt.tight_layout()
        plt.savefig(f'{self.output_dir}/error_distribution.png', dpi=300, bbox_inches='tight')
        plt.close()
        print("[OK] Error distribution plots saved")
    
    # %% [markdown]
    # ### 2.10 Export and Reporting Methods
    
    def export_results_to_csv(self, output_path="training_results/model_comparison.csv"):
        """Export model comparison results to CSV"""
        if not self.results:
            return self
        
        comparison_data = []
        for name, metrics in self.results.items():
            comparison_data.append({
                'Model': name,
                'Test_MAE': metrics['test_mae'],
                'Test_RMSE': metrics['test_rmse'],
                'Test_R2': metrics['test_r2'],
                'Test_MAPE': metrics.get('test_mape', np.nan),
                'Test_EVS': metrics.get('test_evs', np.nan),
                'CV_R2_Mean': metrics['cv_mean'],
                'CV_R2_Std': metrics['cv_std'],
                'Training_Time_Seconds': self.training_times.get(name, 0)
            })
        
        df = pd.DataFrame(comparison_data)
        df = df.sort_values('Test_R2', ascending=False)
        df.to_csv(output_path, index=False)
        print(f"[OK] Results exported to: {output_path}")
        return self
    
    def save_results_report(self, output_path="ML_TRAINING_REPORT.md"):
        """Save detailed training report"""
        print("\n" + "=" * 70)
        print("GENERATING TRAINING REPORT")
        print("=" * 70)
        
        report = f"""# ML Model Training Report

## Training Date
{pd.Timestamp.now().strftime('%Y-%m-%d %H:%M:%S')}

## Dataset Information
- **Source**: {self.csv_path}
- **Total Samples**: {len(self.df)}
- **Training Samples**: {len(self.X_train)}
- **Testing Samples**: {len(self.X_test)}
- **Features**: 13 features
- **Target**: Calories per 100g

## Feature Engineering
1. Name length (integer)
2. Serving size in grams (float)
3. Has category (binary)
4. Has preparation method (binary)
5. Number of ingredients (integer, set to 0)
6-13. Category flags (binary one-hot encoding):
   - meats
   - vegetables
   - fruits
   - grains
   - legumes
   - soups
   - dairy
   - snacks

## Model Experimentation Results

### Comparison Table

| Model | Test MAE | Test RMSE | Test R² | Test MAPE | Test EVS | CV R² Mean | CV R² Std | Training Time |
|-------|----------|-----------|---------|-----------|----------|------------|-----------|---------------|
"""
        
        # Sort by test R²
        sorted_results = sorted(
            self.results.items(),
            key=lambda x: x[1]['test_r2'],
            reverse=True
        )
        
        for name, metrics in sorted_results:
            training_time = self.training_times.get(name, 0)
            mape = metrics.get('test_mape', np.nan)
            evs = metrics.get('test_evs', np.nan)
            mape_str = f"{mape:.2f}%" if not np.isnan(mape) else "N/A"
            report += f"| {name} | {metrics['test_mae']:.2f} | {metrics['test_rmse']:.2f} | {metrics['test_r2']:.4f} | {mape_str} | {evs:.4f} | {metrics['cv_mean']:.4f} | {metrics['cv_std']:.4f} | {training_time:.2f}s |\n"
        
        # Best model
        best_name, best_metrics = sorted_results[0]
        report += f"""
## Best Model: {best_name}

### Performance Metrics
- **Test R²**: {best_metrics['test_r2']:.4f}
- **Test MAE**: {best_metrics['test_mae']:.2f} kcal/100g
- **Test RMSE**: {best_metrics['test_rmse']:.2f} kcal/100g
- **Cross-Validation R²**: {best_metrics['cv_mean']:.4f} (+/- {best_metrics['cv_std']:.4f})

### Model Details
- **Type**: {type(best_metrics['model']).__name__}
- **Parameters**: {best_metrics['model'].get_params()}

## Methodology

### Preprocessing
- **Pipeline**: {'Yes - StandardScaler applied to Linear Regression and KNN' if hasattr(self, 'use_pipeline') and self.use_pipeline else 'No - Raw features used'}
- **Feature Engineering**: 13 features (name length, serving size, category flags, etc.)
- **Data Normalization**: Calories normalized to per 100g basis

### Model Training
- **Hyperparameter Tuning**: {'Enabled with GridSearchCV' if hasattr(self, 'use_hyperparameter_tuning') and self.use_hyperparameter_tuning else 'Disabled - Using default parameters'}
- **Cross-Validation**: 5-fold cross-validation for all models
- **Train/Test Split**: 80/20 split with random_state=42 for reproducibility

## Visualizations

Training visualizations have been generated and saved to `{self.output_dir}/`:

1. **model_comparison.png** - Bar charts comparing all models across different metrics
2. **prediction_scatter.png** - Scatter plots showing predicted vs actual values for each model
3. **feature_importance.png** - Feature importance analysis for tree-based models
4. **training_times.png** - Training time comparison across all models
5. **residual_analysis.png** - Residual analysis for the best model
6. **learning_curves.png** - Learning curves showing model performance vs training set size
7. **error_distribution.png** - Error distribution histograms for all models

## Recommendations

1. **Model Selection**: {best_name} was selected as the best model based on test R² score
2. **Performance**: The model achieves {'good' if best_metrics['test_r2'] > 0.7 else 'moderate' if best_metrics['test_r2'] > 0.5 else 'poor'} performance
3. **Deployment**: Model saved to `model/best_regression_model.joblib`
4. **Monitoring**: Monitor predictions in production and retrain if performance degrades
5. **Visualizations**: Review the generated plots in `{self.output_dir}/` for detailed analysis

## Next Steps

1. Review the visualizations in `{self.output_dir}/` folder
2. Test the model with the comprehensive test suite
3. Deploy to production
4. Monitor prediction quality
5. Collect feedback for future improvements
"""
        
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(report)
        
        print(f"Report saved to: {output_path}")
        return self

# %% [markdown]
# ## 3. Main Training Pipeline
# 
# This function runs the complete training process:
# 1. Loads and prepares data
# 2. Initializes models
# 3. Trains and evaluates all models
# 4. Creates visualizations
# 5. Saves the best model

# %%
def main():
    """Main training pipeline"""
    print("=" * 70)
    print("ML MODEL TRAINING WITH EXPERIMENTATION")
    print("=" * 70)
    
    try:
        # Initialize trainer
        trainer = CalorieModelTrainer()
        
        # Load and prepare data
        trainer.load_data()
        trainer.prepare_features()
        trainer.split_data()
        
        # Initialize and train models (with pipeline and optional hyperparameter tuning)
        trainer.initialize_models(use_pipeline=True, use_hyperparameter_tuning=False)
        trainer.train_and_evaluate_models()
        
        # Compare models
        trainer.print_comparison_table()
        
        # Select and save best model
        best_name, best_model = trainer.select_best_model()
        
        if best_model:
            # Test predictions
            trainer.test_predictions(best_model, best_name)
            
            # Create visualizations
            trainer.create_visualizations()
            
            # Export results to CSV
            trainer.export_results_to_csv()
            
            # Save model
            trainer.save_model(best_model, best_name)
            
            # Save report
            trainer.save_results_report()
            
            print("\n" + "=" * 70)
            print("TRAINING COMPLETE!")
            print("=" * 70)
            print(f"Best model: {best_name}")
            print("Model saved and ready for deployment")
        else:
            print("ERROR: No model was trained successfully!")
            return 1
        
        return 0
        
    except Exception as e:
        print(f"\nERROR: Training failed: {e}")
        import traceback
        traceback.print_exc()
        return 1

# %% [markdown]
# ## 4. Run Training
# 
# **For Google Colab:** You can also run individual steps manually:
# ```python
# trainer = CalorieModelTrainer()
# trainer.load_data()
# trainer.prepare_features()
# trainer.split_data()
# trainer.initialize_models(use_pipeline=True, use_hyperparameter_tuning=False)
# trainer.train_and_evaluate_models()
# trainer.print_comparison_table()
# best_name, best_model = trainer.select_best_model()
# trainer.create_visualizations()
# trainer.export_results_to_csv()
# trainer.save_model(best_model, best_name)
# trainer.save_results_report()
# ```

# %%
if __name__ == "__main__":
    exit(main())

