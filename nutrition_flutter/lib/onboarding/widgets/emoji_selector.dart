import 'package:flutter/material.dart';
import '../../design_system/app_design_system.dart';

class EmojiOption {
  final String emoji;
  final String label;
  final String value;
  final String description;
  final Color? color;

  const EmojiOption({
    required this.emoji,
    required this.label,
    required this.value,
    required this.description,
    this.color,
  });
}

class EmojiSelector extends StatefulWidget {
  final List<EmojiOption> options;
  final String? selectedValue;
  final ValueChanged<String> onChanged;
  final String title;
  final String? subtitle;
  final bool allowMultipleSelection;
  final List<String>? selectedValues;
  final ValueChanged<List<String>>? onMultipleChanged;
  final Color primaryColor;

  const EmojiSelector({
    super.key,
    required this.options,
    this.selectedValue,
    required this.onChanged,
    required this.title,
    this.subtitle,
    this.allowMultipleSelection = false,
    this.selectedValues,
    this.onMultipleChanged,
    required this.primaryColor,
  });

  @override
  State<EmojiSelector> createState() => _EmojiSelectorState();
}

class _EmojiSelectorState extends State<EmojiSelector>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late List<AnimationController> _itemControllers;
  late List<Animation<double>> _itemAnimations;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _itemControllers = List.generate(
      widget.options.length,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 300),
        vsync: this,
      ),
    );

    _itemAnimations =
        _itemControllers.map((controller) {
          return Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: controller, curve: Curves.elasticOut),
          );
        }).toList();

    _animationController.forward();

    // Stagger item animations
    for (int i = 0; i < _itemControllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 100), () {
        if (mounted) {
          _itemControllers[i].forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    for (var controller in _itemControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  bool _isSelected(String value) {
    if (widget.allowMultipleSelection) {
      return widget.selectedValues?.contains(value) ?? false;
    } else {
      return widget.selectedValue == value;
    }
  }

  void _onTap(String value) {
    if (widget.allowMultipleSelection) {
      final currentValues = List<String>.from(widget.selectedValues ?? []);
      if (currentValues.contains(value)) {
        currentValues.remove(value);
      } else {
        currentValues.add(value);
      }
      widget.onMultipleChanged?.call(currentValues);
    } else {
      widget.onChanged(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sectionSpacing = AppDesignSystem.getResponsiveSpacingExact(
      context,
      xs: 8,
      sm: 12,
      md: 16,
    );
    final gridSpacing = AppDesignSystem.getResponsiveSpacingExact(
      context,
      xs: 8,
      sm: 10,
      md: 12,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title section
        Padding(
          padding: AppDesignSystem.getResponsivePaddingExact(
            context,
            xs: 8,
            sm: 10,
            md: 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: AppDesignSystem.getResponsiveFontSize(
                    context,
                    xs: 18,
                    sm: 20,
                    md: 22,
                  ),
                  fontWeight: FontWeight.bold,
                  color: widget.primaryColor,
                ),
              ),
              if (widget.subtitle != null) ...[
                SizedBox(
                  height: AppDesignSystem.getResponsiveSpacingExact(
                    context,
                    xs: 2,
                    sm: 3,
                    md: 4,
                  ),
                ),
                Text(
                  widget.subtitle!,
                  style: TextStyle(
                    fontSize: AppDesignSystem.getResponsiveFontSize(
                      context,
                      xs: 12,
                      sm: 14,
                      md: 16,
                    ),
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ],
          ),
        ),

        SizedBox(height: sectionSpacing),

        // Emoji grid - more compact
        Padding(
          padding: AppDesignSystem.getResponsivePaddingExact(
            context,
            xs: 8,
            sm: 12,
            md: 16,
          ),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: widget.options.length > 4 ? 3 : 2,
              crossAxisSpacing: gridSpacing,
              mainAxisSpacing: gridSpacing,
              childAspectRatio: 1.1,
            ),
            itemCount: widget.options.length,
            itemBuilder: (context, index) {
              final option = widget.options[index];
              final isSelected = _isSelected(option.value);

              return AnimatedBuilder(
                animation: _itemAnimations[index],
                builder: (context, child) {
                  return Transform.scale(
                    scale: _itemAnimations[index].value,
                    child: EmojiOptionCard(
                      option: option,
                      isSelected: isSelected,
                      onTap: () => _onTap(option.value),
                      primaryColor: widget.primaryColor,
                    ),
                  );
                },
              );
            },
          ),
        ),

        // Selected description
        if (widget.selectedValue != null && !widget.allowMultipleSelection) ...[
          SizedBox(height: sectionSpacing),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _buildSelectedDescription(context),
          ),
        ],

        if (widget.allowMultipleSelection &&
            (widget.selectedValues?.isNotEmpty ?? false)) ...[
          SizedBox(height: sectionSpacing),
          _buildMultipleSelectionSummary(context),
        ],
      ],
    );
  }

  Widget _buildSelectedDescription(BuildContext context) {
    final isSmallScreen = AppDesignSystem.getScreenHeight(context) < 700;
    final selectedOption = widget.options.firstWhere(
      (option) => option.value == widget.selectedValue,
      orElse: () => widget.options.first,
    );

    return Container(
      key: ValueKey(selectedOption.value),
      margin: AppDesignSystem.getResponsivePaddingExact(
        context,
        xs: 8,
        sm: 10,
        md: 16,
      ),
      padding: AppDesignSystem.getResponsivePaddingExact(
        context,
        xs: 12,
        sm: 14,
        md: 16,
      ),
      decoration: BoxDecoration(
        color: widget.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.primaryColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Text(
            selectedOption.emoji,
            style: TextStyle(
              fontSize: AppDesignSystem.getResponsiveFontSize(
                context,
                xs: 20,
                sm: 22,
                md: 24,
              ),
            ),
          ),
          SizedBox(
            width: AppDesignSystem.getResponsiveSpacingExact(
              context,
              xs: 8,
              sm: 10,
              md: 12,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedOption.label,
                  style: TextStyle(
                    fontSize: AppDesignSystem.getResponsiveFontSize(
                      context,
                      xs: 14,
                      sm: 15,
                      md: 16,
                    ),
                    fontWeight: FontWeight.bold,
                    color: widget.primaryColor,
                  ),
                ),
                SizedBox(
                  height: AppDesignSystem.getResponsiveSpacingExact(
                    context,
                    xs: 2,
                    sm: 3,
                    md: 4,
                  ),
                ),
                Text(
                  selectedOption.description,
                  style: TextStyle(
                    fontSize: AppDesignSystem.getResponsiveFontSize(
                      context,
                      xs: 12,
                      sm: 13,
                      md: 14,
                    ),
                    color: Colors.grey[700],
                  ),
                  maxLines: isSmallScreen ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultipleSelectionSummary(BuildContext context) {
    final selectedOptions = widget.options
        .where((option) => widget.selectedValues?.contains(option.value) ?? false)
        .toList();

    if (selectedOptions.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: AppDesignSystem.getResponsivePaddingExact(
        context,
        xs: 8,
        sm: 10,
        md: 16,
      ),
      padding: AppDesignSystem.getResponsivePaddingExact(
        context,
        xs: 12,
        sm: 14,
        md: 16,
      ),
      decoration: BoxDecoration(
        color: widget.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.primaryColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selected: ${selectedOptions.length} item${selectedOptions.length != 1 ? 's' : ''}',
            style: TextStyle(
              fontSize: AppDesignSystem.getResponsiveFontSize(
                context,
                xs: 14,
                sm: 15,
                md: 16,
              ),
              fontWeight: FontWeight.bold,
              color: widget.primaryColor,
            ),
          ),
          SizedBox(
            height: AppDesignSystem.getResponsiveSpacingExact(
              context,
              xs: 6,
              sm: 6,
              md: 8,
            ),
          ),
          Wrap(
            spacing: AppDesignSystem.getResponsiveSpacingExact(
              context,
              xs: 6,
              sm: 6,
              md: 8,
            ),
            runSpacing: AppDesignSystem.getResponsiveSpacingExact(
              context,
              xs: 4,
              sm: 4,
              md: 6,
            ),
            children: selectedOptions.map((option) {
              return Chip(
                avatar: Text(
                  option.emoji,
                  style: TextStyle(
                    fontSize: AppDesignSystem.getResponsiveFontSize(
                      context,
                      xs: 12,
                      sm: 13,
                      md: 14,
                    ),
                  ),
                ),
                label: Text(
                  option.label,
                  style: TextStyle(
                    fontSize: AppDesignSystem.getResponsiveFontSize(
                      context,
                      xs: 11,
                      sm: 12,
                      md: 12,
                    ),
                  ),
                ),
                backgroundColor: widget.primaryColor.withValues(alpha: 0.1),
                side: BorderSide(
                  color: widget.primaryColor.withValues(alpha: 0.3),
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class EmojiOptionCard extends StatefulWidget {
  final EmojiOption option;
  final bool isSelected;
  final VoidCallback onTap;
  final Color primaryColor;

  const EmojiOptionCard({
    super.key,
    required this.option,
    required this.isSelected,
    required this.onTap,
    required this.primaryColor,
  });

  @override
  State<EmojiOptionCard> createState() => _EmojiOptionCardState();
}

class _EmojiOptionCardState extends State<EmojiOptionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _tapController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _tapController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _tapController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _tapController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _tapController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _tapController.reverse();
    widget.onTap();
  }

  void _onTapCancel() {
    _tapController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final padding = AppDesignSystem.getResponsiveSpacingExact(
      context,
      xs: 6,
      sm: 8,
      md: 12,
    );
    final emojiContainerSize = AppDesignSystem.getResponsiveSpacingExact(
      context,
      xs: 36,
      sm: 44,
      md: 50,
    );
    final emojiFontSize = AppDesignSystem.getResponsiveFontSize(
      context,
      xs: 18,
      sm: 22,
      md: 26,
    );
    final labelFontSize = AppDesignSystem.getResponsiveFontSize(
      context,
      xs: 10,
      sm: 12,
      md: 14,
    );

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: _onTapDown,
            onTapUp: _onTapUp,
            onTapCancel: _onTapCancel,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color:
                    widget.isSelected
                        ? widget.primaryColor.withValues(alpha: 0.15)
                        : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      widget.isSelected
                          ? widget.primaryColor
                          : Colors.grey[300]!,
                  width: widget.isSelected ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        widget.isSelected
                            ? widget.primaryColor.withValues(alpha: 0.3)
                            : Colors.grey.withValues(alpha: 0.1),
                    blurRadius: widget.isSelected ? 6 : 3,
                    offset: const Offset(0, 2),
                    spreadRadius: widget.isSelected ? 1 : 0,
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(padding),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: emojiContainerSize,
                        height: emojiContainerSize,
                        decoration: BoxDecoration(
                          color:
                              widget.isSelected
                                  ? widget.primaryColor.withValues(alpha: 0.1)
                                  : Colors.grey[100],
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            widget.option.emoji,
                            style: TextStyle(
                              fontSize:
                                  widget.isSelected
                                      ? emojiFontSize + 2
                                      : emojiFontSize,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: AppDesignSystem.getResponsiveSpacingExact(
                        context,
                        xs: 2,
                        sm: 4,
                        md: 6,
                      ),
                    ),
                    Text(
                      widget.option.label,
                      style: TextStyle(
                        fontSize: labelFontSize,
                        fontWeight:
                            widget.isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                        color:
                            widget.isSelected
                                ? widget.primaryColor
                                : Colors.grey[800],
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.isSelected) ...[
                      SizedBox(
                        height: AppDesignSystem.getResponsiveSpacingExact(
                          context,
                          xs: 1,
                          sm: 2,
                          md: 4,
                        ),
                      ),
                      Container(
                        width: AppDesignSystem.getResponsiveSpacingExact(
                          context,
                          xs: 3,
                          sm: 4,
                          md: 6,
                        ),
                        height: AppDesignSystem.getResponsiveSpacingExact(
                          context,
                          xs: 3,
                          sm: 4,
                          md: 6,
                        ),
                        decoration: BoxDecoration(
                          color: widget.primaryColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Predefined emoji options for different categories
class EmojiOptions {
  static List<EmojiOption> getMoodOptions() {
    return [
      EmojiOption(
        emoji: '😊',
        label: 'Happy',
        value: 'happy',
        description:
            'Feeling great and energetic! Perfect for maintaining healthy habits.',
        color: Colors.yellow,
      ),
      EmojiOption(
        emoji: '😌',
        label: 'Calm',
        value: 'calm',
        description:
            'Peaceful and balanced. Great for mindful eating and portion control.',
        color: Colors.blue,
      ),
      EmojiOption(
        emoji: '😴',
        label: 'Tired',
        value: 'tired',
        description:
            'Low energy today. We\'ll suggest easy, nourishing meal options.',
        color: Colors.purple,
      ),
      EmojiOption(
        emoji: '😤',
        label: 'Stressed',
        value: 'stressed',
        description:
            'Feeling overwhelmed. Let\'s focus on stress-reducing nutrition.',
        color: Colors.red,
      ),
      EmojiOption(
        emoji: '🤔',
        label: 'Neutral',
        value: 'neutral',
        description:
            'Just another day. We\'ll keep your nutrition consistent and balanced.',
        color: Colors.grey,
      ),
      EmojiOption(
        emoji: '🥳',
        label: 'Excited',
        value: 'excited',
        description:
            'High energy and motivated! Perfect for trying new healthy recipes.',
        color: Colors.orange,
      ),
    ];
  }

  static List<EmojiOption> getEnergyOptions() {
    return [
      EmojiOption(
        emoji: '⚡',
        label: 'High Energy',
        value: 'high',
        description: 'Feeling energized and ready to take on the day!',
        color: Colors.yellow,
      ),
      EmojiOption(
        emoji: '🔋',
        label: 'Good Energy',
        value: 'good',
        description: 'Steady energy levels, feeling balanced and focused.',
        color: Colors.green,
      ),
      EmojiOption(
        emoji: '🪫',
        label: 'Low Energy',
        value: 'low',
        description:
            'Feeling a bit drained. We\'ll suggest energy-boosting foods.',
        color: Colors.orange,
      ),
      EmojiOption(
        emoji: '😴',
        label: 'Very Tired',
        value: 'very_low',
        description:
            'Exhausted and need a pick-me-up. Let\'s focus on recovery nutrition.',
        color: Colors.red,
      ),
    ];
  }

  static List<EmojiOption> getActivityOptions() {
    return [
      EmojiOption(
        emoji: '🏃‍♀️',
        label: 'Very Active',
        value: 'very_active',
        description: 'Regular intense exercise or physically demanding job.',
        color: Colors.red,
      ),
      EmojiOption(
        emoji: '🚴‍♂️',
        label: 'Active',
        value: 'active',
        description:
            'Exercise 3-4 times per week or moderately active lifestyle.',
        color: Colors.orange,
      ),
      EmojiOption(
        emoji: '🚶‍♀️',
        label: 'Light Activity',
        value: 'light',
        description: 'Some walking or light exercise 1-2 times per week.',
        color: Colors.blue,
      ),
      EmojiOption(
        emoji: '🛋️',
        label: 'Sedentary',
        value: 'sedentary',
        description: 'Mostly sitting or desk work with minimal exercise.',
        color: Colors.grey,
      ),
    ];
  }

  static List<EmojiOption> getFoodPreferenceOptions() {
    return [
      EmojiOption(
        emoji: '🥗',
        label: 'Healthy',
        value: 'healthy',
        description: 'Love fresh, nutritious foods and balanced meals.',
        color: Colors.green,
      ),
      EmojiOption(
        emoji: '🍕',
        label: 'Comfort Food',
        value: 'comfort',
        description: 'Enjoy hearty, satisfying meals that feel like home.',
        color: Colors.orange,
      ),
      EmojiOption(
        emoji: '🌶️',
        label: 'Spicy',
        value: 'spicy',
        description: 'Love bold flavors and spicy cuisine.',
        color: Colors.red,
      ),
      EmojiOption(
        emoji: '🍰',
        label: 'Sweet Tooth',
        value: 'sweet',
        description: 'Have a preference for sweet flavors and desserts.',
        color: Colors.pink,
      ),
      EmojiOption(
        emoji: '🥩',
        label: 'Protein Lover',
        value: 'protein',
        description: 'Prefer meals with substantial protein content.',
        color: Colors.brown,
      ),
      EmojiOption(
        emoji: '🥕',
        label: 'Plant-Based',
        value: 'plant_based',
        description: 'Focus on vegetables, fruits, and plant-based options.',
        color: Colors.green,
      ),
    ];
  }

  static List<EmojiOption> getCookingSkillOptions() {
    return [
      EmojiOption(
        emoji: '👨‍🍳',
        label: 'Expert Chef',
        value: 'expert',
        description:
            'Love cooking complex recipes and experimenting with new techniques.',
        color: Colors.purple,
      ),
      EmojiOption(
        emoji: '🍳',
        label: 'Good Cook',
        value: 'good',
        description:
            'Comfortable with most recipes and enjoy cooking regularly.',
        color: Colors.blue,
      ),
      EmojiOption(
        emoji: '🥪',
        label: 'Basic Skills',
        value: 'basic',
        description: 'Can handle simple recipes and basic meal preparation.',
        color: Colors.orange,
      ),
      EmojiOption(
        emoji: '🍜',
        label: 'Beginner',
        value: 'beginner',
        description:
            'Prefer simple, quick meals with minimal cooking required.',
        color: Colors.green,
      ),
    ];
  }
}

