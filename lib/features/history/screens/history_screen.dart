import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/models/telemetry_point.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/responsive_content.dart';
import '../../../core/widgets/trend_chart_card.dart';

enum _HistoryRange {
  oneHour('1h', Duration(hours: 1)),
  sixHours('6h', Duration(hours: 6)),
  oneDay('24h', Duration(hours: 24)),
  sevenDays('7d', Duration(days: 7));

  const _HistoryRange(this.label, this.duration);

  final String label;
  final Duration duration;
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  _HistoryRange _range = _HistoryRange.oneDay;

  List<TelemetryPoint> _withinRange(List<TelemetryPoint> points) {
    final cutoff = DateTime.now().subtract(_range.duration);
    return points
        .where((point) => !point.timestamp.isBefore(cutoff))
        .toList(growable: false);
  }

  Widget _rangeSelector() {
    return SegmentedButton<_HistoryRange>(
      segments: [
        for (final range in _HistoryRange.values)
          ButtonSegment<_HistoryRange>(value: range, label: Text(range.label)),
      ],
      selected: {_range},
      showSelectedIcon: false,
      onSelectionChanged: (selection) {
        if (selection.isEmpty) return;
        setState(() => _range = selection.first);
      },
    );
  }

  Widget _content(BuildContext context) {
    final appState = AppStateScope.of(context);

    return AnimatedBuilder(
      animation: Listenable.merge([
        appState.socHistory,
        appState.activeLoadPowerHistory,
      ]),
      builder: (context, _) {
        final soc = _withinRange(appState.socHistory.value);
        final activePower = _withinRange(appState.activeLoadPowerHistory.value);

        return SingleChildScrollView(
          child: ResponsiveContent(
            maxWidth: 1280,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _rangeSelector(),
                    Text('Rolling 7-day history', style: AppTextStyles.caption),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                ResponsiveCardGrid(
                  minCardWidth: 300,
                  maxColumns: 2,
                  children: [
                    TrendChartCard(
                      title: 'Battery state of charge',
                      points: soc,
                      unit: '%',
                      minimumY: 0,
                      maximumY: 100,
                    ),
                    TrendChartCard(
                      title: 'Active load power',
                      points: activePower,
                      unit: 'W',
                      minimumY: 0,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = SafeArea(child: _content(context));
    if (widget.embedded) {
      return Material(color: Colors.transparent, child: body);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: body,
    );
  }
}
