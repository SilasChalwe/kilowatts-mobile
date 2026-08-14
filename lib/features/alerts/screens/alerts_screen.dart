import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/empty_state.dart';
import '../models/alert_model.dart';
import '../widgets/alert_card.dart';

enum _AlertFilter { all, critical, warning, info }

/// Alerts arrive one at a time on `kilowatts/v1/events` — there is no
/// "history of past alerts" topic, so this list only ever holds what has
/// streamed in since the app was opened (accumulated centrally in
/// [AppState.alerts], not by this screen). Acknowledgement is a local,
/// on-device convenience; there is no documented ack-back channel yet.
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
        return alerts
            .where((a) => a.severity == AlertSeverity.critical)
            .toList();
      case _AlertFilter.warning:
        return alerts
            .where((a) => a.severity == AlertSeverity.warning)
            .toList();
      case _AlertFilter.info:
        return alerts.where((a) => a.severity == AlertSeverity.info).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Alerts', style: AppTextStyles.title),
                const Spacer(),
                TextButton(
                  onPressed: appState.acknowledgeAllAlerts,
                  child: const Text('Mark all read'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final filter in _AlertFilter.values) ...[
                    ChoiceChip(
                      label: Text(_label(filter)),
                      selected: _filter == filter,
                      onSelected: (_) => setState(() => _filter = filter),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: ValueListenableBuilder<List<AlertModel>>(
                valueListenable: appState.alerts,
                builder: (context, alerts, _) {
                  final filtered = _apply(alerts);
                  if (filtered.isEmpty) {
                    return const EmptyState(
                      icon: Icons.notifications_off_outlined,
                      title: 'No Alerts',
                      message: 'System alerts will appear here as they happen.',
                    );
                  }
                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) =>
                        AlertCard(alert: filtered[index]),
                  );
                },
              ),
            ),
          ],
        ),
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
        return 'Info';
    }
  }
}
