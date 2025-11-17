import 'package:flutter/material.dart';
import '../design_system/app_design_system.dart';

/// Password strength calculation result
class PasswordStrengthResult {
  final String strength; // 'weak', 'medium', 'strong'
  final int score; // 0-5
  final List<String> requirementsMet;
  final List<String> requirementsMissing;
  final bool isValid; // true if medium or strong

  PasswordStrengthResult({
    required this.strength,
    required this.score,
    required this.requirementsMet,
    required this.requirementsMissing,
    required this.isValid,
  });
}

/// Calculate password strength
PasswordStrengthResult calculatePasswordStrength(String password) {
  if (password.isEmpty) {
    return PasswordStrengthResult(
      strength: 'weak',
      score: 0,
      requirementsMet: [],
      requirementsMissing: ['length', 'uppercase', 'number', 'special'],
      isValid: false,
    );
  }

  final requirementsMet = <String>[];
  final requirementsMissing = <String>[];
  int score = 0;

  // Check length (minimum 8 characters)
  final hasLength = password.length >= 8;
  if (hasLength) {
    requirementsMet.add('length');
    score += 1;
  } else {
    requirementsMissing.add('length');
  }

  // Check uppercase letter
  final hasUpper = RegExp(r'[A-Z]').hasMatch(password);
  if (hasUpper) {
    requirementsMet.add('uppercase');
    score += 1;
  } else {
    requirementsMissing.add('uppercase');
  }

  // Check lowercase letter
  final hasLower = RegExp(r'[a-z]').hasMatch(password);
  if (hasLower) {
    requirementsMet.add('lowercase');
    score += 1;
  } else {
    requirementsMissing.add('lowercase');
  }

  // Check number
  final hasDigit = RegExp(r'[0-9]').hasMatch(password);
  if (hasDigit) {
    requirementsMet.add('number');
    score += 1;
  } else {
    requirementsMissing.add('number');
  }

  // Check special character
  final hasSpecial = RegExp(r'[!@#$%^&*()_+\-=\[\]{}|;:,.<>?~]').hasMatch(password);
  if (hasSpecial) {
    requirementsMet.add('special');
    score += 1;
  } else {
    requirementsMissing.add('special');
  }

  // Determine strength
  // Core requirements: length >= 8, uppercase, number
  // Special character is optional - passwords without it can still be medium
  final coreRequirementsMet = [
    hasLength,
    hasUpper,
    hasDigit,
  ].where((req) => req).length;

  String strength;
  bool isValid;

  final isStrongPassword = score == 5;

  // Strong: all 5 requirements met (length, uppercase, lowercase, number, special)
  if (isStrongPassword) {
    strength = 'strong';
    isValid = true;
  }
  // Weak: less than 3 core requirements (length, uppercase, number) OR score <= 2
  else if (coreRequirementsMet < 3 || score <= 2) {
    strength = 'weak';
    isValid = false;
  }
  // Medium: meets at least 3 core requirements and score >= 3 (covers remaining cases)
  else {
    strength = 'medium';
    isValid = true;
  }

  return PasswordStrengthResult(
    strength: strength,
    score: score,
    requirementsMet: requirementsMet,
    requirementsMissing: requirementsMissing,
    isValid: isValid,
  );
}

/// Professional password strength meter widget
class PasswordStrengthMeter extends StatelessWidget {
  final String password;
  final Color? primaryColor;

  const PasswordStrengthMeter({
    super.key,
    required this.password,
    this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final result = calculatePasswordStrength(password);

    Color strengthColor;
    String strengthLabel;
    double strengthPercent;

    switch (result.strength) {
      case 'weak':
        strengthColor = AppDesignSystem.error;
        strengthLabel = 'Weak';
        strengthPercent = 0.33;
        break;
      case 'medium':
        strengthColor = AppDesignSystem.warning;
        strengthLabel = 'Medium';
        strengthPercent = 0.66;
        break;
      case 'strong':
        strengthColor = AppDesignSystem.success;
        strengthLabel = 'Strong';
        strengthPercent = 1.0;
        break;
      default:
        strengthColor = AppDesignSystem.outline;
        strengthLabel = '';
        strengthPercent = 0.0;
    }

    if (password.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppDesignSystem.radiusXS),
                child: LinearProgressIndicator(
                  value: strengthPercent,
                  backgroundColor: AppDesignSystem.outline,
                  valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
                  minHeight: 4,
                ),
              ),
            ),
            const SizedBox(width: AppDesignSystem.spaceSM),
            Text(
              strengthLabel,
              style: AppDesignSystem.bodySmall.copyWith(
                color: strengthColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Password requirements checklist widget
class PasswordRequirementsChecklist extends StatelessWidget {
  final String password;
  final Color? primaryColor;

  const PasswordRequirementsChecklist({
    super.key,
    required this.password,
    this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final result = calculatePasswordStrength(password);

    final requirements = [
      {
        'key': 'length',
        'label': 'At least 8 characters',
        'met': result.requirementsMet.contains('length'),
      },
      {
        'key': 'uppercase',
        'label': '1 uppercase letter (A-Z)',
        'met': result.requirementsMet.contains('uppercase'),
      },
      {
        'key': 'number',
        'label': '1 number (0-9)',
        'met': result.requirementsMet.contains('number'),
      },
      {
        'key': 'special',
        'label': '1 special character (!@#\$%^&*...)',
        'met': result.requirementsMet.contains('special'),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Password Requirements:',
          style: AppDesignSystem.labelMedium.copyWith(
            color: AppDesignSystem.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppDesignSystem.spaceSM),
        ...requirements.map((req) => Padding(
              padding: const EdgeInsets.only(bottom: AppDesignSystem.spaceXS),
              child: Row(
                children: [
                  Icon(
                    req['met'] as bool ? Icons.check_circle : Icons.circle_outlined,
                    size: 16,
                    color: req['met'] as bool
                        ? AppDesignSystem.success
                        : AppDesignSystem.outlineVariant,
                  ),
                  const SizedBox(width: AppDesignSystem.spaceSM),
                  Expanded(
                    child: Text(
                      req['label'] as String,
                      style: AppDesignSystem.bodySmall.copyWith(
                        color: req['met'] as bool
                            ? AppDesignSystem.onSurface
                            : AppDesignSystem.onSurfaceVariant,
                        decoration: req['met'] as bool
                            ? TextDecoration.none
                            : TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}

