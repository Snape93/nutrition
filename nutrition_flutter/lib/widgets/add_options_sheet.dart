import 'package:flutter/material.dart';
import '../theme_service.dart';
import '../design_system/app_design_system.dart';

class AddOptionsSheet extends StatelessWidget {
  final VoidCallback onFoodLog;
  final VoidCallback onCustomMeals;
  final String? userSex;

  const AddOptionsSheet({
    super.key,
    required this.onFoodLog,
    required this.onCustomMeals,
    this.userSex,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = ThemeService.getPrimaryColor(userSex);
    final backgroundColor = ThemeService.getBackgroundColor(userSex);
    final secondaryColor = AppDesignSystem.info; // Use info color as secondary

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 32,
              height: 3,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              'What would you like to add?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 20),

            // Options
            Row(
              children: [
                // Log Food Option
                Expanded(
                  child: _buildOptionCard(
                    context: context,
                    icon: Icons.restaurant,
                    title: 'Log Food',
                    subtitle: 'Add foods from database',
                    color: primaryColor,
                    onTap: () {
                      Navigator.pop(context);
                      onFoodLog();
                    },
                  ),
                ),
                const SizedBox(width: 12),

                // Custom Meals Option
                Expanded(
                  child: _buildOptionCard(
                    context: context,
                    icon: Icons.restaurant_menu,
                    title: 'Custom Meals',
                    subtitle: 'Create your own recipes',
                    color: secondaryColor,
                    onTap: () {
                      Navigator.pop(context);
                      onCustomMeals();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
