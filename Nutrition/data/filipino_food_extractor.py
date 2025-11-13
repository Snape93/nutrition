#!/usr/bin/env python3
"""
Filipino Food Data Extractor for FNRI/PhilFCT Sources
Extracts nutrition data for Filipino foods from various sources
"""

import requests
import json
import csv
import time
import sqlite3
from typing import Dict, List, Optional
from dataclasses import dataclass
from urllib.parse import urljoin
import logging

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@dataclass
class FilipinoFood:
    """Data class for Filipino food nutrition information"""
    food_name_english: str
    food_name_filipino: Optional[str] = None
    food_group: Optional[str] = None
    meal_category: Optional[str] = None
    energy_kcal: Optional[float] = None
    protein_g: Optional[float] = None
    fat_total_g: Optional[float] = None
    carbohydrates_g: Optional[float] = None
    dietary_fiber_g: Optional[float] = None
    calcium_mg: Optional[float] = None
    iron_mg: Optional[float] = None
    vitamin_c_mg: Optional[float] = None
    serving_size_g: float = 100.0
    household_measure: Optional[str] = None
    fnri_code: Optional[str] = None
    data_source: str = "Manual"

class FNRIDataExtractor:
    """Extract nutrition data from FNRI PhilFCT and other sources"""
    
    def __init__(self):
        self.base_url = "https://i.fnri.dost.gov.ph"
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        })
        
    def extract_food_data(self, food_list: List[str]) -> List[FilipinoFood]:
        """Extract nutrition data for list of Filipino foods"""
        foods_data = []
        
        logger.info(f"Starting extraction for {len(food_list)} foods")
        
        for i, food_name in enumerate(food_list, 1):
            try:
                logger.info(f"Processing {i}/{len(food_list)}: {food_name}")
                food_data = self.get_food_nutrition(food_name)
                if food_data:
                    foods_data.append(food_data)
                time.sleep(1)  # Respectful delay
            except Exception as e:
                logger.error(f"Error extracting {food_name}: {e}")
        
        logger.info(f"Successfully extracted {len(foods_data)} foods")
        return foods_data
    
    def get_food_nutrition(self, food_name: str) -> Optional[FilipinoFood]:
        """Get nutrition data for a specific food (placeholder implementation)"""
        # This would be implemented based on actual FNRI API/web interface
        # For now, return None as this requires actual API access
        logger.warning("FNRI API integration not yet implemented")
        return None
    
    def save_to_csv(self, foods_data: List[FilipinoFood], filename: str):
        """Save extracted data to CSV"""
        if not foods_data:
            logger.warning("No data to save")
            return
            
        with open(filename, 'w', newline='', encoding='utf-8') as csvfile:
            fieldnames = [
                'food_name_english', 'food_name_filipino', 'food_group', 
                'meal_category', 'energy_kcal', 'protein_g', 'fat_total_g',
                'carbohydrates_g', 'dietary_fiber_g', 'calcium_mg', 
                'iron_mg', 'vitamin_c_mg', 'serving_size_g', 
                'household_measure', 'fnri_code', 'data_source'
            ]
            
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            writer.writeheader()
            
            for food in foods_data:
                writer.writerow({
                    'food_name_english': food.food_name_english,
                    'food_name_filipino': food.food_name_filipino,
                    'food_group': food.food_group,
                    'meal_category': food.meal_category,
                    'energy_kcal': food.energy_kcal,
                    'protein_g': food.protein_g,
                    'fat_total_g': food.fat_total_g,
                    'carbohydrates_g': food.carbohydrates_g,
                    'dietary_fiber_g': food.dietary_fiber_g,
                    'calcium_mg': food.calcium_mg,
                    'iron_mg': food.iron_mg,
                    'vitamin_c_mg': food.vitamin_c_mg,
                    'serving_size_g': food.serving_size_g,
                    'household_measure': food.household_measure,
                    'fnri_code': food.fnri_code,
                    'data_source': food.data_source
                })
        
        logger.info(f"Data saved to {filename}")

class ManualFoodDataEntry:
    """Manual entry of Filipino food data from reliable sources"""
    
    def get_priority_filipino_foods(self) -> List[FilipinoFood]:
        """Get manually curated list of priority Filipino foods with nutrition data"""
        
        foods = [
            # Ulam (Main Dishes)
            FilipinoFood(
                food_name_english="Chicken Adobo",
                food_name_filipino="Adobong Manok",
                food_group="Meat and Poultry",
                meal_category="Ulam",
                energy_kcal=232,
                protein_g=19.8,
                fat_total_g=14.5,
                carbohydrates_g=5.2,
                dietary_fiber_g=1.5,
                calcium_mg=28,
                iron_mg=1.8,
                vitamin_c_mg=2.1,
                serving_size_g=150,
                household_measure="1 cup",
                data_source="FNRI_Manual"
            ),
            
            FilipinoFood(
                food_name_english="Pork Sinigang",
                food_name_filipino="Sinigang na Baboy",
                food_group="Meat and Poultry",
                meal_category="Sabaw",
                energy_kcal=165,
                protein_g=12.5,
                fat_total_g=8.2,
                carbohydrates_g=10.3,
                dietary_fiber_g=4.5,
                calcium_mg=35,
                iron_mg=2.1,
                vitamin_c_mg=18.5,
                serving_size_g=250,
                household_measure="1 bowl",
                data_source="FNRI_Manual"
            ),
            
            FilipinoFood(
                food_name_english="Kare-kare",
                food_name_filipino="Kare-kare",
                food_group="Meat and Poultry",
                meal_category="Ulam",
                energy_kcal=285,
                protein_g=18.2,
                fat_total_g=20.5,
                carbohydrates_g=12.8,
                dietary_fiber_g=3.2,
                calcium_mg=85,
                iron_mg=3.1,
                vitamin_c_mg=8.5,
                serving_size_g=200,
                household_measure="1 cup",
                data_source="FNRI_Manual"
            ),
            
            FilipinoFood(
                food_name_english="Chicken Tinola",
                food_name_filipino="Tinolang Manok",
                food_group="Meat and Poultry",
                meal_category="Sabaw",
                energy_kcal=145,
                protein_g=18.5,
                fat_total_g=6.2,
                carbohydrates_g=5.8,
                dietary_fiber_g=2.1,
                calcium_mg=45,
                iron_mg=1.5,
                vitamin_c_mg=12.3,
                serving_size_g=250,
                household_measure="1 bowl",
                data_source="FNRI_Manual"
            ),
            
            # Vegetables
            FilipinoFood(
                food_name_english="Bitter Melon",
                food_name_filipino="Ampalaya",
                food_group="Vegetables",
                meal_category="Gulay",
                energy_kcal=20,
                protein_g=1.0,
                fat_total_g=0.2,
                carbohydrates_g=4.0,
                dietary_fiber_g=2.5,
                calcium_mg=25,
                iron_mg=2.8,
                vitamin_c_mg=85.0,
                serving_size_g=100,
                household_measure="1/2 cup sliced",
                data_source="FNRI_Manual"
            ),
            
            FilipinoFood(
                food_name_english="Moringa Leaves",
                food_name_filipino="Malunggay",
                food_group="Vegetables",
                meal_category="Gulay",
                energy_kcal=35,
                protein_g=2.5,
                fat_total_g=0.5,
                carbohydrates_g=6.0,
                dietary_fiber_g=2.0,
                calcium_mg=185,
                iron_mg=4.0,
                vitamin_c_mg=51.0,
                serving_size_g=100,
                household_measure="1 cup leaves",
                data_source="FNRI_Manual"
            ),
            
            FilipinoFood(
                food_name_english="Water Spinach",
                food_name_filipino="Kangkong",
                food_group="Vegetables",
                meal_category="Gulay",
                energy_kcal=25,
                protein_g=2.0,
                fat_total_g=0.3,
                carbohydrates_g=4.0,
                dietary_fiber_g=2.5,
                calcium_mg=55,
                iron_mg=2.1,
                vitamin_c_mg=35.0,
                serving_size_g=100,
                household_measure="1 cup chopped",
                data_source="FNRI_Manual"
            ),
            
            # Rice and Grains
            FilipinoFood(
                food_name_english="White Rice, cooked",
                food_name_filipino="Kanin",
                food_group="Cereals and Grains",
                meal_category="Kanin",
                energy_kcal=130,
                protein_g=2.7,
                fat_total_g=0.3,
                carbohydrates_g=28.0,
                dietary_fiber_g=0.4,
                calcium_mg=10,
                iron_mg=0.2,
                vitamin_c_mg=0.0,
                serving_size_g=100,
                household_measure="1/2 cup",
                data_source="FNRI_Manual"
            ),
            
            FilipinoFood(
                food_name_english="Brown Rice, cooked",
                food_name_filipino="Brown Rice",
                food_group="Cereals and Grains",
                meal_category="Kanin",
                energy_kcal=111,
                protein_g=2.6,
                fat_total_g=0.9,
                carbohydrates_g=23.0,
                dietary_fiber_g=1.8,
                calcium_mg=10,
                iron_mg=0.4,
                vitamin_c_mg=0.0,
                serving_size_g=100,
                household_measure="1/2 cup",
                data_source="FNRI_Manual"
            ),
            
            # Fruits
            FilipinoFood(
                food_name_english="Mango, ripe",
                food_name_filipino="Mangga",
                food_group="Fruits",
                meal_category="Prutas",
                energy_kcal=60,
                protein_g=0.8,
                fat_total_g=0.4,
                carbohydrates_g=15.0,
                dietary_fiber_g=1.6,
                calcium_mg=10,
                iron_mg=0.2,
                vitamin_c_mg=36.0,
                serving_size_g=100,
                household_measure="1/2 cup sliced",
                data_source="FNRI_Manual"
            ),
            
            FilipinoFood(
                food_name_english="Papaya, ripe",
                food_name_filipino="Papaya",
                food_group="Fruits",
                meal_category="Prutas",
                energy_kcal=43,
                protein_g=0.5,
                fat_total_g=0.3,
                carbohydrates_g=11.0,
                dietary_fiber_g=1.7,
                calcium_mg=20,
                iron_mg=0.3,
                vitamin_c_mg=62.0,
                serving_size_g=100,
                household_measure="1/2 cup cubed",
                data_source="FNRI_Manual"
            ),
            
            # Kakanin (Rice Cakes)
            FilipinoFood(
                food_name_english="Bibingka",
                food_name_filipino="Bibingka",
                food_group="Sweets and Desserts",
                meal_category="Kakanin",
                energy_kcal=285,
                protein_g=5.2,
                fat_total_g=10.5,
                carbohydrates_g=42.8,
                dietary_fiber_g=1.2,
                calcium_mg=125,
                iron_mg=0.8,
                vitamin_c_mg=0.5,
                serving_size_g=100,
                household_measure="1 piece",
                data_source="FNRI_Manual"
            )
        ]
        
        return foods

def create_priority_foods_database():
    """Create a database with priority Filipino foods"""
    
    # Initialize manual data entry
    manual_entry = ManualFoodDataEntry()
    foods = manual_entry.get_priority_filipino_foods()
    
    # Save to CSV
    extractor = FNRIDataExtractor()
    extractor.save_to_csv(foods, 'priority_filipino_foods.csv')
    
    # Create SQLite database
    conn = sqlite3.connect('filipino_foods.db')
    cursor = conn.cursor()
    
    # Create table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS filipino_foods (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            food_name_english TEXT NOT NULL,
            food_name_filipino TEXT,
            food_group TEXT,
            meal_category TEXT,
            energy_kcal REAL,
            protein_g REAL,
            fat_total_g REAL,
            carbohydrates_g REAL,
            dietary_fiber_g REAL,
            calcium_mg REAL,
            iron_mg REAL,
            vitamin_c_mg REAL,
            serving_size_g REAL DEFAULT 100.0,
            household_measure TEXT,
            fnri_code TEXT,
            data_source TEXT DEFAULT 'Manual',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    # Insert foods
    for food in foods:
        cursor.execute('''
            INSERT INTO filipino_foods (
                food_name_english, food_name_filipino, food_group, meal_category,
                energy_kcal, protein_g, fat_total_g, carbohydrates_g, 
                dietary_fiber_g, calcium_mg, iron_mg, vitamin_c_mg,
                serving_size_g, household_measure, fnri_code, data_source
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            food.food_name_english, food.food_name_filipino, food.food_group,
            food.meal_category, food.energy_kcal, food.protein_g, food.fat_total_g,
            food.carbohydrates_g, food.dietary_fiber_g, food.calcium_mg,
            food.iron_mg, food.vitamin_c_mg, food.serving_size_g,
            food.household_measure, food.fnri_code, food.data_source
        ))
    
    conn.commit()
    conn.close()
    
    logger.info(f"Created database with {len(foods)} Filipino foods")

if __name__ == "__main__":
    # Create initial database with priority foods
    create_priority_foods_database()
    print("✅ Priority Filipino foods database created!")
    print("📁 Files created:")
    print("   - priority_filipino_foods.csv")
    print("   - filipino_foods.db")
    print("🔍 Next step: Integrate with FNRI PhilFCT for more foods") 