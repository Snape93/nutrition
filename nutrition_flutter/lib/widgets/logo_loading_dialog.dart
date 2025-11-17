import 'package:flutter/material.dart';

import 'animated_logo_widget.dart';

class LogoLoadingFullScreen extends StatelessWidget {
  final bool dimBackground;

  const LogoLoadingFullScreen({
    super.key,
    this.dimBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor =
        dimBackground ? Colors.white.withValues(alpha: 0.9) : const Color(0xFFF6FFF7);

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: backgroundColor,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          AnimatedLogoWidget(
            size: 140,
          ),
          SizedBox(height: 24),
          Text(
            'Nutritionist App',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF388E3C),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class LogoLoadingOverlayController {
  LogoLoadingOverlayController._(
    this._context,
    this._minDisplayDuration,
    this._dimBackground,
  );

  final BuildContext _context;
  final Duration _minDisplayDuration;
  final bool _dimBackground;
  OverlayEntry? _overlayEntry;
  DateTime? _shownAt;

  static const Duration defaultDuration = Duration(milliseconds: 350);

  static LogoLoadingOverlayController show(
    BuildContext context, {
    Duration minDisplayDuration = defaultDuration,
    bool dimBackground = false,
  }) {
    final controller = LogoLoadingOverlayController._(
      context,
      minDisplayDuration,
      dimBackground,
    );
    controller._showOverlay();
    return controller;
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;
    final overlay = Overlay.of(_context, rootOverlay: true);

    _shownAt = DateTime.now();
    _overlayEntry = OverlayEntry(
      builder: (_) => LogoLoadingFullScreen(dimBackground: _dimBackground),
    );
    overlay.insert(_overlayEntry!);
  }

  Future<void> hide() async {
    if (_overlayEntry == null) return;
    final elapsed = DateTime.now().difference(_shownAt ?? DateTime.now());
    if (elapsed < _minDisplayDuration) {
      await Future.delayed(_minDisplayDuration - elapsed);
    }
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}

