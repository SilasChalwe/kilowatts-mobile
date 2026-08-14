import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/trend_chart_card.dart';
import '../../alerts/models/alert_model.dart';
import '../../alerts/widgets/alert_card.dart';
import '../widgets/history_chart.dart';

/// Everything here is built from samples/events accumulated centrally in
/// [AppState] during this app session — there is no historical reporting
/// API yet, so nothing is backfilled or invented.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('History / Reports'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Usage'),
              Tab(text: 'Events'),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              ValueListenableBuilder<List<double>>(
                valueListenable: appState.socSamples,
                builder: (context, socSamples, _) {
                  return ValueListenableBuilder<List<double>>(
                    valueListenable: appState.committedPowerSamples,
                    builder: (context, powerSamples, _) {
                      return ListView(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        children: [
                          TrendChartCard(
                            title: 'Battery SoC Trend',
                            values: socSamples,
                            caption: 'State of charge (%), this session',
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TrendChartCard(
                            title: 'Power Usage Trend',
                            values: powerSamples,
                            caption: 'Committed power (W), this session',
                          ),
                          const SizedBox(height: AppSpacing.md),
                          const HistoryChart(
                            title: 'Daily Energy Summary',
                            entries: [],
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
              ValueListenableBuilder<List<AlertModel>>(
                valueListenable: appState.alerts,
                builder: (context, events, _) {
                  return events.isEmpty
                      ? const EmptyState(
                          icon: Icons.event_note_outlined,
                          title: 'No Events Yet',
                          message:
                              'System events will appear here as they happen.',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          itemCount: events.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, index) =>
                              AlertCard(alert: events[index]),
                        );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
