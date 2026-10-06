import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Keeps tablet pages readable while phones use device-appropriate padding.
class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent({
    required this.child,
    super.key,
    this.maxWidth = AppBreakpoints.contentMaxWidth,
    this.padding,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = width >= AppBreakpoints.desktop
        ? AppSpacing.pageDesktop
        : width >= 600
        ? AppSpacing.pageTablet
        : AppSpacing.pageMobile;

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding:
              padding ??
              EdgeInsets.fromLTRB(
                horizontal,
                AppSpacing.lg,
                horizontal,
                AppSpacing.xl,
              ),
          child: child,
        ),
      ),
    );
  }
}

/// A responsive fixed-column grid that preserves a useful minimum card width.
/// It is intentionally implemented with Wrap so cards size to their content
/// vertically rather than being forced into arbitrary grid aspect ratios.
class ResponsiveCardGrid extends StatelessWidget {
  const ResponsiveCardGrid({
    required this.children,
    super.key,
    this.minCardWidth = 320,
    this.maxColumns = 3,
    this.gap = AppSpacing.md,
  });

  final List<Widget> children;
  final double minCardWidth;
  final int maxColumns;
  final double gap;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        var columns = ((constraints.maxWidth + gap) / (minCardWidth + gap))
            .floor();
        if (columns < 1) columns = 1;
        if (columns > maxColumns) columns = maxColumns;

        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          crossAxisAlignment: WrapCrossAlignment.start,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}
