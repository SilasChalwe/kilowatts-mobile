import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

enum AppToastTone { success, error, info }

/// A brief, self-dismissing card notification — used instead of [SnackBar]
/// for one-off feedback (e.g. "Signed in", "MQTT settings saved").
abstract final class AppToast {
  static void show(
    BuildContext context, {
    required String message,
    AppToastTone tone = AppToastTone.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    late OverlayEntry entry;
    final removed = _Once();
    void remove() {
      if (removed.trigger()) entry.remove();
    }

    entry = OverlayEntry(
      builder: (context) => _ToastCard(
        message: message,
        tone: tone,
        duration: duration,
        onDismissed: remove,
      ),
    );
    overlay.insert(entry);
  }
}

class _Once {
  bool _done = false;
  bool trigger() {
    if (_done) return false;
    _done = true;
    return true;
  }
}

class _ToastCard extends StatefulWidget {
  const _ToastCard({
    required this.message,
    required this.tone,
    required this.duration,
    required this.onDismissed,
  });

  final String message;
  final AppToastTone tone;
  final Duration duration;
  final VoidCallback onDismissed;

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      reverseDuration: const Duration(milliseconds: 140),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _offset = Tween(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
    Future.delayed(widget.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    await _controller.reverse();
    widget.onDismissed();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  (Color, Color, IconData) get _style => switch (widget.tone) {
    AppToastTone.success => (
      AppColors.success,
      AppColors.successSoft,
      Icons.check_circle_outline_rounded,
    ),
    AppToastTone.error => (
      AppColors.error,
      AppColors.errorSoft,
      Icons.error_outline_rounded,
    ),
    AppToastTone.info => (
      AppColors.info,
      AppColors.infoSoft,
      Icons.info_outline_rounded,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final (foreground, background, icon) = _style;
    return Positioned(
      left: AppSpacing.md,
      right: AppSpacing.md,
      bottom: AppSpacing.xl,
      child: SafeArea(
        child: FadeTransition(
          opacity: _opacity,
          child: SlideTransition(
            position: _offset,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Material(
                color: background,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                elevation: 6,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 18, color: foreground),
                      const SizedBox(width: AppSpacing.xs),
                      Flexible(
                        child: Text(
                          widget.message,
                          style: AppTextStyles.label.copyWith(
                            color: foreground,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
