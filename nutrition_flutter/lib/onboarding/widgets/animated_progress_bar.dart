import 'package:flutter/material.dart';

class AnimatedProgressBar extends StatefulWidget {
  final int currentStep;
  final int totalSteps;
  final List<String> stepNames;
  final Color primaryColor;
  final bool showCelebration;
  final VoidCallback? onCelebrationComplete;

  const AnimatedProgressBar({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.stepNames,
    required this.primaryColor,
    this.showCelebration = false,
    this.onCelebrationComplete,
  });

  @override
  State<AnimatedProgressBar> createState() => _AnimatedProgressBarState();
}

class _AnimatedProgressBarState extends State<AnimatedProgressBar>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _celebrationController;
  late Animation<double> _progressAnimation;
  late Animation<double> _celebrationAnimation;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();

    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _celebrationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: widget.currentStep / widget.totalSteps,
    ).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeOutCubic),
    );

    _celebrationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _celebrationController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _bounceAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _celebrationController,
        curve: const Interval(0.0, 0.3, curve: Curves.elasticOut),
      ),
    );

    _progressController.forward();

    if (widget.showCelebration) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _celebrationController.forward().then((_) {
          widget.onCelebrationComplete?.call();
        });
      });
    }
  }

  @override
  void didUpdateWidget(AnimatedProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentStep != widget.currentStep) {
      _progressAnimation = Tween<double>(
        begin: oldWidget.currentStep / widget.totalSteps,
        end: widget.currentStep / widget.totalSteps,
      ).animate(
        CurvedAnimation(
          parent: _progressController,
          curve: Curves.easeOutCubic,
        ),
      );
      _progressController.reset();
      _progressController.forward();
    }

    if (widget.showCelebration && !oldWidget.showCelebration) {
      _celebrationController.reset();
      Future.delayed(const Duration(milliseconds: 500), () {
        _celebrationController.forward().then((_) {
          widget.onCelebrationComplete?.call();
        });
      });
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    _celebrationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Step indicator and percentage
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AnimatedBuilder(
                animation: _bounceAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale:
                        widget.showCelebration
                            ? _bounceAnimation.value.clamp(0.0, 1.0)
                            : 1.0,
                    child: Text(
                      'Step ${widget.currentStep} of ${widget.totalSteps}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  );
                },
              ),
              AnimatedBuilder(
                animation: _progressAnimation,
                builder: (context, child) {
                  return AnimatedBuilder(
                    animation: _bounceAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale:
                            widget.showCelebration
                                ? _bounceAnimation.value.clamp(0.0, 1.0)
                                : 1.0,
                        child: Text(
                          '${(_progressAnimation.value.clamp(0.0, 1.0) * 100).toInt()}% Complete',
                          style: TextStyle(
                            color: widget.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress bar
          Stack(
            children: [
              // Background bar
              Container(
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(6),
                ),
              ),

              // Progress bar
              AnimatedBuilder(
                animation: _progressAnimation,
                builder: (context, child) {
                  return Container(
                    height: 12,
                    width:
                        MediaQuery.of(context).size.width *
                        (_progressAnimation.value.clamp(0.0, 1.0) *
                            0.85), // Account for padding
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          widget.primaryColor,
                          widget.primaryColor.withValues(alpha: 0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: widget.primaryColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // Step indicators
              Positioned.fill(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(widget.totalSteps, (index) {
                    final isCompleted = index < widget.currentStep;
                    final isCurrent = index == widget.currentStep - 1;

                    return AnimatedBuilder(
                      animation: _celebrationAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale:
                              (isCurrent && widget.showCelebration)
                                  ? 1.0 +
                                      (_celebrationAnimation.value.clamp(
                                            0.0,
                                            1.0,
                                          ) *
                                          0.5)
                                  : 1.0,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color:
                                  isCompleted || isCurrent
                                      ? widget.primaryColor
                                      : Colors.grey[300],
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                if (isCompleted || isCurrent)
                                  BoxShadow(
                                    color: widget.primaryColor.withValues(
                                      alpha: 0.4,
                                    ),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                              ],
                            ),
                            child: Center(
                              child:
                                  isCompleted
                                      ? Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 12,
                                      )
                                      : isCurrent
                                      ? Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                      )
                                      : null,
                            ),
                          ),
                        );
                      },
                    );
                  }),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Current step name
          if (widget.currentStep <= widget.stepNames.length)
            AnimatedBuilder(
              animation: _bounceAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale:
                      widget.showCelebration
                          ? _bounceAnimation.value.clamp(0.0, 1.0)
                          : 1.0,
                  child: Text(
                    widget.stepNames[widget.currentStep - 1],
                    style: TextStyle(
                      color: widget.primaryColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

// Celebration overlay widget
class CelebrationOverlay extends StatefulWidget {
  final bool show;
  final Color color;
  final VoidCallback? onComplete;

  const CelebrationOverlay({
    super.key,
    required this.show,
    required this.color,
    this.onComplete,
  });

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late List<AnimationController> _starControllers;
  late List<Animation<Offset>> _starAnimations;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Create multiple star animations
    _starControllers = List.generate(6, (index) {
      return AnimationController(
        duration: Duration(milliseconds: 1000 + (index * 100)),
        vsync: this,
      );
    });

    _starAnimations =
        _starControllers.asMap().entries.map((entry) {
          final index = entry.key;
          final controller = entry.value;

          // Different start and end positions for each star
          final startX = -0.2 + (index * 0.08);
          final endX = startX + 0.4;
          final startY = 0.3;
          final endY = -0.5;

          return Tween<Offset>(
            begin: Offset(startX, startY),
            end: Offset(endX, endY),
          ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOut));
        }).toList();

    if (widget.show) {
      _startAnimation();
    }
  }

  void _startAnimation() {
    _controller.forward();

    // Stagger star animations
    for (int i = 0; i < _starControllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 100), () {
        if (mounted) {
          _starControllers[i].forward().then((_) {
            if (i == _starControllers.length - 1) {
              widget.onComplete?.call();
            }
          });
        }
      });
    }
  }

  @override
  void didUpdateWidget(CelebrationOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.show && !oldWidget.show) {
      _controller.reset();
      for (var controller in _starControllers) {
        controller.reset();
      }
      _startAnimation();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    for (var controller in _starControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.show) return const SizedBox.shrink();

    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children:
              _starAnimations.asMap().entries.map((entry) {
                final index = entry.key;
                final animation = entry.value;

                return AnimatedBuilder(
                  animation: _starControllers[index],
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(
                        animation.value.dx * MediaQuery.of(context).size.width,
                        animation.value.dy * MediaQuery.of(context).size.height,
                      ),
                      child: Center(
                        child: Transform.scale(
                          scale: _starControllers[index].value,
                          child: Opacity(
                            opacity: 1.0 - _starControllers[index].value,
                            child: Icon(
                              index % 2 == 0 ? Icons.star : Icons.star_border,
                              color: widget.color,
                              size: 30 + (index * 5),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
        ),
      ),
    );
  }
}
