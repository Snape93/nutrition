"""
Test script to verify ALL food preferences work correctly
Tests each preference individually to ensure proper filtering/scoring
"""

import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

def test_all_preferences():
    """Test all available food preferences"""
    print("=" * 70)
    print("TESTING ALL FOOD PREFERENCES")
    print("=" * 70)
    
    try:
        from app import _apply_preference_filtering
        
        # Test foods covering different categories
        test_foods = [
            # Meats
            "chicken adobo",
            "pork sinigang",
            "beef steak",
            "fried chicken",
            "lechon",
            # Vegetables
            "vegetable stir fry",
            "ampalaya",
            "kangkong",
            "ginisang monggo",
            "pinakbet",
            # Fruits
            "mango",
            "banana",
            "apple",
            "fruit salad",
            # Grains/Staples
            "white rice",
            "pancit canton",
            "bread",
            # Spicy foods
            "bicol express",
            "spicy adobo",
            # Sweet foods
            "halo-halo",
            "leche flan",
            "cake",
            # Comfort foods
            "arroz caldo",
            "champorado",
            "soup",
            # Protein-rich
            "egg",
            "tofu",
            "fish",
        ]
        
        print(f"\nTest Foods: {len(test_foods)} foods")
        print(f"Categories: Meats, Vegetables, Fruits, Grains, Spicy, Sweet, Comfort, Protein")
        
        # Define all available preferences
        all_preferences = [
            'plant-based',
            'healthy',
            'protein',
            'spicy',
            'sweet',
            'comfort'
        ]
        
        print(f"\nTesting {len(all_preferences)} preferences:")
        for pref in all_preferences:
            print(f"  - {pref}")
        
        results = {}
        
        # Test each preference individually
        for preference in all_preferences:
            print(f"\n{'=' * 70}")
            print(f"TESTING: {preference.upper()}")
            print('=' * 70)
            
            filtered = _apply_preference_filtering(test_foods, [preference])
            
            print(f"Input: {len(test_foods)} foods")
            print(f"Output: {len(filtered)} foods")
            print(f"Filtered foods: {filtered}")
            
            # Analyze results
            meat_count = sum(1 for f in filtered if any(kw in f.lower() for kw in ['chicken', 'pork', 'beef', 'lechon']))
            vegetable_count = sum(1 for f in filtered if any(kw in f.lower() for kw in ['vegetable', 'ampalaya', 'kangkong', 'monggo', 'pinakbet']))
            fruit_count = sum(1 for f in filtered if any(kw in f.lower() for kw in ['mango', 'banana', 'apple', 'fruit']))
            spicy_count = sum(1 for f in filtered if any(kw in f.lower() for kw in ['spicy', 'bicol']))
            sweet_count = sum(1 for f in filtered if any(kw in f.lower() for kw in ['halo', 'flan', 'cake', 'sweet']))
            comfort_count = sum(1 for f in filtered if any(kw in f.lower() for kw in ['arroz', 'champorado', 'soup']))
            protein_count = sum(1 for f in filtered if any(kw in f.lower() for kw in ['chicken', 'pork', 'beef', 'egg', 'tofu', 'fish']))
            
            # Verify each preference
            passed = True
            issues = []
            
            if preference == 'plant-based':
                if meat_count > 0:
                    passed = False
                    issues.append(f"Should exclude meats, but {meat_count} meat foods found")
                else:
                    print(f"  [OK] Excluded all {len(test_foods) - len(filtered)} meat foods")
                    if vegetable_count + fruit_count > 0:
                        print(f"  [OK] Included {vegetable_count + fruit_count} plant foods")
            
            elif preference == 'healthy':
                if vegetable_count + fruit_count == 0:
                    passed = False
                    issues.append("Should include healthy foods (vegetables, fruits)")
                else:
                    print(f"  [OK] Included {vegetable_count + fruit_count} healthy foods")
            
            elif preference == 'protein':
                if protein_count == 0:
                    passed = False
                    issues.append("Should include protein foods")
                else:
                    print(f"  [OK] Included {protein_count} protein foods")
            
            elif preference == 'spicy':
                if spicy_count == 0:
                    passed = False
                    issues.append("Should include spicy foods")
                else:
                    print(f"  [OK] Included {spicy_count} spicy foods")
            
            elif preference == 'sweet':
                if sweet_count == 0:
                    passed = False
                    issues.append("Should include sweet foods")
                else:
                    print(f"  [OK] Included {sweet_count} sweet foods")
            
            elif preference == 'comfort':
                if comfort_count == 0:
                    passed = False
                    issues.append("Should include comfort foods")
                else:
                    print(f"  [OK] Included {comfort_count} comfort foods")
            
            if passed:
                print(f"  [PASS] {preference} preference works correctly")
            else:
                print(f"  [FAIL] {preference} preference has issues:")
                for issue in issues:
                    print(f"    - {issue}")
            
            results[preference] = {
                'passed': passed,
                'input_count': len(test_foods),
                'output_count': len(filtered),
                'filtered': filtered,
                'issues': issues
            }
        
        # Test multiple preferences together
        print(f"\n{'=' * 70}")
        print("TESTING: MULTIPLE PREFERENCES")
        print('=' * 70)
        
        # Test plant-based + healthy
        print("\n[1] Test: plant-based + healthy")
        filtered = _apply_preference_filtering(test_foods, ['plant-based', 'healthy'])
        print(f"   Input: {len(test_foods)} foods")
        print(f"   Output: {len(filtered)} foods")
        print(f"   Filtered: {filtered}")
        meat_count = sum(1 for f in filtered if any(kw in f.lower() for kw in ['chicken', 'pork', 'beef']))
        healthy_count = sum(1 for f in filtered if any(kw in f.lower() for kw in ['vegetable', 'fruit', 'mango', 'apple']))
        if meat_count == 0 and healthy_count > 0:
            print("   [PASS] Multiple preferences work correctly")
        else:
            print(f"   [FAIL] Issues with multiple preferences")
        
        # Test protein + spicy
        print("\n[2] Test: protein + spicy")
        filtered = _apply_preference_filtering(test_foods, ['protein', 'spicy'])
        print(f"   Input: {len(test_foods)} foods")
        print(f"   Output: {len(filtered)} foods")
        print(f"   Filtered: {filtered}")
        protein_spicy = sum(1 for f in filtered if any(kw in f.lower() for kw in ['bicol', 'spicy', 'chicken', 'pork']))
        if protein_spicy > 0:
            print("   [PASS] Multiple preferences work correctly")
        else:
            print(f"   [FAIL] Should include protein + spicy foods")
        
        # Summary
        print(f"\n{'=' * 70}")
        print("TEST SUMMARY")
        print('=' * 70)
        
        all_passed = True
        for pref, result in results.items():
            status = "[PASS]" if result['passed'] else "[FAIL]"
            print(f"{status}: {pref}")
            if not result['passed']:
                all_passed = False
                for issue in result['issues']:
                    print(f"  - {issue}")
        
        print(f"\n{'=' * 70}")
        if all_passed:
            print("ALL PREFERENCES WORKING CORRECTLY!")
        else:
            print("SOME PREFERENCES HAVE ISSUES")
        print('=' * 70)
        
        return all_passed
        
    except Exception as e:
        print(f"\n[ERROR] {str(e)}")
        import traceback
        traceback.print_exc()
        return False


def main():
    """Run all preference tests"""
    success = test_all_preferences()
    return 0 if success else 1


if __name__ == "__main__":
    exit(main())


