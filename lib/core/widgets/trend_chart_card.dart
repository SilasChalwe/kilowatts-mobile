import 'package:flutter/material.dart';

import '../models/telemetry_point.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'section_card.dart';
import 'telemetry_line_chart.dart';

class TrendChartCard extends StatelessWidget {
  const TrendChartCard({
    required this.title,
    required this.points,
    required this.unit,
    super.key,
    this.caption,
    this.minimumY,
    this.maximumY,
    this.emptyTitle = 'Waiting for readings',
  });

  final String title;
  final List<TelemetryPoint> points;
  final String unit;
  final String? caption;
  final double? minimumY;
  final double? maximumY;
  final String emptyTitle;

  @override
  Widget build(BuildContext context) {
    final ordered = [...points]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final latest = ordered.isEmpty ? null : ordered.last;

    return SectionCard(
      title: title,
      trailing: latest == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatLatest(latest.value),
                  style: AppTextStyles.sectionTitle,
                ),
                Text('Latest', style: AppTextStyles.caption),
              ],
            ),
      child: ordered.length < 2
          ? Container(
              width: double.infinity,
              height: 136,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.monitor_heart_outlined,
                    color: AppColors.textTertiary,
                    size: 24,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(emptyTitle, style: AppTextStyles.label),
                  const SizedBox(height: 2),
                  Text(
                    ordered.isEmpty
                        ? 'History will appear after telemetry is received.'
                        : 'One reading stored · waiting for the next sample.',
                    style: AppTextStyles.caption,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TelemetryLineChart(
                  points: ordered,
                  unit: unit,
                  minimumY: minimumY,
                  maximumY: maximumY,
                ),
                if (caption != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(caption!, style: AppTextStyles.caption),
                ],
              ],
            ),
    );
  }

  String _formatLatest(double value) {
    final abs = value.abs();
    final decimals = abs >= 100 ? 0 : abs >= 10 ? 1 : 2;
    final text = value.toStringAsFixed(decimals);
    return unit.isEmpty ? text : '$text $unit';
  }
}
