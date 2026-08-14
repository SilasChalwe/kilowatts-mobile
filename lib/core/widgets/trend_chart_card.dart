import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'empty_state.dart';
import 'section_card.dart';
import 'sparkline_chart.dart';

/// A titled card wrapping [SparklineChart], with an honest empty state
/// instead of a placeholder chart when there isn't yet enough data to
/// draw a trend.
class TrendChartCard extends StatelessWidget {
  const TrendChartCard({
    required this.title,
    required this.values,
    super.key,
    this.caption,
    this.emptyTitle = 'Collecting Data',
    this.emptyMessage = 'The trend will appear once more readings arrive.',
  });

  final String title;
  final List<double> values;
  final String? caption;
  final String emptyTitle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: title,
      child: values.length < 2
          ? EmptyState(
              icon: Icons.show_chart_rounded,
              title: emptyTitle,
              message: emptyMessage,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SparklineChart(values: values),
                if (caption != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(caption!, style: AppTextStyles.caption),
                ],
              ],
            ),
    );
  }
}
