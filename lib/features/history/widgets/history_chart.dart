import 'package:flutter/material.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/simple_bar_chart.dart';

/// Day-bucketed usage summary. There is currently no firmware/cloud topic
/// that publishes historical daily totals, so [entries] is empty until
/// that exists — this renders an honest empty state rather than a chart
/// built from invented numbers.
class HistoryChart extends StatelessWidget {
  const HistoryChart({required this.title, required this.entries, super.key});

  final String title;
  final List<BarChartEntry> entries;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: title,
      child: entries.isEmpty
          ? const EmptyState(
              icon: Icons.bar_chart_outlined,
              title: 'No Historical Data Yet',
              message:
                  'Daily summaries will appear once the system reports historical usage.',
            )
          : SimpleBarChart(entries: entries),
    );
  }
}
