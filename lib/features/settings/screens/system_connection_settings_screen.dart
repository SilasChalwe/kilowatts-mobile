import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/services/mqtt_config.dart';
import '../../../core/services/mqtt_service.dart';
import '../../../core/widgets/responsive_content.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/status_badge.dart';

class SystemConnectionSettingsScreen extends StatefulWidget {
  const SystemConnectionSettingsScreen({super.key});

  @override
  State<SystemConnectionSettingsScreen> createState() =>
      _SystemConnectionSettingsScreenState();
}

class _SystemConnectionSettingsScreenState
    extends State<SystemConnectionSettingsScreen> {
  MqttConfig? _config;
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading && _config == null) _load();
  }

  Future<void> _load() async {
    final appState = AppStateScope.of(context);
    final config = await appState.loadMqttConfig();
    if (!mounted) return;
    setState(() {
      _config = config;
      _loading = false;
    });
    if (config.isConfigured) unawaited(appState.connectMqtt());
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('System connection')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                children: [
                  ResponsiveContent(
                    maxWidth: 880,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ValueListenableBuilder<MqttConnectionStatus>(
                          valueListenable: appState.connectionStatus,
                          builder: (context, status, _) {
                            return SectionCard(
                              title: 'Connection status',
                              trailing: StatusBadge(
                                label: _statusLabel(status),
                                tone: _statusTone(status),
                              ),
                              child: const SizedBox.shrink(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  static String _statusLabel(MqttConnectionStatus status) {
    switch (status) {
      case MqttConnectionStatus.connected:
        return 'Connected';
      case MqttConnectionStatus.connecting:
        return 'Connecting';
      case MqttConnectionStatus.reconnecting:
        return 'Reconnecting';
      case MqttConnectionStatus.authenticationFailure:
        return 'Authentication failed';
      case MqttConnectionStatus.tlsFailure:
        return 'TLS failed';
      case MqttConnectionStatus.networkFailure:
        return 'Network unavailable';
      case MqttConnectionStatus.notConfigured:
        return 'Not configured';
      case MqttConnectionStatus.disconnected:
        return 'Disconnected';
    }
  }

  static StatusTone _statusTone(MqttConnectionStatus status) {
    switch (status) {
      case MqttConnectionStatus.connected:
        return StatusTone.positive;
      case MqttConnectionStatus.connecting:
      case MqttConnectionStatus.reconnecting:
        return StatusTone.info;
      case MqttConnectionStatus.notConfigured:
        return StatusTone.warning;
      default:
        return StatusTone.negative;
    }
  }
}
