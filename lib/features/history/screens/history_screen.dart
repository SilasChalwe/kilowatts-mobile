import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/responsive_content.dart';
import '../../../core/widgets/trend_chart_card.dart';
import '../../alerts/models/alert_model.dart';
import '../../alerts/widgets/alert_card.dart';

/// Session reports only. The current firmware does not expose historical
/// backfill, so this screen never pretends that older data exists.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, this.embedded = false});

  final bool embedded;

  Widget _usage(BuildContext context) {
    final appState = AppStateScope.of(context);
    return ValueListenableBuilder<List<double>>(
      valueListenable: appState.socSamples,
      builder: (context, socSamples, _) {
        return ValueListenableBuilder<List<double>>(
          valueListenable: appState.activeLoadPowerSamples,
          builder: (context, powerSamples, _) {
            return ListView(
              children: [
                ResponsiveContent(
                  child: ResponsiveCardGrid(
                    minCardWidth: 420,
                    maxColumns: 2,
                    children: [
                      TrendChartCard(
                        title: 'Battery state of charge',
                        values: socSamples,
                        caption: 'State of charge (%) · this session',
                      ),
                      TrendChartCard(
                        title: 'Active load power',
                        values: powerSamples,
                        caption: 'Fixed ON + selected automatic load power (W)',
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _events(BuildContext context) {
    final appState = AppStateScope.of(context);
    return ValueListenableBuilder<List<AlertModel>>(
      valueListenable: appState.alerts,
      builder: (context, events, _) {
        if (events.isEmpty) {
          return const EmptyState(
            icon: Icons.event_note_outlined,
            title: 'No events this session',
          );
        }

        return ListView(
          children: [
            ResponsiveContent(
              maxWidth: 980,
              child: Column(
                children: [
                  for (var index = 0; index < events.length; index++) ...[
                    AlertCard(alert: events[index]),
                    if (index != events.length - 1)
                      const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _tabs(BuildContext context) {
    return TabBarView(children: [_usage(context), _events(context)]);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: embedded
          ? Material(
              color: Colors.transparent,
              child: SafeArea(
                child: Column(
                  children: [
                    ResponsiveContent(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.pageDesktop,
                        AppSpacing.lg,
                        AppSpacing.pageDesktop,
                        0,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: const SizedBox(
                            width: 280,
                            child: TabBar(
                              dividerColor: Colors.transparent,
                              indicatorSize: TabBarIndicatorSize.tab,
                              tabs: [
                                Tab(text: 'Usage'),
                                Tab(text: 'Events'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Expanded(child: _tabs(context)),
                  ],
                ),
              ),
            )
          : Scaffold(
              appBar: AppBar(
                title: const Text('Reports'),
                bottom: const TabBar(
                  tabs: [Tab(text: 'Usage'), Tab(text: 'Events')],
                ),
              ),
              body: SafeArea(child: _tabs(context)),
            ),
    );
  }
}
