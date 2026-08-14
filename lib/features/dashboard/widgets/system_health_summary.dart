import 'package:flutter/material.dart';

import '../../../core/services/mqtt_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/status_badge.dart';
import '../../system/models/topology_model.dart';

enum SystemHealth { ok, degraded, unavailable }

class SystemHealthSummary extends StatelessWidget {
  const SystemHealthSummary({
    required this.connectionStatus,
    required this.topology,
    super.key,
  });

  final MqttConnectionStatus connectionStatus;
  final TopologyModel? topology;

  SystemHealth get _health {
    if (connectionStatus != MqttConnectionStatus.connected) {
      return SystemHealth.unavailable;
    }
    final central = topology?.central;
    if (central == null || !central.online) return SystemHealth.unavailable;
    final offlineSmartNodes = topology!.smartNodes
        .where((n) => !n.online)
        .length;
    if (offlineSmartNodes > 0) return SystemHealth.degraded;
    return SystemHealth.ok;
  }

  @override
  Widget build(BuildContext context) {
    final health = _health;
    final (label, tone) = switch (health) {
      SystemHealth.ok => ('System OK', StatusTone.positive),
      SystemHealth.degraded => ('Degraded', StatusTone.warning),
      SystemHealth.unavailable => ('Unavailable', StatusTone.negative),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          const Text(
            'System Status',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          StatusBadge(label: label, tone: tone),
        ],
      ),
    );
  }
}
