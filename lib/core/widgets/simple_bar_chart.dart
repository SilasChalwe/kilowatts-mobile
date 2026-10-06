import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

class BarChartEntry {
  const BarChartEntry({required this.label, required this.value});

  final String label;
  final double value;
}

/// A minimal vertical bar chart for daily/weekly usage summaries, matching
/// the History wireframe. No external charting package — the data shape is
/// simple enough for a small CustomPainter.
class SimpleBarChart extends StatelessWidget {
  const SimpleBarChart({
    required this.entries,
    super.key,
    this.height = 160,
    this.barColor = AppColors.primary,
  });

  final List<BarChartEntry> entries;
  final double height;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return SizedBox(height: height);
    }
    final maxValue = entries
        .map((e) => e.value)
        .reduce((a, b) => a > b ? a : b);
    final safeMax = maxValue <= 0 ? 1.0 : maxValue;

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final entry in entries)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: (entry.value / safeMax).clamp(
                            0.02,
                            1.0,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: barColor,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      entry.label,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
