import 'package:flutter/material.dart';
import '../models/streak_model.dart';
import '../design_system/app_design_system.dart';

/// Professional streak card widget matching the app design system
class StreakCard extends StatelessWidget {
  final StreakData? streakData;
  final String? userSex;
  final VoidCallback? onRefresh;
  final VoidCallback? onLogActivity;

  const StreakCard({
    super.key,
    this.streakData,
    this.userSex,
    this.onRefresh,
    this.onLogActivity,
  });

  // Dynamic color scheme based on user gender
  Color get _primaryColor => AppDesignSystem.getPrimaryColor(userSex);
  static const Color _textGray = Color(0xFF666666);
  static const Color _textLightGray = Color(0xFF999999);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width - 32, // Account for screen padding
      ),
      padding: const EdgeInsets.all(AppDesignSystem.spaceMD),
      decoration: BoxDecoration(
        color: AppDesignSystem.surface,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusLG),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: AppDesignSystem.elevationLow * 2,
            offset: const Offset(0, AppDesignSystem.elevationLow),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          const SizedBox(height: AppDesignSystem.spaceMD),
          if (streakData == null || streakData!.currentStreak == 0)
            _buildEmptyState()
          else
            _buildActiveStreak(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.local_fire_department,
                    color: _primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Streak',
                    style: AppDesignSystem.headlineSmall.copyWith(
                      color: AppDesignSystem.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Keep your momentum going',
                style: AppDesignSystem.bodyMedium.copyWith(
                  color: _textGray,
                ),
              ),
            ],
          ),
        ),
        if (onRefresh != null)
          GestureDetector(
            onTap: onRefresh,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.refresh,
                color: _primaryColor,
                size: 16,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActiveStreak() {
    if (streakData == null) return const SizedBox.shrink();

    return Column(
      children: [
        // Main streak display
        _buildStreakDisplay(),
        const SizedBox(height: AppDesignSystem.spaceMD),
        // Stats boxes
        _buildStatsRow(),
        const SizedBox(height: AppDesignSystem.spaceMD),
        // Motivational message
        _buildMotivationalMessage(),
      ],
    );
  }

  Widget _buildStreakDisplay() {
    if (streakData == null) return const SizedBox.shrink();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_fire_department,
              color: _primaryColor,
              size: 32,
            ),
            const SizedBox(width: 8),
            Text(
              '${streakData!.currentStreak}',
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                height: 1.0,
              ).copyWith(color: _primaryColor),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          streakData!.currentStreak == 1 ? 'day streak' : 'days streak',
          style: AppDesignSystem.bodyMedium.copyWith(
            color: _textGray,
          ),
        ),
        const SizedBox(height: 8),
        // Streak type badge
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: _primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _primaryColor.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Text(
            streakData!.streakTypeDisplayName,
            style: AppDesignSystem.labelMedium.copyWith(
              color: _primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    if (streakData == null) return const SizedBox.shrink();

    return Row(
      children: [
        Expanded(
          child: _buildStatBox(
            label: 'Current',
            value: '${streakData!.currentStreak}',
            unit: streakData!.currentStreak == 1 ? 'day' : 'days',
            isHighlighted: true,
          ),
        ),
        const SizedBox(width: AppDesignSystem.spaceSM),
        Expanded(
          child: _buildStatBox(
            label: 'Longest',
            value: '${streakData!.longestStreak}',
            unit: streakData!.longestStreak == 1 ? 'day' : 'days',
            isHighlighted: false,
            icon: Icons.emoji_events,
          ),
        ),
        const SizedBox(width: AppDesignSystem.spaceSM),
        Expanded(
          child: _buildStatBox(
            label: streakData!.streakStartDate != null ? 'Started' : 'Last',
            value: streakData!.daysSinceStart != null
                ? '${streakData!.daysSinceStart}'
                : streakData!.daysSinceBreak != null
                    ? '${streakData!.daysSinceBreak}'
                    : '—',
            unit: streakData!.daysSinceStart != null
                ? (streakData!.daysSinceStart == 1 ? 'day ago' : 'days ago')
                : streakData!.daysSinceBreak != null
                    ? (streakData!.daysSinceBreak == 1 ? 'day ago' : 'days ago')
                    : '',
            isHighlighted: false,
            icon: Icons.calendar_today,
          ),
        ),
      ],
    );
  }

  Widget _buildStatBox({
    required String label,
    required String value,
    required String unit,
    required bool isHighlighted,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 12,
        horizontal: 8,
      ),
      decoration: BoxDecoration(
        color: isHighlighted
            ? _primaryColor.withValues(alpha: 0.1)
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: isHighlighted
            ? Border.all(
                color: _primaryColor.withValues(alpha: 0.3),
                width: 1,
              )
            : null,
      ),
      child: Column(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 16,
              color: isHighlighted ? _primaryColor : _textLightGray,
            ),
            const SizedBox(height: 4),
          ],
          Text(
            value,
            style: AppDesignSystem.titleMedium.copyWith(
              color: isHighlighted ? _primaryColor : AppDesignSystem.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (unit.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              unit,
              style: AppDesignSystem.labelSmall.copyWith(
                color: _textLightGray,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            label,
            style: AppDesignSystem.labelMedium.copyWith(
              color: _textGray,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMotivationalMessage() {
    if (streakData == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              streakData!.motivationalMessage,
              style: AppDesignSystem.bodyMedium.copyWith(
                color: AppDesignSystem.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: _primaryColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.local_fire_department,
            color: _primaryColor,
            size: 30,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          streakData?.longestStreak != null && streakData!.longestStreak > 0
              ? 'Your streak has ended'
              : 'No streak yet',
          style: AppDesignSystem.headlineSmall.copyWith(
            color: AppDesignSystem.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          streakData?.longestStreak != null && streakData!.longestStreak > 0
              ? 'You had a ${streakData!.longestStreak}-day streak! Start a new one today and beat your record of ${streakData!.longestStreak} days.'
              : 'Start logging your ${streakData?.streakTypeDisplayName.toLowerCase() ?? "activity"} to begin your streak!',
          style: AppDesignSystem.bodyMedium.copyWith(
            color: _textGray,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        if (onLogActivity != null)
          ElevatedButton.icon(
            onPressed: onLogActivity,
            icon: const Icon(Icons.add, color: Colors.white, size: 20),
            label: const Text(
              'Log Activity',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
      ],
    );
  }
}

