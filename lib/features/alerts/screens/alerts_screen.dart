import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/responsive_content.dart';
import '../../../core/widgets/section_card.dart';
import '../models/alert_model.dart';
import '../widgets/alert_card.dart';

enum _AlertFilter { all, critical, warning, info }

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  _AlertFilter _filter = _AlertFilter.all;

  List<AlertModel> _apply(List<AlertModel> alerts) {
    switch (_filter) {
      case _AlertFilter.all:
        return alerts;
      case _AlertFilter.critical:
        return alerts.where((a) => a.severity == AlertSeverity.critical).toList();
      case _AlertFilter.warning:
        return alerts.where((a) => a.severity == AlertSeverity.warning).toList();
      case _AlertFilter.info:
        return alerts.where((a) => a.severity == AlertSeverity.info).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    return SafeArea(
      child: ValueListenableBuilder<List<AlertModel>>(
        valueListenable: appState.alerts,
        builder: (context, alerts, _) {
          final filtered = _apply(alerts);

          return ListView(
            children: [
              ResponsiveContent(
                maxWidth: 1100,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (alerts.isNotEmpty)
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: appState.acknowledgeAllAlerts,
                          icon: const Icon(Icons.done_all_rounded, size: 18),
                          label: const Text('Mark all read'),
                        ),
                      ),
                    if (alerts.isNotEmpty)
                      const SizedBox(height: AppSpacing.md),
                    SectionCard(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
                          for (final filter in _AlertFilter.values)
                            ChoiceChip(
                              label: Text(_label(filter)),
                              selected: _filter == filter,
                              onSelected: (_) => setState(() => _filter = filter),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (filtered.isEmpty)
                      EmptyState(
                        icon: alerts.isEmpty
                            ? Icons.notifications_none_rounded
                            : Icons.filter_alt_off_outlined,
                        title: alerts.isEmpty
                            ? 'All clear'
                            : 'No alerts in this category',
                        message: alerts.isEmpty
                            ? null
                            : 'Choose another severity filter.',
                      )
                    else
                      Column(
                        children: [
                          for (var index = 0; index < filtered.length; index++) ...[
                            AlertCard(alert: filtered[index]),
                            if (index != filtered.length - 1)
                              const SizedBox(height: AppSpacing.sm),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _label(_AlertFilter filter) {
    switch (filter) {
      case _AlertFilter.all:
        return 'All';
      case _AlertFilter.critical:
        return 'Critical';
      case _AlertFilter.warning:
        return 'Warning';
      case _AlertFilter.info:
        return 'Information';
    }
  }
}
