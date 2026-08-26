import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/trend_chart_card.dart';
import '../../alerts/models/alert_model.dart';
import '../../alerts/widgets/alert_card.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, this.embedded = false});

  final bool embedded;

  Widget _usage(BuildContext context) {
    final appState = AppStateScope.of(context);
    return ValueListenableBuilder<List<double>>(
      valueListenable: appState.socSamples,
      builder: (context, socSamples, _) {
        return ValueListenableBuilder<List<double>>(
          valueListenable: appState.committedPowerSamples,
          builder: (context, powerSamples, _) {
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final twoColumns = constraints.maxWidth >= 900;
                    final gap = AppSpacing.md;
                    final width = twoColumns
                        ? (constraints.maxWidth - gap) / 2
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        SizedBox(
                          width: width,
                          child: TrendChartCard(
                            title: 'Battery SoC',
                            values: socSamples,
                            caption: 'State of charge (%) · this session',
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: TrendChartCard(
                            title: 'Committed power',
                            values: powerSamples,
                            caption: 'Power (W) · this session',
                          ),
                        ),
                      ],
                    );
                  },
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
            compact: true,
            icon: Icons.event_note_outlined,
            title: 'No events recorded',
            message:
                'Events received during this app session will appear here.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: events.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) => AlertCard(alert: events[index]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (embedded) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                0,
              ),
              child: PageHeader(
                title: 'History & reports',
                subtitle:
                    'Session trends and system events currently available to this device.',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: 'Usage'),
                Tab(text: 'Events'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [_usage(context), _events(context)],
            ),
          ),
        ],
      ),
    );

    if (embedded) {
      return Material(
        color: Colors.transparent,
        child: SafeArea(child: content),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('History & reports')),
      body: SafeArea(child: content),
    );
  }
}
