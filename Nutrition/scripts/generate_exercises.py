"""
Generate scientifically accurate exercise database for health app.
Based on ACSM, ACE, NSCA guidelines and Compendium of Physical Activities MET values.
"""
import csv
import os

PROJECT_ROOT = os.path.dirname(os.path.dirname(__file__))
CSV_PATH = os.path.join(PROJECT_ROOT, "data", "exercises.csv")

# MET values from Compendium of Physical Activities (Ainsworth et al.)
# Calories per minute ≈ MET × 3.5 × weight(kg) / 200
# Using average 70kg person: cal/min ≈ MET × 1.225

def met_to_calories(met_value):
    """Convert MET to calories per minute for 70kg person"""
    return round(met_value * 1.225, 1)

# ============================================================================
# CARDIO EXERCISES (~400)
# ============================================================================

CARDIO_EXERCISES = []
exercise_id = 1

# Running (various intensities and types)
running_variants = [
    ("Running — Jogging, General", "legs", "cardiovascular", "body weight", 7.0, "Maintain steady pace; Land midfoot; Keep upright posture; Breathe rhythmically", "cardio,running,outdoor"),
    ("Running — 5 mph (12 min/mile)", "legs", "cardiovascular", "body weight", 8.3, "Steady pace; Control breathing; Maintain form; Stay relaxed", "cardio,running"),
    ("Running — 6 mph (10 min/mile)", "legs", "cardiovascular", "body weight", 9.8, "Moderate pace; Rhythmic breathing; Good posture; Consistent stride", "cardio,running"),
    ("Running — 7 mph (8.5 min/mile)", "legs", "cardiovascular", "body weight", 11.0, "Faster pace; Deep breathing; Strong arm swing; Forward lean", "cardio,running"),
    ("Running — 8 mph (7.5 min/mile)", "legs", "cardiovascular", "body weight", 11.8, "Fast pace; Controlled breathing; Efficient form; Quick turnover", "cardio,running,advanced"),
    ("Running — 10 mph (6 min/mile)", "legs", "cardiovascular", "body weight", 14.5, "Sprint pace; Explosive power; Maximum effort; Elite level", "cardio,running,advanced"),
    ("Running — Uphill", "legs", "cardiovascular", "body weight", 10.5, "Lean forward; Short steps; Drive knees up; Power through legs", "cardio,running,hills"),
    ("Running — Trail Running", "full body", "cardiovascular", "body weight", 9.0, "Watch footing; Adjust pace; Use arms for balance; Stay alert", "cardio,running,outdoor,trail"),
    ("Running — Stairs", "legs", "cardiovascular", "body weight", 15.0, "Drive through legs; Use arms; Quick feet; Breathe deeply", "cardio,stairs,intense"),
    ("Running — High Knees", "legs", "cardiovascular", "body weight", 10.0, "Drive knees to chest; Quick tempo; Stay on toes; Engage core", "cardio,hiit,running"),
]

difficulties = ["Beginner", "Intermediate", "Advanced"]
for base_name, body_part, target, equipment, met, instructions, tags in running_variants:
    for difficulty in difficulties:
        met_adjusted = met * (0.85 if difficulty == "Beginner" else 1.0 if difficulty == "Intermediate" else 1.15)
        CARDIO_EXERCISES.append({
            "id": f"cardio_{exercise_id}",
            "name": f"{base_name} — {difficulty}",
            "category": "Cardio",
            "body_part": body_part,
            "target": target,
            "equipment": equipment,
            "difficulty": difficulty,
            "calories_per_minute": met_to_calories(met_adjusted),
            "instructions": instructions,
            "tags": tags
        })
        exercise_id += 1

# Cycling
cycling_variants = [
    ("Cycling — Stationary, Light", "legs", "cardiovascular", "machine", 3.5, "Steady pace; Adjust resistance; Maintain posture; Control breathing", "cardio,cycling,lowimpact"),
    ("Cycling — Stationary, Moderate", "legs", "cardiovascular", "machine", 6.8, "Moderate resistance; Steady cadence; Upright position; Rhythmic pedaling", "cardio,cycling"),
    ("Cycling — Stationary, Vigorous", "legs", "cardiovascular", "machine", 8.8, "High resistance; Fast cadence; Good form; Intense effort", "cardio,cycling,intense"),
    ("Cycling — Outdoor, Leisure (10-12 mph)", "legs", "cardiovascular", "body weight", 6.0, "Comfortable pace; Enjoy ride; Maintain balance; Safe riding", "cardio,cycling,outdoor"),
    ("Cycling — Outdoor, Moderate (12-14 mph)", "legs", "cardiovascular", "body weight", 8.0, "Steady pace; Efficient pedaling; Road awareness; Good form", "cardio,cycling,outdoor"),
    ("Cycling — Outdoor, Fast (14-16 mph)", "legs", "cardiovascular", "body weight", 10.0, "Brisk pace; Power through legs; Aerodynamic position; Strong effort", "cardio,cycling,outdoor"),
    ("Cycling — Outdoor, Racing (16-20 mph)", "legs", "cardiovascular", "body weight", 12.0, "Race pace; Maximum efficiency; Aero position; High intensity", "cardio,cycling,advanced"),
    ("Cycling — Mountain Biking", "full body", "cardiovascular", "body weight", 8.5, "Variable terrain; Adjust gears; Use core; Control bike", "cardio,cycling,outdoor,mountain"),
    ("Cycling — Spinning Class", "legs", "cardiovascular", "machine", 8.5, "Follow instructor; Vary resistance; Match tempo; Push effort", "cardio,cycling,class"),
]

for base_name, body_part, target, equipment, met, instructions, tags in cycling_variants:
    for difficulty in difficulties:
        met_adjusted = met * (0.85 if difficulty == "Beginner" else 1.0 if difficulty == "Intermediate" else 1.15)
        CARDIO_EXERCISES.append({
            "id": f"cardio_{exercise_id}",
            "name": f"{base_name} — {difficulty}",
            "category": "Cardio",
            "body_part": body_part,
            "target": target,
            "equipment": equipment,
            "difficulty": difficulty,
            "calories_per_minute": met_to_calories(met_adjusted),
            "instructions": instructions,
            "tags": tags
        })
        exercise_id += 1

# Swimming
swimming_variants = [
    ("Swimming — Freestyle, Slow", "full body", "cardiovascular", "body weight", 5.8, "Long strokes; Rotate body; Bilateral breathing; Glide phase", "cardio,swimming,lowimpact"),
    ("Swimming — Freestyle, Moderate", "full body", "cardiovascular", "body weight", 8.3, "Efficient strokes; Good rotation; Steady breathing; Streamlined", "cardio,swimming"),
    ("Swimming — Freestyle, Fast", "full body", "cardiovascular", "body weight", 9.8, "Quick tempo; Power pull; Fast kicks; High intensity", "cardio,swimming,intense"),
    ("Swimming — Backstroke", "full body", "cardiovascular", "body weight", 7.0, "Straight body; Rotate shoulders; Steady kicks; Look up", "cardio,swimming"),
    ("Swimming — Breaststroke", "full body", "cardiovascular", "body weight", 6.8, "Pull-breathe-kick-glide; Wide pull; Frog kick; Timing crucial", "cardio,swimming"),
    ("Swimming — Butterfly", "full body", "cardiovascular", "body weight", 11.0, "Dolphin kicks; Wave motion; Powerful pull; Advanced technique", "cardio,swimming,advanced"),
    ("Swimming — Treading Water, Moderate", "full body", "cardiovascular", "body weight", 3.5, "Stay afloat; Circular kicks; Scull hands; Steady effort", "cardio,swimming,lowimpact"),
    ("Swimming — Water Aerobics", "full body", "cardiovascular", "body weight", 5.5, "Follow routine; Use water resistance; Full range; Keep moving", "cardio,swimming,class,lowimpact"),
]

for base_name, body_part, target, equipment, met, instructions, tags in swimming_variants:
    for difficulty in difficulties:
        met_adjusted = met * (0.85 if difficulty == "Beginner" else 1.0 if difficulty == "Intermediate" else 1.15)
        CARDIO_EXERCISES.append({
            "id": f"cardio_{exercise_id}",
            "name": f"{base_name} — {difficulty}",
            "category": "Cardio",
            "body_part": body_part,
            "target": target,
            "equipment": equipment,
            "difficulty": difficulty,
            "calories_per_minute": met_to_calories(met_adjusted),
            "instructions": instructions,
            "tags": tags
        })
        exercise_id += 1

# Rowing
rowing_variants = [
    ("Rowing Machine — Light", "full body", "cardiovascular", "machine", 3.5, "Smooth strokes; Legs-back-arms sequence; Control return; Steady rhythm", "cardio,rowing,lowimpact"),
    ("Rowing Machine — Moderate", "full body", "cardiovascular", "machine", 7.0, "Powerful drive; Good technique; Consistent pace; Full extension", "cardio,rowing"),
    ("Rowing Machine — Vigorous", "full body", "cardiovascular", "machine", 8.5, "Explosive power; Fast stroke rate; Maximum effort; Elite technique", "cardio,rowing,intense"),
    ("Rowing Machine — Intervals", "full body", "cardiovascular", "machine", 9.5, "Sprint-rest cycles; High intensity; Recovery periods; Pace variation", "cardio,rowing,hiit"),
]

for base_name, body_part, target, equipment, met, instructions, tags in rowing_variants:
    for difficulty in difficulties:
        met_adjusted = met * (0.85 if difficulty == "Beginner" else 1.0 if difficulty == "Intermediate" else 1.15)
        CARDIO_EXERCISES.append({
            "id": f"cardio_{exercise_id}",
            "name": f"{base_name} — {difficulty}",
            "category": "Cardio",
            "body_part": body_part,
            "target": target,
            "equipment": equipment,
            "difficulty": difficulty,
            "calories_per_minute": met_to_calories(met_adjusted),
            "instructions": instructions,
            "tags": tags
        })
        exercise_id += 1

# Jump Rope
jump_rope_variants = [
    ("Jump Rope — Slow", "full body", "cardiovascular", "body weight", 8.0, "Steady bounces; Wrist turns rope; Land softly; Rhythm important", "cardio,jumprope"),
    ("Jump Rope — Moderate", "full body", "cardiovascular", "body weight", 10.0, "Quick tempo; Stay on toes; Tight jumps; Coordinated", "cardio,jumprope"),
    ("Jump Rope — Fast", "full body", "cardiovascular", "body weight", 12.0, "High speed; Minimal ground contact; Quick wrist; Intense", "cardio,jumprope,intense"),
    ("Jump Rope — Double Unders", "full body", "cardiovascular", "body weight", 12.5, "Two rope passes per jump; Explosive jump; Fast wrist; Advanced skill", "cardio,jumprope,advanced"),
]

for base_name, body_part, target, equipment, met, instructions, tags in jump_rope_variants:
    for difficulty in difficulties:
        met_adjusted = met * (0.85 if difficulty == "Beginner" else 1.0 if difficulty == "Intermediate" else 1.15)
        CARDIO_EXERCISES.append({
            "id": f"cardio_{exercise_id}",
            "name": f"{base_name} — {difficulty}",
            "category": "Cardio",
            "body_part": body_part,
            "target": target,
            "equipment": equipment,
            "difficulty": difficulty,
            "calories_per_minute": met_to_calories(met_adjusted),
            "instructions": instructions,
            "tags": tags
        })
        exercise_id += 1

# Elliptical
elliptical_variants = [
    ("Elliptical — Light", "full body", "cardiovascular", "machine", 4.5, "Smooth motion; Light resistance; Upright posture; Steady pace", "cardio,elliptical,lowimpact"),
    ("Elliptical — Moderate", "full body", "cardiovascular", "machine", 5.0, "Moderate resistance; Use handles; Full stride; Consistent effort", "cardio,elliptical"),
    ("Elliptical — Vigorous", "full body", "cardiovascular", "machine", 6.0, "High resistance; Fast tempo; Power through; Intense workout", "cardio,elliptical,intense"),
]

for base_name, body_part, target, equipment, met, instructions, tags in elliptical_variants:
    for difficulty in difficulties:
        met_adjusted = met * (0.85 if difficulty == "Beginner" else 1.0 if difficulty == "Intermediate" else 1.15)
        CARDIO_EXERCISES.append({
            "id": f"cardio_{exercise_id}",
            "name": f"{base_name} — {difficulty}",
            "category": "Cardio",
            "body_part": body_part,
            "target": target,
            "equipment": equipment,
            "difficulty": difficulty,
            "calories_per_minute": met_to_calories(met_adjusted),
            "instructions": instructions,
            "tags": tags
        })
        exercise_id += 1

# Walking
walking_variants = [
    ("Walking — Slow (2 mph)", "legs", "cardiovascular", "body weight", 2.5, "Leisurely pace; Natural gait; Relaxed; Good for recovery", "cardio,walking,lowimpact"),
    ("Walking — Moderate (3 mph)", "legs", "cardiovascular", "body weight", 3.5, "Brisk pace; Purposeful stride; Swing arms; Steady breathing", "cardio,walking"),
    ("Walking — Brisk (3.5 mph)", "legs", "cardiovascular", "body weight", 4.3, "Fast walk; Increased effort; Pumping arms; Elevated heart rate", "cardio,walking"),
    ("Walking — Very Brisk (4 mph)", "legs", "cardiovascular", "body weight", 5.0, "Very fast walk; Nearly jogging; Strong arm swing; High intensity", "cardio,walking,intense"),
    ("Walking — Uphill", "legs", "cardiovascular", "body weight", 6.0, "Incline walk; Lean slightly forward; Shorter steps; Use glutes", "cardio,walking,hills"),
    ("Walking — Treadmill, 5% incline", "legs", "cardiovascular", "machine", 6.0, "Inclined surface; Don't hold rails; Natural stride; Good posture", "cardio,walking,treadmill"),
]

for base_name, body_part, target, equipment, met, instructions, tags in walking_variants:
    for difficulty in difficulties:
        met_adjusted = met * (0.85 if difficulty == "Beginner" else 1.0 if difficulty == "Intermediate" else 1.15)
        CARDIO_EXERCISES.append({
            "id": f"cardio_{exercise_id}",
            "name": f"{base_name} — {difficulty}",
            "category": "Cardio",
            "body_part": body_part,
            "target": target,
            "equipment": equipment,
            "difficulty": difficulty,
            "calories_per_minute": met_to_calories(met_adjusted),
            "instructions": instructions,
            "tags": tags
        })
        exercise_id += 1

# HIIT / Bodyweight Cardio
hiit_variants = [
    ("Burpees", "full body", "cardiovascular", "body weight", 8.0, "Squat-plank-jump sequence; Explosive movement; Land softly; Keep core tight", "cardio,hiit,bodyweight"),
    ("Mountain Climbers — Cardio", "full body", "cardiovascular", "body weight", 8.0, "Plank position; Drive knees to chest; Quick tempo; Keep hips low", "cardio,hiit,core"),
    ("Jumping Jacks", "full body", "cardiovascular", "body weight", 8.0, "Jump while spreading legs; Raise arms overhead; Land softly; Continuous motion", "cardio,hiit,bodyweight"),
    ("High Knees", "legs", "cardiovascular", "body weight", 8.0, "Run in place; Drive knees high; Quick tempo; Pump arms", "cardio,hiit,running"),
    ("Butt Kicks", "legs", "cardiovascular", "body weight", 8.0, "Run in place; Kick heels to glutes; Quick feet; Stay upright", "cardio,hiit,running"),
    ("Box Jumps", "legs", "power", "body weight", 8.0, "Jump onto platform; Land softly; Full hip extension; Step down", "cardio,plyometric,power"),
    ("Lateral Shuffles", "legs", "cardiovascular", "body weight", 6.0, "Side to side movement; Stay low; Quick feet; Athletic stance", "cardio,agility"),
    ("Tuck Jumps", "legs", "power", "body weight", 10.0, "Jump and tuck knees; Explosive power; Land softly; Advanced move", "cardio,plyometric,advanced"),
    ("Skater Hops", "legs", "cardiovascular", "body weight", 7.0, "Side-to-side jumps; Single leg landing; Lateral power; Balance", "cardio,plyometric,agility"),
    ("Plank Jacks", "core", "cardiovascular", "body weight", 7.0, "Plank position; Jump feet out and in; Keep core stable; Don't sag", "cardio,hiit,core"),
]

for base_name, body_part, target, equipment, met, instructions, tags in hiit_variants:
    for difficulty in difficulties:
        met_adjusted = met * (0.85 if difficulty == "Beginner" else 1.0 if difficulty == "Intermediate" else 1.15)
        CARDIO_EXERCISES.append({
            "id": f"cardio_{exercise_id}",
            "name": f"{base_name} — {difficulty}",
            "category": "Cardio",
            "body_part": body_part,
            "target": target,
            "equipment": equipment,
            "difficulty": difficulty,
            "calories_per_minute": met_to_calories(met_adjusted),
            "instructions": instructions,
            "tags": tags
        })
        exercise_id += 1

# Boxing / Martial Arts
combat_variants = [
    ("Boxing — Heavy Bag", "full body", "cardiovascular", "body weight", 7.8, "Punch combinations; Rotate hips; Stay light on feet; Guard up", "cardio,boxing,combat"),
    ("Boxing — Speed Bag", "upper body", "cardiovascular", "body weight", 6.0, "Rhythmic punching; Hand-eye coordination; Shoulder endurance; Timing", "cardio,boxing"),
    ("Kickboxing", "full body", "cardiovascular", "body weight", 10.0, "Punches and kicks; Powerful strikes; Stay balanced; High intensity", "cardio,kickboxing,combat"),
    ("Shadow Boxing", "full body", "cardiovascular", "body weight", 7.0, "Punch combinations; Footwork; Defensive moves; Visualize opponent", "cardio,boxing,combat"),
    ("Martial Arts — Sparring", "full body", "cardiovascular", "body weight", 10.0, "Controlled combat; Technique focus; Cardio intensive; Advanced skill", "cardio,martialarts,advanced"),
]

for base_name, body_part, target, equipment, met, instructions, tags in combat_variants:
    for difficulty in difficulties:
        met_adjusted = met * (0.85 if difficulty == "Beginner" else 1.0 if difficulty == "Intermediate" else 1.15)
        CARDIO_EXERCISES.append({
            "id": f"cardio_{exercise_id}",
            "name": f"{base_name} — {difficulty}",
            "category": "Cardio",
            "body_part": body_part,
            "target": target,
            "equipment": equipment,
            "difficulty": difficulty,
            "calories_per_minute": met_to_calories(met_adjusted),
            "instructions": instructions,
            "tags": tags
        })
        exercise_id += 1

# Stair Climbing
stair_variants = [
    ("Stair Climbing — Slow", "legs", "cardiovascular", "body weight", 4.0, "Steady pace; Full foot on step; Use rails if needed; Controlled", "cardio,stairs,lowimpact"),
    ("Stair Climbing — Moderate", "legs", "cardiovascular", "body weight", 6.0, "Brisk pace; Push through legs; Swing arms; Rhythmic", "cardio,stairs"),
    ("Stair Climbing — Fast", "legs", "cardiovascular", "body weight", 8.0, "Fast pace; Power through; Quick feet; Intense effort", "cardio,stairs,intense"),
    ("Stair Climber Machine", "legs", "cardiovascular", "machine", 9.0, "Continuous stepping; Don't lean on handles; Full range; Steady tempo", "cardio,stairs,machine"),
]

for base_name, body_part, target, equipment, met, instructions, tags in stair_variants:
    for difficulty in difficulties:
        met_adjusted = met * (0.85 if difficulty == "Beginner" else 1.0 if difficulty == "Intermediate" else 1.15)
        CARDIO_EXERCISES.append({
            "id": f"cardio_{exercise_id}",
            "name": f"{base_name} — {difficulty}",
            "category": "Cardio",
            "body_part": body_part,
            "target": target,
            "equipment": equipment,
            "difficulty": difficulty,
            "calories_per_minute": met_to_calories(met_adjusted),
            "instructions": instructions,
            "tags": tags
        })
        exercise_id += 1

# Dance
dance_variants = [
    ("Dancing — General", "full body", "cardiovascular", "body weight", 4.5, "Move to music; Enjoy rhythm; Full body movement; Have fun", "cardio,dance"),
    ("Dancing — Aerobic, High Impact", "full body", "cardiovascular", "body weight", 7.0, "Choreographed moves; Follow instructor; High energy; Jumping", "cardio,dance,class"),
    ("Dancing — Zumba", "full body", "cardiovascular", "body weight", 8.5, "Latin-inspired; Follow routine; High energy; Fun workout", "cardio,dance,class,zumba"),
    ("Dancing — Hip Hop", "full body", "cardiovascular", "body weight", 6.5, "Urban moves; Rhythm important; Creative expression; Street style", "cardio,dance,hiphop"),
    ("Dancing — Ballet", "full body", "cardiovascular", "body weight", 5.0, "Classical technique; Grace and control; Flexibility; Posture", "cardio,dance,ballet"),
]

for base_name, body_part, target, equipment, met, instructions, tags in dance_variants:
    for difficulty in difficulties:
        met_adjusted = met * (0.85 if difficulty == "Beginner" else 1.0 if difficulty == "Intermediate" else 1.15)
        CARDIO_EXERCISES.append({
            "id": f"cardio_{exercise_id}",
            "name": f"{base_name} — {difficulty}",
            "category": "Cardio",
            "body_part": body_part,
            "target": target,
            "equipment": equipment,
            "difficulty": difficulty,
            "calories_per_minute": met_to_calories(met_adjusted),
            "instructions": instructions,
            "tags": tags
        })
        exercise_id += 1

# Battle Ropes
battle_rope_variants = [
    ("Battle Ropes — Alternating Waves", "full body", "cardiovascular", "body weight", 10.0, "Alternate arms; Create waves; Core engaged; Explosive power", "cardio,battleropes,hiit"),
    ("Battle Ropes — Double Waves", "full body", "cardiovascular", "body weight", 10.0, "Both arms together; Big waves; Hip hinge; Power from core", "cardio,battleropes,hiit"),
    ("Battle Ropes — Slams", "full body", "power", "body weight", 11.0, "Lift high and slam down; Explosive movement; Full body power; Intense", "cardio,battleropes,power"),
]

for base_name, body_part, target, equipment, met, instructions, tags in battle_rope_variants:
    for difficulty in difficulties:
        met_adjusted = met * (0.85 if difficulty == "Beginner" else 1.0 if difficulty == "Intermediate" else 1.15)
        CARDIO_EXERCISES.append({
            "id": f"cardio_{exercise_id}",
            "name": f"{base_name} — {difficulty}",
            "category": "Cardio",
            "body_part": body_part,
            "target": target,
            "equipment": equipment,
            "difficulty": difficulty,
            "calories_per_minute": met_to_calories(met_adjusted),
            "instructions": instructions,
            "tags": tags
        })
        exercise_id += 1

# Sports and Recreation
sports_variants = [
    ("Basketball — Game", "full body", "cardiovascular", "body weight", 6.5, "Running; Jumping; Sprinting; Full body workout; Game pace", "cardio,sports,basketball"),
    ("Basketball — Shooting Around", "full body", "cardiovascular", "body weight", 4.5, "Casual shooting; Light movement; Recreation", "cardio,sports,basketball"),
    ("Soccer — Game", "full body", "cardiovascular", "body weight", 7.0, "Running; Kicking; Sprinting; Endurance; Game pace", "cardio,sports,soccer"),
    ("Soccer — Casual", "full body", "cardiovascular", "body weight", 5.0, "Light play; Recreation; Enjoyable", "cardio,sports,soccer"),
    ("Tennis — Singles", "full body", "cardiovascular", "body weight", 8.0, "Side to side; Sprinting; Swinging; High intensity", "cardio,sports,tennis"),
    ("Tennis — Doubles", "full body", "cardiovascular", "body weight", 6.0, "Less running; Strategic; Moderate intensity", "cardio,sports,tennis"),
    ("Volleyball — Game", "full body", "cardiovascular", "body weight", 4.0, "Jumping; Diving; Quick movements; Team sport", "cardio,sports,volleyball"),
    ("Volleyball — Beach", "full body", "cardiovascular", "body weight", 8.0, "Sand resistance; Jumping; Very intense; Outdoor", "cardio,sports,volleyball"),
    ("Badminton", "full body", "cardiovascular", "body weight", 5.5, "Quick movements; Hand-eye coordination; Moderate pace", "cardio,sports,badminton"),
    ("Racquetball", "full body", "cardiovascular", "body weight", 7.0, "Fast-paced; Court coverage; High intensity", "cardio,sports,racquetball"),
    ("Squash", "full body", "cardiovascular", "body weight", 12.0, "Very intense; Constant movement; High cardio", "cardio,sports,squash"),
    ("Rock Climbing — Indoor", "full body", "strength", "body weight", 8.0, "Climbing wall; Grip strength; Full body; Problem solving", "cardio,climbing,strength"),
    ("Rock Climbing — Outdoor", "full body", "strength", "body weight", 8.0, "Real rock; Technical; Endurance; Adventure", "cardio,climbing,strength,outdoor"),
    ("Hiking — Moderate Terrain", "legs", "cardiovascular", "body weight", 6.0, "Varied terrain; Steady pace; Nature; Endurance", "cardio,hiking,outdoor"),
    ("Hiking — Steep Terrain", "legs", "cardiovascular", "body weight", 7.5, "Uphill; Challenging; Leg strength; Cardio", "cardio,hiking,outdoor"),
    ("Kayaking — Moderate", "upper body", "cardiovascular", "body weight", 5.0, "Paddling; Upper body endurance; Core; Water", "cardio,paddling,outdoor"),
    ("Kayaking — Vigorous", "upper body", "cardiovascular", "body weight", 12.5, "Fast paddling; High intensity; Racing pace", "cardio,paddling,outdoor"),
    ("Canoeing", "upper body", "cardiovascular", "body weight", 3.5, "Paddling; Upper body; Leisurely; Water activity", "cardio,paddling,outdoor"),
    ("Stand-Up Paddleboarding", "full body", "cardiovascular", "body weight", 6.0, "Balance; Paddling; Core engagement; Water", "cardio,paddling,balance,outdoor"),
    ("Surfing", "full body", "cardiovascular", "body weight", 3.0, "Paddling; Balancing; Riding waves; Ocean sport", "cardio,surfing,balance,outdoor"),
    ("Skateboarding", "full body", "cardiovascular", "body weight", 5.0, "Balance; Leg strength; Tricks; Urban sport", "cardio,skateboarding,balance"),
    ("Rollerblading", "legs", "cardiovascular", "body weight", 7.0, "Skating; Leg endurance; Balance; Outdoor", "cardio,skating,outdoor"),
    ("Ice Skating", "legs", "cardiovascular", "body weight", 7.0, "Skating; Balance; Leg strength; Winter sport", "cardio,skating"),
    ("Cross-Country Skiing", "full body", "cardiovascular", "body weight", 9.0, "Full body; Endurance; Winter; High cardio", "cardio,skiing,outdoor,winter"),
    ("Downhill Skiing — Moderate", "legs", "cardiovascular", "body weight", 5.5, "Leg control; Balance; Mountain sport", "cardio,skiing,outdoor,winter"),
    ("Snowboarding", "legs", "cardiovascular", "body weight", 5.5, "Balance; Leg strength; Mountain sport", "cardio,snowboarding,outdoor,winter"),
    ("Golf — Walking Course", "full body", "cardiovascular", "body weight", 4.3, "Walking; Swinging; Leisure sport; Outdoor", "cardio,golf,outdoor"),
    ("Golf — Carrying Clubs", "full body", "cardiovascular", "body weight", 5.5, "Walking with weight; Moderate effort", "cardio,golf,outdoor"),
    ("Bowling", "upper body", "cardiovascular", "body weight", 3.0, "Controlled movement; Recreation; Social", "cardio,bowling"),
    ("Frisbee — Ultimate", "full body", "cardiovascular", "body weight", 8.0, "Running; Jumping; Sprinting; Team sport", "cardio,frisbee,sports"),
    ("Frisbee — Casual", "full body", "cardiovascular", "body weight", 3.0, "Light movement; Recreation; Fun", "cardio,frisbee"),
    ("Gardening — General", "full body", "cardiovascular", "body weight", 4.0, "Digging; Planting; Raking; Physical work; Outdoor", "cardio,outdoor,functional"),
    ("Gardening — Heavy", "full body", "cardiovascular", "body weight", 5.5, "Shoveling; Moving soil; Heavy labor; Strenuous", "cardio,outdoor,functional"),
    ("Mowing Lawn — Push Mower", "full body", "cardiovascular", "body weight", 5.5, "Push mower; Walking; Arm work; Outdoor chore", "cardio,outdoor,functional"),
    ("Shoveling Snow", "full body", "cardiovascular", "body weight", 6.0, "Heavy shoveling; Lift and throw; Winter work; Strenuous", "cardio,outdoor,functional,winter"),
    ("Housework — General Cleaning", "full body", "cardiovascular", "body weight", 3.5, "Vacuuming; Mopping; Dusting; Light activity", "cardio,functional"),
    ("Housework — Heavy Cleaning", "full body", "cardiovascular", "body weight", 4.5, "Scrubbing; Moving furniture; Deep cleaning; Moderate activity", "cardio,functional"),
    ("Moving Furniture", "full body", "strength", "body weight", 6.0, "Lifting; Carrying; Moving items; Functional strength", "cardio,functional,strength"),
    ("Carrying Groceries", "full body", "strength", "body weight", 3.5, "Carry bags; Walk; Functional; Daily activity", "cardio,functional"),
    ("Playing with Children — Active", "full body", "cardiovascular", "body weight", 5.5, "Running; Playing; Active games; Fun workout", "cardio,functional"),
    ("Dog Walking — Brisk", "legs", "cardiovascular", "body weight", 4.0, "Brisk pace; Dog control; Outdoor; Daily activity", "cardio,walking,outdoor"),
    ("Yoga — Vinyasa Flow", "full body", "flexibility", "body weight", 4.0, "Dynamic yoga; Flowing movements; Strength and flexibility", "cardio,yoga,flexibility"),
    ("Yoga — Power", "full body", "strength", "body weight", 4.5, "Strength-focused; Challenging poses; Athletic yoga", "cardio,yoga,strength"),
    ("Yoga — Hot (Bikram)", "full body", "cardiovascular", "body weight", 5.0, "Heated room; Intense; Cardiovascular; Advanced", "cardio,yoga,advanced"),
    ("Pilates — Mat", "core", "strength", "body weight", 3.5, "Core focus; Controlled movements; Body awareness", "strength,core,pilates"),
    ("Pilates — Reformer", "full body", "strength", "machine", 4.0, "Machine-based; Resistance; Full body; Controlled", "strength,pilates,machine"),
    ("Barre Class", "full body", "strength", "body weight", 4.0, "Ballet-inspired; Small movements; Muscular endurance", "strength,barre,class"),
    ("TRX — Suspension Training", "full body", "strength", "suspension trainer", 5.0, "Bodyweight; Unstable; Core engagement; Functional", "strength,trx,functional"),
    ("CrossFit — WOD", "full body", "cardiovascular", "body weight", 10.0, "High intensity; Varied movements; Competition pace; Elite", "cardio,crossfit,hiit,advanced"),
    ("Bootcamp Class", "full body", "cardiovascular", "body weight", 8.0, "Mixed exercises; High intensity; Group class; Varied", "cardio,hiit,class"),
    ("Circuit Training", "full body", "cardiovascular", "body weight", 8.0, "Station rotation; Timed intervals; Full body; Efficient", "cardio,circuit,hiit"),
    ("Tabata Training", "full body", "cardiovascular", "body weight", 12.0, "20s on 10s off; Very high intensity; Short duration; Intense", "cardio,tabata,hiit,advanced"),
    ("Fartlek Training", "legs", "cardiovascular", "body weight", 8.5, "Speed play; Varied pace; Running; Unstructured intervals", "cardio,running,intervals"),
]

for base_name, body_part, target, equipment, met, instructions, tags in sports_variants:
    for difficulty in difficulties:
        met_adjusted = met * (0.85 if difficulty == "Beginner" else 1.0 if difficulty == "Intermediate" else 1.15)
        CARDIO_EXERCISES.append({
            "id": f"cardio_{exercise_id}",
            "name": f"{base_name} — {difficulty}",
            "category": "Cardio",
            "body_part": body_part,
            "target": target,
            "equipment": equipment,
            "difficulty": difficulty,
            "calories_per_minute": met_to_calories(met_adjusted),
            "instructions": instructions,
            "tags": tags
        })
        exercise_id += 1

print(f"Generated {len(CARDIO_EXERCISES)} cardio exercises")

# ============================================================================
# STRENGTH EXERCISES (~600)
# ============================================================================

STRENGTH_EXERCISES = []

# Squats (all variations)
squat_variants = [
    # Bodyweight
    ("Bodyweight Squat", "legs", "quads", "body weight", 3.5, "Feet shoulder-width; Sit back; Knees track toes; Chest up; Full depth", "strength,legs,compound,bodyweight"),
    ("Jump Squat", "legs", "quads", "body weight", 8.0, "Squat then explode up; Land softly; Continuous motion; Power exercise", "strength,plyometric,power"),
    ("Pistol Squat", "legs", "quads", "body weight", 8.0, "Single leg squat; Other leg extended; Balance crucial; Advanced move", "strength,legs,balance,advanced"),
    ("Bulgarian Split Squat", "legs", "quads", "body weight", 6.0, "Rear foot elevated; Front leg squats; Upright torso; Great quad focus", "strength,legs,unilateral"),
    ("Sissy Squat", "legs", "quads", "body weight", 6.0, "Lean back; Knees forward; Quads isolated; Advanced technique", "strength,legs,quads,advanced"),
    
    # Barbell
    ("Barbell Back Squat", "legs", "quads", "barbell", 5.0, "Bar on upper back; Feet shoulder-width; Depth to parallel+; Drive through heels", "strength,legs,compound,barbell"),
    ("Barbell Front Squat", "legs", "quads", "barbell", 5.0, "Bar on front delts; Elbows high; Upright torso; Quad dominant", "strength,legs,compound,barbell"),
    ("Barbell Box Squat", "legs", "quads", "barbell", 5.0, "Squat to box; Pause on box; Explode up; Build power", "strength,legs,powerlifting"),
    ("Barbell Overhead Squat", "full body", "quads", "barbell", 6.0, "Bar overhead; Wide grip; Extreme mobility; Full body stability", "strength,compound,advanced,mobility"),
    ("Barbell Zercher Squat", "legs", "quads", "barbell", 5.0, "Bar in elbow crooks; Upright torso; Core intensive; Unique variation", "strength,legs,compound"),
    
    # Dumbbell
    ("Dumbbell Goblet Squat", "legs", "quads", "dumbbell", 5.0, "Hold dumbbell at chest; Elbows inside knees; Upright; Great for learning", "strength,legs,compound,dumbbell"),
    ("Dumbbell Squat", "legs", "quads", "dumbbell", 5.0, "Dumbbells at sides; Natural squat pattern; Control weight; Good for beginners", "strength,legs,compound,dumbbell"),
    ("Dumbbell Bulgarian Split Squat", "legs", "quads", "dumbbell", 6.0, "Dumbbells in hands; Rear foot elevated; Balance and strength; Unilateral", "strength,legs,unilateral,dumbbell"),
    ("Dumbbell Front Squat", "legs", "quads", "dumbbell", 5.0, "Dumbbells on shoulders; Upright torso; Quad focus; Alternative to barbell", "strength,legs,compound,dumbbell"),
    
    # Kettlebell
    ("Kettlebell Goblet Squat", "legs", "quads", "kettlebell", 5.0, "Hold kettlebell at chest; Deep squat; Elbows inside; Mobility builder", "strength,legs,compound,kettlebell"),
    ("Kettlebell Front Squat", "legs", "quads", "kettlebell", 5.0, "Kettlebells in rack; Upright posture; Quad dominant; Core engaged", "strength,legs,compound,kettlebell"),
    
    # Machine
    ("Smith Machine Squat", "legs", "quads", "machine", 5.0, "Fixed bar path; Feet forward; Control descent; Good for beginners", "strength,legs,compound,machine"),
    ("Hack Squat Machine", "legs", "quads", "machine", 5.0, "Back against pad; Push through heels; Deep range; Quad focus", "strength,legs,machine"),
    ("Leg Press", "legs", "quads", "machine", 6.0, "Feet on platform; Press through heels; Full range; Control negative", "strength,legs,machine"),
]

for base_name, body_part, target, equipment, met, instructions, tags in squat_variants:
    for difficulty in difficulties:
        met_adjusted = met * (0.85 if difficulty == "Beginner" else 1.0 if difficulty == "Intermediate" else 1.15)
        STRENGTH_EXERCISES.append({
            "id": f"strength_{exercise_id}",
            "name": f"{base_name} — {difficulty}",
            "category": "Strength",
            "body_part": body_part,
            "target": target,
            "equipment": equipment,
            "difficulty": difficulty,
            "calories_per_minute": met_to_calories(met_adjusted),
            "instructions": instructions,
            "tags": tags
        })
        exercise_id += 1

# Deadlifts
deadlift_variants = [
    ("Barbell Deadlift — Conventional", "full body", "hamstrings", "barbell", 6.0, "Hip-width stance; Bar over mid-foot; Straight back; Drive through floor", "strength,compound,barbell,deadlift"),
    ("Barbell Deadlift — Sumo", "full body", "hamstrings", "barbell", 6.0, "Wide stance; Toes out; Upright torso; Hip-dominant pull", "strength,compound,barbell,deadlift"),
    ("Barbell Romanian Deadlift", "hamstrings", "hamstrings", "barbell", 5.0, "Slight knee bend; Hinge at hips; Feel hamstring stretch; Control descent", "strength,hamstrings,barbell"),
    ("Barbell Stiff-Leg Deadlift", "hamstrings", "hamstrings", "barbell", 5.0, "Nearly straight legs; Hinge at hips; Hamstring focus; Flexibility needed", "strength,hamstrings,barbell"),
    ("Trap Bar Deadlift", "full body", "quads", "trap bar", 6.0, "Stand inside bar; Neutral grip; Easier on back; Great variation", "strength,compound,trapbar"),
    ("Dumbbell Romanian Deadlift", "hamstrings", "hamstrings", "dumbbell", 5.0, "Dumbbells in front of legs; Hinge at hips; Feel stretch; Control", "strength,hamstrings,dumbbell"),
    ("Dumbbell Stiff-Leg Deadlift", "hamstrings", "hamstrings", "dumbbell", 5.0, "Dumbbells close to legs; Minimal knee bend; Hamstring isolation", "strength,hamstrings,dumbbell"),
    ("Single-Leg Romanian Deadlift", "hamstrings", "hamstrings", "dumbbell", 5.0, "One leg; Hinge at hip; Balance crucial; Unilateral strength", "strength,hamstrings,balance,unilateral"),
    ("Kettlebell Deadlift", "full body", "hamstrings", "kettlebell", 5.0, "Kettlebell between feet; Hip hinge; Neutral spine; Good for learning", "strength,compound,kettlebell"),
]

for base_name, body_part, target, equipment, met, instructions, tags in deadlift_variants:
    for difficulty in difficulties:
        met_adjusted = met * (0.85 if difficulty == "Beginner" else 1.0 if difficulty == "Intermediate" else 1.15)
        STRENGTH_EXERCISES.append({
            "id": f"strength_{exercise_id}",
            "name": f"{base_name} — {difficulty}",
            "category": "Strength",
            "body_part": body_part,
            "target": target,
            "equipment": equipment,
            "difficulty": difficulty,
            "calories_per_minute": met_to_calories(met_adjusted),
            "instructions": instructions,
            "tags": tags
        })
        exercise_id += 1

# Bench Press
bench_variants = [
    ("Barbell Bench Press", "chest", "pecs", "barbell", 5.0, "5-point contact; Bar to chest; Press straight up; Control descent", "strength,chest,compound,barbell"),
    ("Barbell Incline Bench Press", "chest", "upper pecs", "barbell", 5.0, "30-45° incline; Upper chest focus; Same technique; Full range", "strength,chest,compound,barbell"),
    ("Barbell Decline Bench Press", "chest", "lower pecs", "barbell", 5.0, "Decline angle; Lower chest focus; Shorter range; Heavy loads", "strength,chest,compound,barbell"),
    ("Barbell Close-Grip Bench Press", "chest", "triceps", "barbell", 5.0, "Narrow grip; Elbows close; Triceps dominant; Press straight", "strength,triceps,compound,barbell"),
    ("Dumbbell Bench Press", "chest", "pecs", "dumbbell", 5.0, "Dumbbells at chest level; Press up and together; Greater range; More stability needed", "strength,chest,compound,dumbbell"),
    ("Dumbbell Incline Bench Press", "chest", "upper pecs", "dumbbell", 5.0, "30-45° incline; Dumbbells together at top; Upper chest; Natural path", "strength,chest,compound,dumbbell"),
    ("Dumbbell Decline Bench Press", "chest", "lower pecs", "dumbbell", 5.0, "Decline angle; Control dumbbells; Lower chest; Stretch at bottom", "strength,chest,compound,dumbbell"),
    ("Dumbbell Floor Press", "chest", "pecs", "dumbbell", 5.0, "Lie on floor; Elbows touch ground; Partial range; Triceps emphasis", "strength,chest,dumbbell"),
    ("Push-ups", "chest", "pecs", "body weight", 3.5, "Hands shoulder-width; Body straight; Chest to ground; Press up", "strength,chest,bodyweight,push"),
    ("Push-ups — Wide Grip", "chest", "pecs", "body weight", 3.5, "Hands wider than shoulders; Chest stretch; Press up; Chest focus", "strength,chest,bodyweight"),
    ("Push-ups — Diamond", "chest", "triceps", "body weight", 4.0, "Hands together; Diamond shape; Triceps dominant; Harder variation", "strength,triceps,bodyweight"),
    ("Push-ups — Decline", "chest", "upper pecs", "body weight", 4.0, "Feet elevated; Upper chest focus; More difficult; Control form", "strength,chest,bodyweight"),
    ("Push-ups — Incline", "chest", "pecs", "body weight", 3.0, "Hands elevated; Easier variation; Good for beginners; Full range", "strength,chest,bodyweight"),
    ("Chest Dips", "chest", "pecs", "body weight", 4.0, "Lean forward; Elbows out; Deep stretch; Press up", "strength,chest,bodyweight,dips"),
    ("Machine Chest Press", "chest", "pecs", "machine", 5.0, "Adjust seat; Push handles forward; Control return; Stable path", "strength,chest,machine"),
    ("Cable Chest Press", "chest", "pecs", "cable", 4.0, "Cables at chest height; Press forward; Constant tension; Control motion", "strength,chest,cable"),
    ("Cable Crossover — High to Low", "chest", "lower pecs", "cable", 3.5, "Cables high; Cross down and together; Squeeze chest; Fly motion", "strength,chest,cable,isolation"),
    ("Cable Crossover — Low to High", "chest", "upper pecs", "cable", 3.5, "Cables low; Cross up and together; Upper chest focus; Fly motion", "strength,chest,cable,isolation"),
    ("Cable Crossover — Middle", "chest", "pecs", "cable", 3.5, "Cables at chest; Cross forward; Pec squeeze; Constant tension", "strength,chest,cable,isolation"),
    ("Dumbbell Chest Fly", "chest", "pecs", "dumbbell", 3.5, "Flat bench; Arc motion; Stretch pecs; Bring together at top", "strength,chest,dumbbell,isolation"),
    ("Dumbbell Incline Fly", "chest", "upper pecs", "dumbbell", 3.5, "Incline bench; Arc motion; Upper chest stretch; Squeeze together", "strength,chest,dumbbell,isolation"),
    ("Dumbbell Decline Fly", "chest", "lower pecs", "dumbbell", 3.5, "Decline bench; Arc motion; Lower chest focus; Control stretch", "strength,chest,dumbbell,isolation"),
    ("Pec Deck Machine", "chest", "pecs", "machine", 3.5, "Bring arms together; Squeeze chest; Isolation; Control", "strength,chest,machine,isolation"),
    ("Push-ups — Plyometric", "chest", "pecs", "body weight", 5.0, "Explosive push; Hands leave ground; Power training; Advanced", "strength,chest,power,bodyweight,advanced"),
    ("Push-ups — Archer", "chest", "pecs", "body weight", 5.0, "Shift weight side to side; One-arm emphasis; Advanced variation", "strength,chest,bodyweight,advanced"),
    ("Push-ups — Spiderman", "chest", "pecs", "body weight", 4.0, "Bring knee to elbow; Rotation; Core and chest; Dynamic", "strength,chest,core,bodyweight"),
    ("Svend Press", "chest", "pecs", "dumbbell", 3.0, "Squeeze plates together; Press forward; Pec contraction; Unique", "strength,chest,dumbbell,isolation"),
]

for base_name, body_part, target, equipment, met, instructions, tags in bench_variants:
    for difficulty in difficulties:
        met_adjusted = met * (0.85 if difficulty == "Beginner" else 1.0 if difficulty == "Intermediate" else 1.15)
        STRENGTH_EXERCISES.append({
            "id": f"strength_{exercise_id}",
            "name": f"{base_name} — {difficulty}",
            "category": "Strength",
            "body_part": body_part,
            "target": target,
            "equipment": equipment,
            "difficulty": difficulty,
            "calories_per_minute": met_to_calories(met_adjusted),
            "instructions": instructions,
            "tags": tags
        })
        exercise_id += 1

# Pull-ups and Rows (Back)
back_variants = [
    ("Pull-ups", "back", "lats", "body weight", 4.0, "Hang from bar; Pull chin over bar; Control descent; Engage lats", "strength,back,bodyweight,pull"),
    ("Pull-ups — Wide Grip", "back", "lats", "body weight", 4.0, "Wider than shoulders; Lat focus; Pull to chest; Control", "strength,back,bodyweight"),
    ("Pull-ups — Close Grip", "back", "lats", "body weight", 4.0, "Narrow grip; Increased range; Biceps assist; Pull high", "strength,back,bodyweight"),
    ("Chin-ups", "back", "lats", "body weight", 4.0, "Underhand grip; Pull chin over; Biceps assist; Control down", "strength,back,biceps,bodyweight"),
    ("Neutral Grip Pull-ups", "back", "lats", "body weight", 4.0, "Palms facing; Shoulder-friendly; Natural path; Pull high", "strength,back,bodyweight"),
    ("Assisted Pull-ups", "back", "lats", "machine", 3.0, "Machine assists; Same technique; Build strength; Progressive", "strength,back,machine"),
    ("Lat Pulldown", "back", "lats", "machine", 4.0, "Wide grip; Pull to chest; Squeeze lats; Control up", "strength,back,machine"),
    ("Lat Pulldown — Close Grip", "back", "lats", "machine", 4.0, "Narrow handle; Greater range; Biceps assist; Pull to chest", "strength,back,machine"),
    ("Barbell Bent-Over Row", "back", "lats", "barbell", 4.5, "Hip hinge; Back flat; Pull to sternum; Squeeze shoulder blades", "strength,back,compound,barbell"),
    ("Barbell Pendlay Row", "back", "lats", "barbell", 5.0, "Dead stop each rep; Explosive pull; Parallel back; Power movement", "strength,back,barbell,power"),
    ("Barbell T-Bar Row", "back", "mid-back", "barbell", 4.5, "V-handle attachment; Pull to chest; Squeeze back; Control", "strength,back,compound,barbell"),
    ("Dumbbell Bent-Over Row", "back", "lats", "dumbbell", 4.5, "One or both arms; Hip hinge; Pull to hip; Squeeze at top", "strength,back,dumbbell"),
    ("Dumbbell Single-Arm Row", "back", "lats", "dumbbell", 4.0, "One arm; Support with other; Pull to hip; Control; Unilateral", "strength,back,dumbbell,unilateral"),
    ("Dumbbell Chest-Supported Row", "back", "mid-back", "dumbbell", 4.0, "Chest on bench; Isolates back; No lower back strain; Squeeze", "strength,back,dumbbell"),
    ("Cable Row — Seated", "back", "mid-back", "cable", 4.0, "Seated; Cable to torso; Squeeze shoulder blades; Control", "strength,back,cable"),
    ("Cable Row — Single-Arm", "back", "lats", "cable", 3.5, "One arm; Rotation allowed; Control weight; Unilateral focus", "strength,back,cable,unilateral"),
    ("Inverted Row", "back", "mid-back", "body weight", 3.5, "Bar at waist height; Pull chest to bar; Body straight; Great for beginners", "strength,back,bodyweight"),
    ("Face Pulls", "back", "rear delts", "cable", 3.0, "Cable to face; External rotation; Upper back; Shoulder health", "strength,back,shoulders,cable"),
    ("Shrugs — Barbell", "back", "traps", "barbell", 3.0, "Shrug shoulders up; Hold briefly; Control down; Trap focus", "strength,traps,barbell"),
    ("Shrugs — Dumbbell", "back", "traps", "dumbbell", 3.0, "Dumbbells at sides; Shrug up; Squeeze traps; Don't roll", "strength,traps,dumbbell"),
    ("Farmer's Walk", "full body", "traps", "dumbbell", 4.0, "Heavy dumbbells at sides; Walk with good posture; Grip and trap strength", "strength,traps,grip,functional,dumbbell"),
    ("Deadlift — Snatch Grip", "full body", "hamstrings", "barbell", 6.5, "Wide grip; Deadlift pattern; More range; Upper back work", "strength,compound,barbell,deadlift"),
    ("Rack Pull", "back", "lats", "barbell", 5.5, "Bar starts at knee height; Partial deadlift; Heavy weight; Upper back", "strength,back,barbell"),
    ("Cable Pullover", "back", "lats", "cable", 3.5, "High cable; Pull down to hips; Straight arms; Lat stretch", "strength,lats,cable,isolation"),
    ("Dumbbell Pullover", "back", "lats", "dumbbell", 3.5, "Lie on bench; Lower dumbbell overhead; Pull back up; Lat stretch", "strength,lats,dumbbell,isolation"),
    ("Meadows Row", "back", "lats", "barbell", 4.5, "T-bar one arm; Rotate torso; Heavy pull; Unilateral", "strength,back,barbell,unilateral"),
    ("Seal Row", "back", "mid-back", "barbell", 4.5, "Lie face down on bench; Row barbell; No momentum; Pure back", "strength,back,barbell,isolation"),
    ("Yates Row", "back", "lats", "barbell", 4.5, "Underhand grip; More upright; Lower back friendly; Lat focus", "strength,lats,barbell"),
    ("Machine Row", "back", "mid-back", "machine", 4.0, "Chest on pad; Pull handles; Squeeze back; Stable", "strength,back,machine"),
    ("Wide Grip Pull-ups", "back", "lats", "body weight", 4.5, "Very wide grip; Lat stretch; Pull to chest; Advanced", "strength,lats,bodyweight,advanced"),
    ("Typewriter Pull-ups", "back", "lats", "body weight", 5.0, "Pull up then move side to side; Very advanced; Strength and control", "strength,lats,bodyweight,advanced"),
]

for base_name, body_part, target, equipment, met, instructions, tags in back_variants:
    for difficulty in difficulties:
        met_adjusted = met * (0.85 if difficulty == "Beginner" else 1.0 if difficulty == "Intermediate" else 1.15)
        STRENGTH_EXERCISES.append({
            "id": f"strength_{exercise_id}",
            "name": f"{base_name} — {difficulty}",
            "category": "Strength",
            "body_part": body_part,
            "target": target,
            "equipment": equipment,
            "difficulty": difficulty,
            "calories_per_minute": met_to_calories(met_adjusted),
            "instructions": instructions,
            "tags": tags
        })
        exercise_id += 1

# Shoulders
shoulder_variants = [
    ("Barbell Overhead Press", "shoulders", "delts", "barbell", 4.5, "Bar at shoulders; Press overhead; Lock out; Control down", "strength,shoulders,compound,barbell"),
    ("Barbell Push Press", "shoulders", "delts", "barbell", 5.0, "Slight dip; Drive with legs; Press overhead; Power movement", "strength,shoulders,power,barbell"),
    ("Dumbbell Overhead Press", "shoulders", "delts", "dumbbell", 4.5, "Dumbbells at shoulders; Press up; Natural path; Control", "strength,shoulders,compound,dumbbell"),
    ("Dumbbell Arnold Press", "shoulders", "delts", "dumbbell", 4.5, "Rotate palms during press; Start facing you; End facing away; Full deltoid", "strength,shoulders,dumbbell"),
    ("Dumbbell Lateral Raise", "shoulders", "side delts", "dumbbell", 3.0, "Arms at sides; Raise to shoulder height; Slight bend; Control down", "strength,shoulders,isolation,dumbbell"),
    ("Dumbbell Front Raise", "shoulders", "front delts", "dumbbell", 3.0, "Raise forward; To shoulder height; Control; Don't swing", "strength,shoulders,isolation,dumbbell"),
    ("Dumbbell Rear Delt Fly", "shoulders", "rear delts", "dumbbell", 3.0, "Bent over; Raise arms out; Squeeze rear delts; Control", "strength,shoulders,isolation,dumbbell"),
    ("Cable Lateral Raise", "shoulders", "side delts", "cable", 3.0, "Cable from side; Raise arm; Constant tension; Control", "strength,shoulders,cable"),
    ("Cable Face Pull", "shoulders", "rear delts", "cable", 3.0, "Pull to face; External rotation; Rear delts and upper back", "strength,shoulders,cable"),
    ("Machine Shoulder Press", "shoulders", "delts", "machine", 4.0, "Adjust seat; Press overhead; Stable path; Control descent", "strength,shoulders,machine"),
    ("Pike Push-ups", "shoulders", "delts", "body weight", 4.0, "Inverted V position; Lower head to ground; Press up; Shoulder focus", "strength,shoulders,bodyweight"),
    ("Handstand Push-ups", "shoulders", "delts", "body weight", 6.0, "Against wall; Lower head to ground; Press up; Advanced move", "strength,shoulders,bodyweight,advanced"),
    ("Upright Row — Barbell", "shoulders", "delts", "barbell", 4.0, "Pull bar to chin; Elbows high; Shoulder and trap focus", "strength,shoulders,barbell"),
    ("Upright Row — Dumbbell", "shoulders", "delts", "dumbbell", 4.0, "Pull dumbbells to chin; Natural path; Shoulder focus", "strength,shoulders,dumbbell"),
    ("Cable Rear Delt Fly", "shoulders", "rear delts", "cable", 3.0, "Cables crossed; Fly arms apart; Rear delt focus; Constant tension", "strength,shoulders,cable,isolation"),
    ("Reverse Pec Deck", "shoulders", "rear delts", "machine", 3.0, "Face machine; Pull arms back; Rear delt isolation; Squeeze", "strength,shoulders,machine,isolation"),
    ("Band Pull-Apart", "shoulders", "rear delts", "band", 2.5, "Pull band apart; Rear delt work; Shoulder health; Warm-up", "strength,shoulders,band"),
    ("Cuban Press", "shoulders", "delts", "dumbbell", 3.5, "Upright row to external rotation to press; Complex; Shoulder health", "strength,shoulders,dumbbell,complex"),
    ("Bradford Press", "shoulders", "delts", "barbell", 4.5, "Press from front then behind neck alternating; Shoulder mobility; Advanced", "strength,shoulders,barbell,advanced"),
    ("Landmine Press", "shoulders", "delts", "barbell", 4.0, "Bar in corner; Press at angle; Shoulder-friendly; Good variation", "strength,shoulders,barbell"),
    ("Z-Press", "shoulders", "delts", "barbell", 5.0, "Sit on floor; Strict press; No leg drive; Core and shoulders", "strength,shoulders,core,barbell,advanced"),
]

for base_name, body_part, target, equipment, met, instructions, tags in shoulder_variants:
    for difficulty in difficulties:
        met_adjusted = met * (0.85 if difficulty == "Beginner" else 1.0 if difficulty == "Intermediate" else 1.15)
        STRENGTH_EXERCISES.append({
            "id": f"strength_{exercise_id}",
            "name": f"{base_name} — {difficulty}",
            "category": "Strength",
            "body_part": body_part,
            "target": target,
            "equipment": equipment,
            "difficulty": difficulty,
            "calories_per_minute": met_to_calories(met_adjusted),
            "instructions": instructions,
            "tags": tags
        })
        exercise_id += 1

# Arms - Biceps
bicep_variants = [
    ("Barbell Bicep Curl", "biceps", "biceps", "barbell", 3.0, "Elbows at sides; Curl bar up; Squeeze at top; Control down", "strength,biceps,isolation,barbell"),
    ("Barbell Preacher Curl", "biceps", "biceps", "barbell", 3.0, "Arms on pad; Isolated biceps; No momentum; Full range", "strength,biceps,isolation,barbell"),
    ("EZ-Bar Curl", "biceps", "biceps", "barbell", 3.0, "Angled grip; Wrist-friendly; Curl up; Control descent", "strength,biceps,isolation,barbell"),
    ("Dumbbell Bicep Curl", "biceps", "biceps", "dumbbell", 3.0, "Dumbbells at sides; Curl up; Rotate palms; Squeeze", "strength,biceps,isolation,dumbbell"),
    ("Dumbbell Hammer Curl", "biceps", "biceps", "dumbbell", 3.0, "Neutral grip; Thumbs up; Curl up; Brachialis focus", "strength,biceps,isolation,dumbbell"),
    ("Dumbbell Concentration Curl", "biceps", "biceps", "dumbbell", 3.0, "Seated; Elbow on thigh; Isolated curl; Peak contraction", "strength,biceps,isolation,dumbbell"),
    ("Dumbbell Incline Curl", "biceps", "biceps", "dumbbell", 3.0, "Incline bench; Arms hang; Full stretch; Curl up", "strength,biceps,isolation,dumbbell"),
    ("Cable Bicep Curl", "biceps", "biceps", "cable", 3.0, "Cable bar; Constant tension; Curl up; Control", "strength,biceps,isolation,cable"),
    ("Cable Hammer Curl", "biceps", "biceps", "cable", 3.0, "Rope attachment; Neutral grip; Curl up; Constant tension", "strength,biceps,isolation,cable"),
    ("Spider Curl — Barbell", "biceps", "biceps", "barbell", 3.0, "Chest on incline; Arms hang; Isolated curl; No momentum", "strength,biceps,isolation,barbell"),
    ("Spider Curl — Dumbbell", "biceps", "biceps", "dumbbell", 3.0, "Chest on incline; Arms hang; Isolated curl; Peak contraction", "strength,biceps,isolation,dumbbell"),
    ("Drag Curl", "biceps", "biceps", "barbell", 3.0, "Drag bar up body; Elbows back; Different stimulus; Unique", "strength,biceps,isolation,barbell"),
    ("Zottman Curl", "biceps", "biceps", "dumbbell", 3.5, "Curl up normal; Rotate; Lower with reverse grip; Biceps and forearms", "strength,biceps,forearms,dumbbell"),
]

for base_name, body_part, target, equipment, met, instructions, tags in bicep_variants:
    for difficulty in difficulties:
        met_adjusted = met * (0.85 if difficulty == "Beginner" else 1.0 if difficulty == "Intermediate" else 1.15)
        STRENGTH_EXERCISES.append({
            "id": f"strength_{exercise_id}",
            "name": f"{base_name} — {difficulty}",
            "category": "Strength",
            "body_part": body_part,
            "target": target,
            "equipment": equipment,
            "difficulty": difficulty,
            "calories_per_minute": met_to_calories(met_adjusted),
            "instructions": instructions,
            "tags": tags
        })
        exercise_id += 1

# Arms - Triceps
tricep_variants = [
    ("Tricep Dips", "triceps", "triceps", "body weight", 4.0, "Upright torso; Lower body; Elbows back; Press up", "strength,triceps,bodyweight"),
    ("Close-Grip Bench Press", "triceps", "triceps", "barbell", 5.0, "Narrow grip; Elbows tucked; Press up; Triceps focus", "strength,triceps,compound,barbell"),
    ("Lying Tricep Extension — Barbell", "triceps", "triceps", "barbell", 3.0, "Skull crushers; Lower to forehead; Extend arms; Elbows stay", "strength,triceps,isolation,barbell"),
    ("Lying Tricep Extension — Dumbbell", "triceps", "triceps", "dumbbell", 3.0, "Dumbbells overhead; Lower behind head; Extend up; Elbows stable", "strength,triceps,isolation,dumbbell"),
    ("Overhead Tricep Extension — Dumbbell", "triceps", "triceps", "dumbbell", 3.0, "One or two dumbbells; Overhead; Lower behind; Extend up", "strength,triceps,isolation,dumbbell"),
    ("Cable Tricep Pushdown", "triceps", "triceps", "cable", 3.0, "Bar or rope; Push down; Lock out; Control up", "strength,triceps,isolation,cable"),
    ("Cable Overhead Tricep Extension", "triceps", "triceps", "cable", 3.0, "Face away; Rope overhead; Extend forward; Long head focus", "strength,triceps,isolation,cable"),
    ("Diamond Push-ups", "triceps", "triceps", "body weight", 4.0, "Hands together; Diamond shape; Triceps dominant; Chest touches", "strength,triceps,bodyweight"),
    ("Cable Kickback", "triceps", "triceps", "cable", 3.0, "One arm; Kickback motion; Squeeze; Constant tension", "strength,triceps,cable,isolation"),
    ("Dumbbell Kickback", "triceps", "triceps", "dumbbell", 3.0, "Bent over; Kickback; Squeeze at top; Isolation", "strength,triceps,dumbbell,isolation"),
    ("JM Press", "triceps", "triceps", "barbell", 4.0, "Hybrid skull crusher and close-grip; Advanced technique; Heavy", "strength,triceps,barbell,advanced"),
    ("Tate Press", "triceps", "triceps", "dumbbell", 3.5, "Elbows flare; Unique angle; Triceps focus; Different stimulus", "strength,triceps,dumbbell,isolation"),
]

for base_name, body_part, target, equipment, met, instructions, tags in tricep_variants:
    for difficulty in difficulties:
        met_adjusted = met * (0.85 if difficulty == "Beginner" else 1.0 if difficulty == "Intermediate" else 1.15)
        STRENGTH_EXERCISES.append({
            "id": f"strength_{exercise_id}",
            "name": f"{base_name} — {difficulty}",
            "category": "Strength",
            "body_part": body_part,
            "target": target,
            "equipment": equipment,
            "difficulty": difficulty,
            "calories_per_minute": met_to_calories(met_adjusted),
            "instructions": instructions,
            "tags": tags
        })
        exercise_id += 1

# Forearms and Grip
forearm_variants = [
    ("Wrist Curl — Barbell", "forearms", "forearms", "barbell", 2.5, "Forearms on bench; Curl wrists up; Forearm flexors; Control", "strength,forearms,isolation,barbell"),
    ("Wrist Curl — Dumbbell", "forearms", "forearms", "dumbbell", 2.5, "Forearms on bench; Curl wrists up; Isolation; Control", "strength,forearms,isolation,dumbbell"),
    ("Reverse Wrist Curl — Barbell", "forearms", "forearms", "barbell", 2.5, "Forearms on bench; Overhand grip; Curl up; Forearm extensors", "strength,forearms,isolation,barbell"),
    ("Reverse Wrist Curl — Dumbbell", "forearms", "forearms", "dumbbell", 2.5, "Forearms on bench; Overhand grip; Curl up; Extensors", "strength,forearms,isolation,dumbbell"),
    ("Farmer's Carry", "forearms", "grip", "dumbbell", 4.0, "Heavy weights; Walk; Grip endurance; Functional", "strength,grip,forearms,functional,dumbbell"),
    ("Plate Pinch", "forearms", "grip", "body weight", 3.0, "Pinch plates together; Hold; Thumb and finger strength", "strength,grip,forearms,isometric"),
    ("Dead Hang", "forearms", "grip", "body weight", 3.0, "Hang from bar; Hold; Grip endurance; Simple", "strength,grip,forearms,isometric,bodyweight"),
    ("Towel Hang", "forearms", "grip", "body weight", 3.5, "Hang from towel; Hold; Advanced grip; Very challenging", "strength,grip,forearms,isometric,bodyweight,advanced"),
    ("Reverse Curl — Barbell", "forearms", "forearms", "barbell", 3.0, "Overhand grip; Curl up; Brachioradialis focus; Forearms", "strength,forearms,barbell"),
    ("Reverse Curl — Dumbbell", "forearms", "forearms", "dumbbell", 3.0, "Overhand grip; Curl up; Forearm and bicep; Control", "strength,forearms,dumbbell"),
    ("Fat Grip Training", "forearms", "grip", "dumbbell", 3.5, "Thick grip attachment; Any exercise; Increased grip challenge", "strength,grip,forearms"),
    ("Gripper — Hand", "forearms", "grip", "body weight", 2.5, "Hand gripper tool; Squeeze; Crush grip; Progressive resistance", "strength,grip,forearms"),
]

for base_name, body_part, target, equipment, met, instructions, tags in forearm_variants:
    for difficulty in difficulties:
        met_adjusted = met * (0.85 if difficulty == "Beginner" else 1.0 if difficulty == "Intermediate" else 1.15)
        STRENGTH_EXERCISES.append({
            "id": f"strength_{exercise_id}",
            "name": f"{base_name} — {difficulty}",
            "category": "Strength",
            "body_part": body_part,
            "target": target,
            "equipment": equipment,
            "difficulty": difficulty,
            "calories_per_minute": met_to_calories(met_adjusted),
            "instructions": instructions,
            "tags": tags
        })
        exercise_id += 1

# Legs - Lunges
lunge_variants = [
    ("Forward Lunge", "legs", "quads", "body weight", 4.0, "Step forward; Lower back knee; Drive back up; Alternate legs", "strength,legs,bodyweight"),
    ("Reverse Lunge", "legs", "quads", "body weight", 4.0, "Step backward; Lower down; Push back up; Knee-friendly", "strength,legs,bodyweight"),
    ("Walking Lunge", "legs", "quads", "body weight", 4.5, "Continuous forward lunges; Alternate legs; Cover distance; Balance", "strength,legs,bodyweight"),
    ("Barbell Forward Lunge", "legs", "quads", "barbell", 5.0, "Bar on back; Lunge forward; Control descent; Drive up", "strength,legs,compound,barbell"),
    ("Barbell Reverse Lunge", "legs", "quads", "barbell", 5.0, "Bar on back; Step back; Lower down; Return; Safer variation", "strength,legs,compound,barbell"),
    ("Dumbbell Forward Lunge", "legs", "quads", "dumbbell", 4.5, "Dumbbells at sides; Lunge forward; Control; Drive up", "strength,legs,dumbbell"),
    ("Dumbbell Reverse Lunge", "legs", "quads", "dumbbell", 4.5, "Dumbbells at sides; Step back; Lower; Return", "strength,legs,dumbbell"),
    ("Dumbbell Walking Lunge", "legs", "quads", "dumbbell", 5.0, "Dumbbells at sides; Continuous lunges; Balance; Distance", "strength,legs,dumbbell"),
]

for base_name, body_part, target, equipment, met, instructions, tags in lunge_variants:
    for difficulty in difficulties:
        met_adjusted = met * (0.85 if difficulty == "Beginner" else 1.0 if difficulty == "Intermediate" else 1.15)
        STRENGTH_EXERCISES.append({
            "id": f"strength_{exercise_id}",
            "name": f"{base_name} — {difficulty}",
            "category": "Strength",
            "body_part": body_part,
            "target": target,
            "equipment": equipment,
            "difficulty": difficulty,
            "calories_per_minute": met_to_calories(met_adjusted),
            "instructions": instructions,
            "tags": tags
        })
        exercise_id += 1

# Legs - Leg Extensions/Curls
leg_isolation = [
    ("Leg Extension", "legs", "quads", "machine", 3.5, "Sit in machine; Extend legs; Squeeze quads at top; Control down", "strength,quads,isolation,machine"),
    ("Leg Curl — Lying", "hamstrings", "hamstrings", "machine", 3.5, "Lie face down; Curl heels to glutes; Squeeze; Control", "strength,hamstrings,isolation,machine"),
    ("Leg Curl — Seated", "hamstrings", "hamstrings", "machine", 3.5, "Sit in machine; Curl legs under; Squeeze hamstrings; Control", "strength,hamstrings,isolation,machine"),
    ("Leg Curl — Standing", "hamstrings", "hamstrings", "machine", 3.5, "One leg; Curl heel up; Balance; Squeeze hamstring", "strength,hamstrings,isolation,machine,unilateral"),
    ("Glute-Ham Raise", "hamstrings", "hamstrings", "body weight", 5.0, "GHR machine; Lower body; Pull back up with hamstrings; Advanced", "strength,hamstrings,glutes,advanced"),
    ("Nordic Hamstring Curl", "hamstrings", "hamstrings", "body weight", 5.0, "Partner holds feet; Lower forward; Eccentric focus; Very advanced", "strength,hamstrings,advanced,eccentric"),
    ("Hip Thrust — Barbell", "glutes", "glutes", "barbell", 5.0, "Back on bench; Bar on hips; Drive through heels; Squeeze glutes at top", "strength,glutes,barbell"),
    ("Hip Thrust — Dumbbell", "glutes", "glutes", "dumbbell", 4.5, "Back on bench; Dumbbell on hips; Drive up; Glute focus", "strength,glutes,dumbbell"),
    ("Single-Leg Hip Thrust", "glutes", "glutes", "body weight", 5.0, "One leg; Drive through heel; Balance; Unilateral glute work", "strength,glutes,bodyweight,unilateral"),
    ("Glute Bridge", "glutes", "glutes", "body weight", 3.5, "Lie on back; Feet flat; Drive hips up; Squeeze glutes", "strength,glutes,bodyweight"),
    ("Single-Leg Glute Bridge", "glutes", "glutes", "body weight", 4.0, "One leg extended; Drive through heel; Glute isolation", "strength,glutes,bodyweight,unilateral"),
    ("Kickback — Cable", "glutes", "glutes", "cable", 3.0, "Ankle strap; Kick leg back; Squeeze glute; Control", "strength,glutes,cable,isolation"),
    ("Kickback — Machine", "glutes", "glutes", "machine", 3.0, "Glute kickback machine; Push back; Squeeze; Isolation", "strength,glutes,machine,isolation"),
    ("Step-Ups — Bodyweight", "legs", "quads", "body weight", 4.0, "Step onto box; Drive through heel; Alternate legs; Functional", "strength,legs,bodyweight"),
    ("Step-Ups — Dumbbell", "legs", "quads", "dumbbell", 5.0, "Dumbbells in hands; Step up; Control descent; Functional", "strength,legs,dumbbell"),
    ("Step-Ups — Barbell", "legs", "quads", "barbell", 5.5, "Bar on back; Step up; Balance; Functional strength", "strength,legs,barbell"),
    ("Lateral Step-Ups", "legs", "quads", "body weight", 4.0, "Step sideways onto box; Different angle; Abductor work", "strength,legs,bodyweight"),
    ("Wall Sit", "legs", "quads", "body weight", 3.5, "Back against wall; Sit position; Hold; Isometric quad work", "strength,quads,isometric,bodyweight"),
    ("Adductor Machine", "legs", "adductors", "machine", 3.0, "Bring legs together; Squeeze inner thighs; Control", "strength,adductors,machine,isolation"),
    ("Abductor Machine", "legs", "abductors", "machine", 3.0, "Push legs apart; Outer thigh focus; Control", "strength,abductors,machine,isolation"),
    ("Good Morning — Barbell", "hamstrings", "hamstrings", "barbell", 4.5, "Bar on upper back; Hinge at hips; Feel hamstring stretch; Stand up", "strength,hamstrings,barbell"),
]

for base_name, body_part, target, equipment, met, instructions, tags in leg_isolation:
    for difficulty in difficulties:
        met_adjusted = met * (0.85 if difficulty == "Beginner" else 1.0 if difficulty == "Intermediate" else 1.15)
        STRENGTH_EXERCISES.append({
            "id": f"strength_{exercise_id}",
            "name": f"{base_name} — {difficulty}",
            "category": "Strength",
            "body_part": body_part,
            "target": target,
            "equipment": equipment,
            "difficulty": difficulty,
            "calories_per_minute": met_to_calories(met_adjusted),
            "instructions": instructions,
            "tags": tags
        })
        exercise_id += 1

# Calves
calf_variants = [
    ("Standing Calf Raise", "calves", "calves", "machine", 3.0, "Balls of feet on edge; Rise up on toes; Squeeze; Lower with control", "strength,calves,machine"),
    ("Seated Calf Raise", "calves", "calves", "machine", 3.0, "Seated; Weight on knees; Rise on toes; Soleus focus; Full range", "strength,calves,machine"),
    ("Calf Raise — Bodyweight", "calves", "calves", "body weight", 2.5, "Stand on edge; Rise on toes; Control down; Can add weight", "strength,calves,bodyweight"),
    ("Donkey Calf Raise", "calves", "calves", "machine", 3.0, "Bent over; Rise on toes; Full stretch; Old-school effective", "strength,calves,machine"),
]

for base_name, body_part, target, equipment, met, instructions, tags in calf_variants:
    for difficulty in difficulties:
        met_adjusted = met * (0.85 if difficulty == "Beginner" else 1.0 if difficulty == "Intermediate" else 1.15)
        STRENGTH_EXERCISES.append({
            "id": f"strength_{exercise_id}",
            "name": f"{base_name} — {difficulty}",
            "category": "Strength",
            "body_part": body_part,
            "target": target,
            "equipment": equipment,
            "difficulty": difficulty,
            "calories_per_minute": met_to_calories(met_adjusted),
            "instructions": instructions,
            "tags": tags
        })
        exercise_id += 1

# Core/Abs
core_variants = [
    ("Plank", "core", "abs", "body weight", 3.5, "Forearms on ground; Body straight; Hold position; Engage core", "strength,core,isometric,bodyweight"),
    ("Side Plank", "core", "obliques", "body weight", 3.5, "One forearm; Body straight; Hold; Switch sides; Oblique focus", "strength,core,obliques,bodyweight"),
    ("Crunches", "core", "abs", "body weight", 3.0, "Lie on back; Lift shoulders; Crunch abs; Control down", "strength,abs,bodyweight"),
    ("Bicycle Crunches", "core", "obliques", "body weight", 3.5, "Alternate elbow to opposite knee; Rotate torso; Continuous motion", "strength,abs,obliques,bodyweight"),
    ("Russian Twists", "core", "obliques", "body weight", 3.5, "Seated; Lean back; Rotate side to side; Can hold weight", "strength,obliques,bodyweight"),
    ("Leg Raises", "core", "lower abs", "body weight", 4.0, "Lie on back; Raise legs up; Control down; Lower abs focus", "strength,abs,bodyweight"),
    ("Hanging Leg Raises", "core", "abs", "body weight", 4.5, "Hang from bar; Raise legs; Control; Advanced core", "strength,abs,bodyweight,advanced"),
    ("Cable Crunches", "core", "abs", "cable", 3.5, "Kneeling; Rope attachment; Crunch down; Squeeze abs", "strength,abs,cable"),
    ("Ab Wheel Rollout", "core", "abs", "body weight", 5.0, "Roll wheel forward; Engage core; Don't sag; Roll back; Advanced", "strength,abs,bodyweight,advanced"),
    ("Mountain Climbers — Core", "core", "abs", "body weight", 8.0, "Plank position; Drive knees to chest; Slower pace; Core control", "strength,core,bodyweight"),
    ("Dead Bug", "core", "abs", "body weight", 3.0, "On back; Opposite arm and leg extend; Control; Core stability", "strength,core,bodyweight"),
    ("Pallof Press", "core", "obliques", "cable", 3.0, "Cable at chest; Press out; Resist rotation; Anti-rotation core", "strength,core,cable"),
]

for base_name, body_part, target, equipment, met, instructions, tags in core_variants:
    for difficulty in difficulties:
        met_adjusted = met * (0.85 if difficulty == "Beginner" else 1.0 if difficulty == "Intermediate" else 1.15)
        STRENGTH_EXERCISES.append({
            "id": f"strength_{exercise_id}",
            "name": f"{base_name} — {difficulty}",
            "category": "Strength",
            "body_part": body_part,
            "target": target,
            "equipment": equipment,
            "difficulty": difficulty,
            "calories_per_minute": met_to_calories(met_adjusted),
            "instructions": instructions,
            "tags": tags
        })
        exercise_id += 1

# Kettlebell-Specific Exercises
kettlebell_variants = [
    ("Kettlebell Swing", "full body", "glutes", "kettlebell", 6.0, "Hip hinge; Explosive swing; Power from hips; Cardiovascular", "strength,kettlebell,power,compound"),
    ("Kettlebell Turkish Get-Up", "full body", "core", "kettlebell", 5.0, "Complex movement; Ground to standing; Full body coordination; Advanced", "strength,kettlebell,functional,advanced"),
    ("Kettlebell Windmill", "core", "obliques", "kettlebell", 4.0, "Overhead stability; Side bend; Mobility and strength; Advanced", "strength,kettlebell,core,advanced"),
    ("Kettlebell Halo", "shoulders", "delts", "kettlebell", 3.0, "Circle kettlebell around head; Shoulder mobility; Warm-up", "strength,kettlebell,shoulders,mobility"),
    ("Kettlebell Figure-8", "core", "obliques", "kettlebell", 4.0, "Pass kettlebell through legs; Core rotation; Coordination", "strength,kettlebell,core"),
    ("Kettlebell Sumo Deadlift High Pull", "full body", "traps", "kettlebell", 5.5, "Wide stance; Pull high; Full body power; CrossFit", "strength,kettlebell,compound,power"),
    ("Kettlebell Thruster", "full body", "quads", "kettlebell", 6.0, "Squat to press; Full body; Cardiovascular; Functional", "strength,kettlebell,compound"),
    ("Kettlebell Renegade Row", "back", "lats", "kettlebell", 5.0, "Plank position; Row; Core stability; Anti-rotation", "strength,kettlebell,back,core"),
    ("Kettlebell Pistol Squat", "legs", "quads", "kettlebell", 6.0, "One leg squat; Counterbalance; Balance and strength; Advanced", "strength,kettlebell,legs,advanced,unilateral"),
    ("Kettlebell Suitcase Carry", "core", "obliques", "kettlebell", 4.0, "One-sided carry; Anti-lateral flexion; Core stability; Functional", "strength,kettlebell,core,functional"),
]

for base_name, body_part, target, equipment, met, instructions, tags in kettlebell_variants:
    for difficulty in difficulties:
        met_adjusted = met * (0.85 if difficulty == "Beginner" else 1.0 if difficulty == "Intermediate" else 1.15)
        STRENGTH_EXERCISES.append({
            "id": f"strength_{exercise_id}",
            "name": f"{base_name} — {difficulty}",
            "category": "Strength",
            "body_part": body_part,
            "target": target,
            "equipment": equipment,
            "difficulty": difficulty,
            "calories_per_minute": met_to_calories(met_adjusted),
            "instructions": instructions,
            "tags": tags
        })
        exercise_id += 1

# Resistance Band Exercises
band_variants = [
    ("Band Chest Press", "chest", "pecs", "band", 3.5, "Band behind; Press forward; Chest work; Constant tension", "strength,band,chest"),
    ("Band Chest Fly", "chest", "pecs", "band", 3.0, "Band behind; Fly forward; Pec stretch; Isolation", "strength,band,chest,isolation"),
    ("Band Shoulder Press", "shoulders", "delts", "band", 3.5, "Stand on band; Press overhead; Shoulder work; Portable", "strength,band,shoulders"),
    ("Band Lateral Raise", "shoulders", "side delts", "band", 3.0, "Stand on band; Raise arms; Side delts; Constant tension", "strength,band,shoulders,isolation"),
    ("Band Front Raise", "shoulders", "front delts", "band", 3.0, "Stand on band; Raise forward; Front delts; Isolation", "strength,band,shoulders,isolation"),
    ("Band Rows", "back", "lats", "band", 3.5, "Anchor band; Pull to torso; Back work; Portable workout", "strength,band,back"),
    ("Band Lat Pulldown", "back", "lats", "band", 3.5, "Band overhead; Pull down; Lat work; At-home exercise", "strength,band,lats"),
    ("Band Bicep Curl", "biceps", "biceps", "band", 2.5, "Stand on band; Curl up; Bicep work; Simple", "strength,band,biceps,isolation"),
    ("Band Tricep Extension", "triceps", "triceps", "band", 2.5, "Band overhead; Extend down; Tricep work; Portable", "strength,band,triceps,isolation"),
    ("Band Squat", "legs", "quads", "band", 4.0, "Band provides resistance; Squat pattern; Leg work", "strength,band,legs"),
    ("Band Leg Press", "legs", "quads", "band", 4.0, "Lying; Band on feet; Press out; Quad work", "strength,band,legs"),
    ("Band Leg Curl", "hamstrings", "hamstrings", "band", 3.0, "Lying; Band on ankle; Curl to glutes; Hamstring work", "strength,band,hamstrings,isolation"),
    ("Band Glute Bridge", "glutes", "glutes", "band", 3.5, "Band around knees; Bridge up; Glute activation; Abductor work", "strength,band,glutes"),
    ("Band Clamshell", "glutes", "glutes", "band", 3.0, "Side-lying; Open knees; Glute medius; Hip stability", "strength,band,glutes,isolation"),
    ("Band Monster Walk", "glutes", "glutes", "band", 3.5, "Band around ankles or knees; Walk; Glute and hip work; Activation", "strength,band,glutes,functional"),
    ("Band Face Pull", "shoulders", "rear delts", "band", 3.0, "Pull to face; External rotation; Rear delts and upper back", "strength,band,shoulders"),
    ("Band Good Morning", "hamstrings", "hamstrings", "band", 3.5, "Band across back; Hip hinge; Hamstring stretch; Pattern work", "strength,band,hamstrings"),
    ("Band Ab Crunch", "core", "abs", "band", 3.0, "Band provides resistance; Crunch pattern; Ab work", "strength,band,abs"),
    ("Band Pallof Press", "core", "obliques", "band", 3.0, "Anti-rotation; Press out; Core stability; Functional", "strength,band,core"),
    ("Band Wood Chop", "core", "obliques", "band", 3.5, "Diagonal movement; Rotation; Functional core; Athletic", "strength,band,core,functional"),
]

for base_name, body_part, target, equipment, met, instructions, tags in band_variants:
    for difficulty in difficulties:
        met_adjusted = met * (0.85 if difficulty == "Beginner" else 1.0 if difficulty == "Intermediate" else 1.15)
        STRENGTH_EXERCISES.append({
            "id": f"strength_{exercise_id}",
            "name": f"{base_name} — {difficulty}",
            "category": "Strength",
            "body_part": body_part,
            "target": target,
            "equipment": equipment,
            "difficulty": difficulty,
            "calories_per_minute": met_to_calories(met_adjusted),
            "instructions": instructions,
            "tags": tags
        })
        exercise_id += 1

# Olympic Lifts
olympic_variants = [
    ("Barbell Clean", "full body", "power", "barbell", 6.0, "Pull bar from floor; Catch at shoulders; Triple extension; Power movement", "strength,olympic,power,barbell,advanced"),
    ("Barbell Clean and Jerk", "full body", "power", "barbell", 7.0, "Clean to shoulders; Dip and drive overhead; Technical; Elite lift", "strength,olympic,power,barbell,advanced"),
    ("Barbell Snatch", "full body", "power", "barbell", 7.0, "Wide grip; Pull overhead in one motion; Most technical; Elite", "strength,olympic,power,barbell,advanced"),
    ("Barbell Power Clean", "full body", "power", "barbell", 6.0, "Partial depth catch; Explosive; Power development", "strength,olympic,power,barbell"),
    ("Barbell Hang Clean", "full body", "power", "barbell", 5.5, "Start at knees; Clean to shoulders; Easier than floor", "strength,olympic,power,barbell"),
    ("Kettlebell Clean", "full body", "power", "kettlebell", 5.0, "Pull kettlebell to rack; Hip snap; Catch at shoulder", "strength,olympic,power,kettlebell"),
    ("Kettlebell Snatch", "full body", "power", "kettlebell", 6.0, "Pull overhead in one motion; Hip drive; Catch overhead", "strength,olympic,power,kettlebell"),
]

for base_name, body_part, target, equipment, met, instructions, tags in olympic_variants:
    for difficulty in ["Intermediate", "Advanced"]:  # Only intermediate and advanced for Olympic lifts
        met_adjusted = met * (1.0 if difficulty == "Intermediate" else 1.15)
        STRENGTH_EXERCISES.append({
            "id": f"strength_{exercise_id}",
            "name": f"{base_name} — {difficulty}",
            "category": "Strength",
            "body_part": body_part,
            "target": target,
            "equipment": equipment,
            "difficulty": difficulty,
            "calories_per_minute": met_to_calories(met_adjusted),
            "instructions": instructions,
            "tags": tags
        })
        exercise_id += 1

print(f"Generated {len(STRENGTH_EXERCISES)} strength exercises")

# ============================================================================
# FLEXIBILITY/MOBILITY EXERCISES (~200)
# ============================================================================

FLEXIBILITY_EXERCISES = []

flexibility_variants = [
    # Lower Body Stretches
    ("Hamstring Stretch — Standing", "hamstrings", "flexibility", "body weight", 2.5, "One leg elevated; Reach toward toes; Feel stretch; Hold 20-30s; No bouncing", "flexibility,stretching,hamstrings"),
    ("Hamstring Stretch — Seated", "hamstrings", "flexibility", "body weight", 2.5, "Sit with legs extended; Reach forward; Feel stretch in back of legs; Breathe", "flexibility,stretching,hamstrings"),
    ("Quad Stretch — Standing", "quads", "flexibility", "body weight", 2.5, "Pull foot to glutes; Keep knees together; Feel front thigh stretch; Balance", "flexibility,stretching,quads"),
    ("Hip Flexor Stretch — Kneeling", "hips", "flexibility", "body weight", 2.5, "Lunge position; Push hips forward; Upright torso; Feel front of hip", "flexibility,stretching,hips"),
    ("Pigeon Pose", "hips", "flexibility", "body weight", 2.5, "One leg bent in front; Other extended back; Deep hip stretch; Hold and breathe", "flexibility,stretching,hips,yoga"),
    ("Figure-4 Stretch", "glutes", "flexibility", "body weight", 2.5, "Lie on back; Cross ankle over knee; Pull leg toward chest; Glute stretch", "flexibility,stretching,glutes"),
    ("Butterfly Stretch", "hips", "flexibility", "body weight", 2.5, "Sit; Feet together; Knees out; Gently press knees down; Inner thigh", "flexibility,stretching,hips"),
    ("Calf Stretch — Wall", "calves", "flexibility", "body weight", 2.5, "Hands on wall; One leg back; Heel down; Lean forward; Feel calf", "flexibility,stretching,calves"),
    ("IT Band Stretch", "hips", "flexibility", "body weight", 2.5, "Cross one leg behind; Lean to side; Feel outer hip; Hold", "flexibility,stretching,hips"),
    
    # Upper Body Stretches
    ("Chest Stretch — Doorway", "chest", "flexibility", "body weight", 2.5, "Arm on doorframe; Turn body away; Feel chest stretch; Hold", "flexibility,stretching,chest"),
    ("Shoulder Stretch — Cross Body", "shoulders", "flexibility", "body weight", 2.5, "Pull arm across chest; Feel shoulder stretch; Hold; Switch sides", "flexibility,stretching,shoulders"),
    ("Tricep Stretch — Overhead", "triceps", "flexibility", "body weight", 2.5, "Reach arm overhead; Bend elbow; Pull with other hand; Feel tricep", "flexibility,stretching,triceps"),
    ("Lat Stretch", "lats", "flexibility", "body weight", 2.5, "Reach overhead; Side bend; Feel lat stretch; Breathe deeply", "flexibility,stretching,lats"),
    ("Upper Back Stretch", "upper back", "flexibility", "body weight", 2.5, "Clasp hands forward; Round upper back; Spread shoulder blades", "flexibility,stretching,back"),
    
    # Spine/Back
    ("Cat-Cow", "back", "mobility", "body weight", 2.5, "Hands and knees; Arch and round spine; Breathe with movement; Spinal mobility", "mobility,stretching,back,yoga"),
    ("Child's Pose", "back", "flexibility", "body weight", 2.5, "Sit on heels; Reach arms forward; Forehead to ground; Relax and breathe", "flexibility,stretching,back,yoga"),
    ("Cobra Stretch", "abs", "flexibility", "body weight", 2.5, "Lie face down; Press up with arms; Arch back; Feel abs stretch", "flexibility,stretching,abs,yoga"),
    ("Downward Dog", "full body", "flexibility", "body weight", 3.0, "Inverted V; Hands and feet down; Push hips up; Full body stretch", "flexibility,stretching,yoga"),
    ("Thread the Needle", "back", "mobility", "body weight", 2.5, "Hands and knees; Thread arm under; Rotate spine; Thoracic mobility", "mobility,stretching,back"),
    ("Spinal Twist — Seated", "back", "mobility", "body weight", 2.5, "Sit; Twist torso; Look behind; Feel spinal rotation; Both sides", "mobility,stretching,back"),
    
    # Neck and Shoulders
    ("Neck Rolls", "neck", "mobility", "body weight", 2.0, "Slowly roll head in circle; Both directions; Release tension; Be gentle", "mobility,stretching,neck"),
    ("Neck Stretch — Side", "neck", "flexibility", "body weight", 2.0, "Tilt head to side; Feel stretch; Hold; Switch sides; Breathe", "flexibility,stretching,neck"),
    ("Shoulder Rolls", "shoulders", "mobility", "body weight", 2.0, "Roll shoulders forward and back; Release tension; Full circles", "mobility,stretching,shoulders"),
    
    # Dynamic Mobility
    ("Leg Swings — Forward/Back", "hips", "mobility", "body weight", 3.0, "Hold support; Swing leg forward and back; Control; Hip mobility", "mobility,dynamic,hips"),
    ("Leg Swings — Side to Side", "hips", "mobility", "body weight", 3.0, "Hold support; Swing leg side to side; Hip mobility; Balance", "mobility,dynamic,hips"),
    ("Arm Circles", "shoulders", "mobility", "body weight", 2.5, "Make circles with arms; Both directions; Shoulder mobility; Warm-up", "mobility,dynamic,shoulders"),
    ("Torso Twists", "core", "mobility", "body weight", 2.5, "Stand; Rotate torso side to side; Arms swing; Spinal rotation", "mobility,dynamic,core"),
    ("Hip Circles", "hips", "mobility", "body weight", 2.5, "Make circles with hips; Both directions; Hip mobility; Control", "mobility,dynamic,hips"),
    ("Ankle Circles", "calves", "mobility", "body weight", 2.0, "Rotate ankle in circles; Both directions; Ankle mobility; Each foot", "mobility,dynamic,calves"),
    ("Wrist Circles", "forearms", "mobility", "body weight", 2.0, "Rotate wrists in circles; Both directions; Wrist mobility; Loosen up", "mobility,dynamic,forearms"),
    
    # Yoga Poses
    ("Warrior I", "full body", "flexibility", "body weight", 3.0, "Lunge stance; Arms overhead; Hip flexor and shoulder stretch", "flexibility,yoga"),
    ("Warrior II", "full body", "flexibility", "body weight", 3.0, "Wide stance; Arms out; Hip opener; Strength and flexibility", "flexibility,yoga"),
    ("Triangle Pose", "full body", "flexibility", "body weight", 3.0, "Wide stance; Reach to side; Open chest; Hamstring and hip", "flexibility,yoga"),
    ("Forward Fold", "hamstrings", "flexibility", "body weight", 2.5, "Hinge at hips; Reach toward ground; Hamstring stretch; Relax", "flexibility,stretching,hamstrings,yoga"),
    ("Lizard Pose", "hips", "flexibility", "body weight", 2.5, "Low lunge; Deep hip flexor stretch; Twist possible; Hold and breathe", "flexibility,hips,yoga"),
    ("Frog Pose", "hips", "flexibility", "body weight", 3.0, "On knees; Spread wide; Deep inner thigh; Gentle pressure", "flexibility,hips,yoga"),
    ("Happy Baby", "hips", "flexibility", "body weight", 2.5, "On back; Hold feet; Pull knees; Hip and glute stretch", "flexibility,hips,yoga"),
    ("Reclined Twist", "back", "mobility", "body weight", 2.5, "Lie on back; Knee across body; Spinal twist; Both sides", "mobility,back,yoga"),
    ("Bridge Pose", "back", "flexibility", "body weight", 3.0, "Lie on back; Lift hips; Backbend; Chest and hip flexors", "flexibility,back,yoga"),
    ("Bow Pose", "back", "flexibility", "body weight", 3.5, "Lie face down; Grab ankles; Pull up; Deep backbend", "flexibility,back,yoga,advanced"),
    ("Camel Pose", "back", "flexibility", "body weight", 3.0, "Kneeling; Arch back; Reach for heels; Chest and hip flexors", "flexibility,back,yoga"),
    ("Seated Forward Bend", "hamstrings", "flexibility", "body weight", 2.5, "Sit; Legs extended; Reach forward; Hamstring and back", "flexibility,hamstrings,yoga"),
    ("Wide-Legged Forward Fold", "hamstrings", "flexibility", "body weight", 2.5, "Wide stance; Fold forward; Hamstring and inner thigh", "flexibility,hamstrings,yoga"),
    ("Garland Pose (Squat)", "hips", "flexibility", "body weight", 2.5, "Deep squat; Hands together; Hip mobility; Ankle flexibility", "flexibility,hips,yoga"),
    ("Extended Side Angle", "full body", "flexibility", "body weight", 3.0, "Lunge; Reach overhead; Side stretch; Hip and oblique", "flexibility,yoga"),
    ("Half Pigeon", "hips", "flexibility", "body weight", 2.5, "One leg bent; Hip opener; Glute stretch; Hold and relax", "flexibility,hips,yoga"),
    ("Supine Figure-4", "glutes", "flexibility", "body weight", 2.5, "On back; Ankle on knee; Pull leg; Glute and hip", "flexibility,glutes,hips"),
    ("Standing Forward Bend", "hamstrings", "flexibility", "body weight", 2.5, "Hinge forward; Hang; Hamstring stretch; Decompress spine", "flexibility,hamstrings,yoga"),
    ("Revolved Triangle", "full body", "flexibility", "body weight", 3.0, "Triangle with twist; Balance; Hamstring and spinal rotation", "flexibility,yoga,advanced"),
    ("King Pigeon", "hips", "flexibility", "body weight", 3.5, "Pigeon with backbend; Advanced hip and back; Hold carefully", "flexibility,hips,advanced,yoga"),
    ("Splits — Front", "legs", "flexibility", "body weight", 3.0, "One leg forward; One back; Full split; Advanced flexibility", "flexibility,legs,advanced"),
    ("Splits — Side (Straddle)", "legs", "flexibility", "body weight", 3.0, "Legs wide to sides; Full straddle; Advanced flexibility", "flexibility,legs,advanced"),
    ("Doorway Pec Stretch", "chest", "flexibility", "body weight", 2.5, "Arm in doorway; Turn away; Pec stretch; Vary angles", "flexibility,chest"),
    ("Wall Angels", "shoulders", "mobility", "body weight", 2.5, "Back to wall; Arms up and down; Shoulder mobility; Posture", "mobility,shoulders"),
    ("Banded Shoulder Dislocates", "shoulders", "mobility", "band", 2.5, "Band overhead; Rotate back; Shoulder mobility; Warm-up", "mobility,shoulders,band"),
    ("Thoracic Extension — Foam Roller", "back", "mobility", "body weight", 2.5, "Foam roller on mid-back; Extend over roller; Thoracic mobility", "mobility,back"),
    ("90/90 Hip Stretch", "hips", "mobility", "body weight", 2.5, "Both legs at 90°; Rotate between; Hip internal/external rotation", "mobility,hips"),
    ("Cossack Squat", "legs", "mobility", "body weight", 3.0, "Wide stance; Shift side to side; Hip and adductor mobility", "mobility,hips,legs"),
    ("World's Greatest Stretch", "full body", "mobility", "body weight", 3.0, "Lunge with rotation; Full body mobility; Dynamic warm-up", "mobility,dynamic"),
    ("Shin Box", "hips", "mobility", "body weight", 2.5, "Seated 90/90; Alternate sides; Hip mobility drill", "mobility,hips"),
    ("Couch Stretch", "hips", "flexibility", "body weight", 2.5, "Rear leg on couch; Deep hip flexor; Quad stretch; Intense", "flexibility,hips,quads"),
]

for base_name, body_part, target, equipment, met, instructions, tags in flexibility_variants:
    for difficulty in difficulties:
        met_adjusted = met * (0.85 if difficulty == "Beginner" else 1.0 if difficulty == "Intermediate" else 1.15)
        FLEXIBILITY_EXERCISES.append({
            "id": f"flex_{exercise_id}",
            "name": f"{base_name} — {difficulty}",
            "category": "Flexibility/Mobility",
            "body_part": body_part,
            "target": target,
            "equipment": equipment,
            "difficulty": difficulty,
            "calories_per_minute": met_to_calories(met_adjusted),
            "instructions": instructions,
            "tags": tags
        })
        exercise_id += 1

print(f"Generated {len(FLEXIBILITY_EXERCISES)} flexibility/mobility exercises")

# ============================================================================
# WRITE TO CSV
# ============================================================================

ALL_EXERCISES = CARDIO_EXERCISES + STRENGTH_EXERCISES + FLEXIBILITY_EXERCISES

print(f"\nTotal exercises generated: {len(ALL_EXERCISES)}")

with open(CSV_PATH, 'w', newline='', encoding='utf-8') as f:
    fieldnames = ['id', 'name', 'category', 'body_part', 'target', 'equipment', 'difficulty', 'calories_per_minute', 'instructions', 'tags']
    writer = csv.DictWriter(f, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(ALL_EXERCISES)

print(f"Successfully wrote {len(ALL_EXERCISES)} exercises to {CSV_PATH}")

# Verify uniqueness
names = [ex['name'] for ex in ALL_EXERCISES]
if len(names) != len(set(names)):
    from collections import Counter
    duplicates = {n: c for n, c in Counter(names).items() if c > 1}
    print(f"\nWARNING: Found {len(duplicates)} duplicate names:")
    for name, count in list(duplicates.items())[:10]:
        print(f"  {name}: {count}x")
else:
    print("\nAll exercise names are unique")

# Summary by category
from collections import Counter
category_counts = Counter(ex['category'] for ex in ALL_EXERCISES)
print("\nExercises by category:")
for category, count in category_counts.items():
    print(f"  {category}: {count}")
