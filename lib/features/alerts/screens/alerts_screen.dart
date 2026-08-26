import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/page_header.dart';
import '../models/alert_model.dart';
import '../widgets/alert_card.dart';

enum _AlertFilter { all, critical, warning, info }

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key, this.embedded = false});

  /// Embedded pages live inside MainShell and must not create another app bar.
  /// Standalone pages create their own Scaffold so Material controls and back
  /// navigation always have the correct ancestors.
  final bool embedded;

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

  Widget _content(BuildContext context, {required bool showPageHeader}) {
    final appState = AppStateScope.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showPageHeader) ...[
            PageHeader(
              title: 'Alerts',
              subtitle: 'Warnings and system events from this installation.',
              actions: [
                TextButton.icon(
                  onPressed: appState.acknowledgeAllAlerts,
                  icon: const Icon(Icons.done_all_rounded, size: 18),
                  label: const Text('Mark all read'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ] else
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: appState.acknowledgeAllAlerts,
                icon: const Icon(Icons.done_all_rounded, size: 18),
                label: const Text('Mark all read'),
              ),
            ),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _AlertFilter.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
              itemBuilder: (context, index) {
                final filter = _AlertFilter.values[index];
                return ChoiceChip(
                  label: Text(_label(filter)),
                  selected: _filter == filter,
                  onSelected: (_) => setState(() => _filter = filter),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: ValueListenableBuilder<List<AlertModel>>(
              valueListenable: appState.alerts,
              builder: (context, alerts, _) {
                final filtered = _apply(alerts);
                if (filtered.isEmpty) {
                  return EmptyState(
                    compact: true,
                    icon: Icons.notifications_none_rounded,
                    title: alerts.isEmpty ? 'No alerts' : 'No matching alerts',
                    message: alerts.isEmpty
                        ? 'Everything reported by the system is clear right now.'
                        : 'Try another alert filter.',
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
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return Material(
        color: Colors.transparent,
        child: SafeArea(
          child: _content(context, showPageHeader: true),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Alerts')),
      body: SafeArea(child: _content(context, showPageHeader: false)),
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
