import 'package:flutter/material.dart';

import 'animated_logo_widget.dart';

class LogoLoadingFullScreen extends StatelessWidget {
  final bool dimBackground;
  final String? statusMessage;

  const LogoLoadingFullScreen({
    super.key,
    this.dimBackground = false,
    this.statusMessage,
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
        children: [
          const AnimatedLogoWidget(
            size: 120, // slightly smaller logo for a more balanced look
          ),
          const SizedBox(height: 16),
          const Text(
            'Nutritionist App',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.15, // subtle system-like spacing
              height: 1.3,
              color: Color(0xFF388E3C),
              decoration: TextDecoration.none,
            ),
          ),
          if (statusMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              statusMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF4E4E4E),
                decoration: TextDecoration.none,
              ),
            ),
          ],
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
    this._statusMessage,
  );

  final BuildContext _context;
  final Duration _minDisplayDuration;
  final bool _dimBackground;
  final String? _statusMessage;
  OverlayEntry? _overlayEntry;
  DateTime? _shownAt;

  static const Duration defaultDuration = Duration(milliseconds: 350);

  static LogoLoadingOverlayController show(
    BuildContext context, {
    Duration minDisplayDuration = defaultDuration,
    bool dimBackground = false,
    String? statusMessage,
  }) {
    final controller = LogoLoadingOverlayController._(
      context,
      minDisplayDuration,
      dimBackground,
      statusMessage,
    );
    controller._showOverlay();
    return controller;
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;
    final overlay = Overlay.of(_context, rootOverlay: true);

    _shownAt = DateTime.now();
    _overlayEntry = OverlayEntry(
      builder: (_) => LogoLoadingFullScreen(
        dimBackground: _dimBackground,
        statusMessage: _statusMessage,
      ),
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

