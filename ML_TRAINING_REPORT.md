# ML Model Training Report

## Training Date
2025-11-20 03:17:04

## Dataset Information
- **Source**: data/Filipino_Food_Nutrition_Dataset.csv
- **Total Samples**: 991
- **Training Samples**: 790
- **Testing Samples**: 198
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
| Decision Tree | 1700.04 | 3278.81 | 0.9365 | 0.39% | 0.9366 | 0.9271 | 0.0234 | 0.00s |
| Random Forest | 1704.39 | 3295.44 | 0.9359 | 0.42% | 0.9359 | 0.9275 | 0.0231 | 0.12s |
| K-Nearest Neighbors (KNN) | 2193.97 | 4262.85 | 0.8927 | 1.46% | 0.8960 | 0.8795 | 0.0273 | 0.00s |
| Linear Regression | 4571.30 | 6214.73 | 0.7720 | 18.37% | 0.7738 | -857327652449789109338112.0000 | 1713339870908623943106560.0000 | 0.00s |

## Best Model: Decision Tree

### Performance Metrics
- **Test R²**: 0.9365
- **Test MAE**: 1700.04 kcal/100g
- **Test RMSE**: 3278.81 kcal/100g
- **Cross-Validation R²**: 0.9271 (+/- 0.0234)

### Model Details
- **Type**: DecisionTreeRegressor
- **Parameters**: {'ccp_alpha': 0.0, 'criterion': 'squared_error', 'max_depth': 10, 'max_features': None, 'max_leaf_nodes': None, 'min_impurity_decrease': 0.0, 'min_samples_leaf': 1, 'min_samples_split': 2, 'min_weight_fraction_leaf': 0.0, 'random_state': 42, 'splitter': 'best'}

## Methodology

### Preprocessing
- **Pipeline**: Yes - StandardScaler applied to Linear Regression and KNN
- **Feature Engineering**: 13 features (name length, serving size, category flags, etc.)
- **Data Normalization**: Calories normalized to per 100g basis

### Model Training
- **Hyperparameter Tuning**: Disabled - Using default parameters
- **Cross-Validation**: 5-fold cross-validation for all models
- **Train/Test Split**: 80/20 split with random_state=42 for reproducibility

## Visualizations

Training visualizations have been generated and saved to `training_results/`:

1. **model_comparison.png** - Bar charts comparing all models across different metrics
2. **prediction_scatter.png** - Scatter plots showing predicted vs actual values for each model
3. **feature_importance.png** - Feature importance analysis for tree-based models
4. **training_times.png** - Training time comparison across all models
5. **residual_analysis.png** - Residual analysis for the best model
6. **learning_curves.png** - Learning curves showing model performance vs training set size
7. **error_distribution.png** - Error distribution histograms for all models

## Recommendations

1. **Model Selection**: Decision Tree was selected as the best model based on test R² score
2. **Performance**: The model achieves good performance
3. **Deployment**: Model saved to `model/best_regression_model.joblib`
4. **Monitoring**: Monitor predictions in production and retrain if performance degrades
5. **Visualizations**: Review the generated plots in `training_results/` for detailed analysis

## Next Steps

1. Review the visualizations in `training_results/` folder
2. Test the model with the comprehensive test suite
3. Deploy to production
4. Monitor prediction quality
5. Collect feedback for future improvements
