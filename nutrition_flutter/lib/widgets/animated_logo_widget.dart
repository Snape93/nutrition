import 'package:flutter/material.dart';

/// Widget that displays an animated logo with pulse animation
/// Used for loading screens and connectivity checks
class AnimatedLogoWidget extends StatefulWidget {
  final String logoPath;
  final double size;
  final Duration animationDuration;

  const AnimatedLogoWidget({
    super.key,
    this.logoPath = 'design/logo.png',
    this.size = 120,
    this.animationDuration = const Duration(milliseconds: 1500),
  });

  @override
  State<AnimatedLogoWidget> createState() => _AnimatedLogoWidgetState();
}

class _AnimatedLogoWidgetState extends State<AnimatedLogoWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    // Start animation and loop it
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Image.asset(
            widget.logoPath,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.contain,
          ),
        );
      },
    );
  }
}



