"""
Calculate target calories for muscle gain
Based on: Male, 25 years old, 70 kg weight, 170 cm height
"""

def calculate_bmr_mifflin_st_jeor(weight_kg, height_cm, age, gender):
    """
    Calculate Basal Metabolic Rate using Mifflin-St Jeor Equation
    Most accurate BMR formula
    """
    if gender.lower() == 'male':
        bmr = 10 * weight_kg + 6.25 * height_cm - 5 * age + 5
    else:  # female
        bmr = 10 * weight_kg + 6.25 * height_cm - 5 * age - 161
    return bmr

def calculate_tdee(bmr, activity_level):
    """
    Calculate Total Daily Energy Expenditure
    Activity multipliers:
    - Sedentary (little/no exercise): 1.2
    - Lightly active (light exercise 1-3 days/week): 1.375
    - Moderately active (moderate exercise 3-5 days/week): 1.55
    - Very active (hard exercise 6-7 days/week): 1.725
    - Extremely active (very hard exercise, physical job): 1.9
    """
    activity_multipliers = {
        'sedentary': 1.2,
        'lightly active': 1.375,
        'moderately active': 1.55,
        'very active': 1.725,
        'extremely active': 1.9
    }
    return bmr * activity_multipliers.get(activity_level.lower(), 1.55)

def calculate_muscle_gain_calories(tdee, surplus=400):
    """
    Calculate target calories for muscle gain
    Typical surplus: 300-500 calories per day
    """
    return tdee + surplus

# Your stats
age = 25
weight_kg = 70
height_cm = 170
gender = 'male'

# Calculate BMR
bmr = calculate_bmr_mifflin_st_jeor(weight_kg, height_cm, age, gender)

print("=" * 60)
print("TARGET CALORIE CALCULATION FOR MUSCLE GAIN")
print("=" * 60)
print(f"\nYour Stats:")
print(f"  Age: {age} years")
print(f"  Weight: {weight_kg} kg ({weight_kg * 2.20462:.1f} lbs)")
print(f"  Height: {height_cm} cm ({height_cm / 2.54:.1f} inches)")
print(f"  Gender: {gender.title()}")
print(f"\nBasal Metabolic Rate (BMR): {bmr:.0f} calories/day")
print("\n" + "-" * 60)
print("Total Daily Energy Expenditure (TDEE) by Activity Level:")
print("-" * 60)

activity_levels = [
    ('Sedentary', 'sedentary'),
    ('Lightly Active', 'lightly active'),
    ('Moderately Active', 'moderately active'),
    ('Very Active', 'very active'),
    ('Extremely Active', 'extremely active')
]

results = []
for level_name, level_key in activity_levels:
    tdee = calculate_tdee(bmr, level_key)
    target_calories_300 = calculate_muscle_gain_calories(tdee, 300)
    target_calories_400 = calculate_muscle_gain_calories(tdee, 400)
    target_calories_500 = calculate_muscle_gain_calories(tdee, 500)
    
    results.append({
        'level': level_name,
        'tdee': tdee,
        'target_300': target_calories_300,
        'target_400': target_calories_400,
        'target_500': target_calories_500
    })
    
    print(f"\n{level_name}:")
    print(f"  TDEE: {tdee:.0f} calories/day")
    print(f"  Target for Muscle Gain:")
    print(f"    Conservative (+300): {target_calories_300:.0f} calories/day")
    print(f"    Moderate (+400): {target_calories_400:.0f} calories/day")
    print(f"    Aggressive (+500): {target_calories_500:.0f} calories/day")

print("\n" + "=" * 60)
print("RECOMMENDATIONS:")
print("=" * 60)
print("""
For muscle gain, aim for:
• 300-500 calorie surplus above your TDEE
• 1.6-2.2g protein per kg body weight (112-154g protein/day for you)
• Strength training 3-5 times per week
• Adequate sleep (7-9 hours)
• Progressive overload in your workouts

Most people training for muscle gain fall into "Moderately Active" or "Very Active" categories.
If you're doing strength training 3-5 days/week, use "Moderately Active" as your baseline.
""")

# Show recommended target based on moderate activity
recommended_tdee = calculate_tdee(bmr, 'moderately active')
recommended_target = calculate_muscle_gain_calories(recommended_tdee, 400)
print(f"\n>>> RECOMMENDED TARGET: {recommended_target:.0f} calories/day")
print(f"   (Based on Moderately Active + 400 calorie surplus)")
print(f"   Protein target: 140-154g per day (560-616 calories)")
print(f"   Carbs: ~40-50% of calories ({(recommended_target * 0.45) / 4:.0f}g = {recommended_target * 0.45:.0f} calories)")
print(f"   Fats: ~20-30% of calories ({(recommended_target * 0.25) / 9:.0f}g = {recommended_target * 0.25:.0f} calories)")

