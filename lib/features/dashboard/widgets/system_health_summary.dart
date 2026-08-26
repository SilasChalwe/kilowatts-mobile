import 'package:flutter/material.dart';

import '../../../core/services/mqtt_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
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

  SystemHealth get health {
    if (connectionStatus != MqttConnectionStatus.connected) {
      return SystemHealth.unavailable;
    }
    final central = topology?.central;
    if (central == null || !central.online) return SystemHealth.unavailable;
    if (topology!.smartNodes.any((node) => !node.online)) {
      return SystemHealth.degraded;
    }
    return SystemHealth.ok;
  }

  @override
  Widget build(BuildContext context) {
    final currentHealth = health;
    if (currentHealth == SystemHealth.ok) {
      return const SizedBox.shrink();
    }

    final smartNodes = topology?.smartNodes ?? const [];
    final offlineCount = smartNodes.where((node) => !node.online).length;

    final (title, message, icon, accent) = switch (currentHealth) {
      SystemHealth.degraded => (
          '$offlineCount Smart Node${offlineCount == 1 ? '' : 's'} offline',
          'Some connected loads may be unavailable until the node reconnects.',
          Icons.warning_amber_rounded,
          AppColors.warning,
        ),
      SystemHealth.unavailable => (
          connectionStatus == MqttConnectionStatus.connected
              ? 'Central unavailable'
              : 'System not connected',
          connectionStatus == MqttConnectionStatus.connected
              ? 'The broker is reachable, but Central is not reporting live state.'
              : 'Live monitoring and control are currently unavailable.',
          Icons.cloud_off_rounded,
          AppColors.error,
        ),
      SystemHealth.ok => throw StateError('Healthy state is not rendered.'),
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: accent),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.label),
                const SizedBox(height: 2),
                Text(message, style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
