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
    this.chartHeight = 220,
  });

  final String title;
  final List<TelemetryPoint> points;
  final String unit;
  final String? caption;
  final double? minimumY;
  final double? maximumY;
  final String emptyTitle;
  final double chartHeight;

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
                  _formatValue(latest.value),
                  style: AppTextStyles.sectionTitle,
                ),
                Text('Latest', style: AppTextStyles.caption),
              ],
            ),
      child: ordered.length < 2
          ? Container(
              width: double.infinity,
              height: chartHeight < 160.0 ? 160.0 : chartHeight,
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
          : _chartBody(ordered),
    );
  }

  Widget _chartBody(List<TelemetryPoint> ordered) {
    final values = ordered.map((point) => point.value).toList(growable: false);
    final minimum = values.reduce((a, b) => a < b ? a : b);
    final maximum = values.reduce((a, b) => a > b ? a : b);
    final average = values.reduce((a, b) => a + b) / values.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TelemetryLineChart(
          points: ordered,
          unit: unit,
          height: chartHeight,
          minimumY: minimumY,
          maximumY: maximumY,
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Row(
            children: [
              Expanded(child: _stat('Min', minimum)),
              Expanded(child: _stat('Average', average)),
              Expanded(child: _stat('Max', maximum)),
            ],
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(caption!, style: AppTextStyles.caption),
        ],
      ],
    );
  }

  Widget _stat(String label, double value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppTextStyles.caption),
        const SizedBox(height: 2),
        Text(_formatValue(value), style: AppTextStyles.label),
      ],
    );
  }

  String _formatValue(double value) {
    final abs = value.abs();
    final decimals = abs >= 100 ? 0 : abs >= 10 ? 1 : 2;
    final text = value.toStringAsFixed(decimals);
    return unit.isEmpty ? text : '$text $unit';
  }
}
