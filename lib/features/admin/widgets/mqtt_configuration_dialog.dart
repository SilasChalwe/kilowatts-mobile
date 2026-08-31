import 'package:flutter/material.dart';

import '../../../core/services/mqtt_config.dart';
import '../../../core/theme/app_spacing.dart';

Future<MqttConfig?> showMqttConfigurationDialog(
  BuildContext context,
  MqttConfig initial,
) => showDialog<MqttConfig>(
  context: context,
  builder: (_) => _MqttConfigurationDialog(initial: initial),
);

class _MqttConfigurationDialog extends StatefulWidget {
  const _MqttConfigurationDialog({required this.initial});

  final MqttConfig initial;

  @override
  State<_MqttConfigurationDialog> createState() =>
      _MqttConfigurationDialogState();
}

class _MqttConfigurationDialogState extends State<_MqttConfigurationDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _namespace;
  late final TextEditingController _username;
  late final TextEditingController _password;
  late bool _useTls;

  @override
  void initState() {
    super.initState();
    _host = TextEditingController(text: widget.initial.host);
    _port = TextEditingController(text: '${widget.initial.port}');
    _namespace = TextEditingController(text: widget.initial.topicNamespace);
    _username = TextEditingController(text: widget.initial.username ?? '');
    _password = TextEditingController(text: widget.initial.password ?? '');
    _useTls = widget.initial.useTls;
  }

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    _namespace.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final config = MqttConfig(
      host: _host.text.trim(),
      port: int.parse(_port.text.trim()),
      useTls: _useTls,
      topicNamespace: _namespace.text.trim(),
      username: _username.text.trim().isEmpty ? null : _username.text.trim(),
      password: _password.text.isEmpty ? null : _password.text,
    );
    if (!config.isConfigured) return;
    Navigator.of(context).pop(config);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('MQTT connection'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _host,
                  decoration: const InputDecoration(
                    labelText: 'Broker host',
                    hintText: 'broker.example.com',
                  ),
                  validator: (value) {
                    final host = value?.trim() ?? '';
                    if (host.isEmpty ||
                        host.contains('://') ||
                        host.contains('/') ||
                        host.contains(':') ||
                        host.contains(RegExp(r'\s'))) {
                      return 'Enter a hostname without a scheme or port.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _port,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'TCP port'),
                  validator: (value) {
                    final port = int.tryParse(value?.trim() ?? '');
                    return port == null || port < 1 || port > 65535
                        ? 'Use a port from 1 to 65,535.'
                        : null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _namespace,
                  decoration: const InputDecoration(
                    labelText: 'Topic namespace',
                    hintText: 'kilowatts/v1/home-001',
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    return text.isEmpty ||
                            text.startsWith('/') ||
                            text.endsWith('/') ||
                            text.contains('#') ||
                            text.contains('+') ||
                            text.contains(RegExp(r'\s'))
                        ? 'Enter a valid private topic namespace.'
                        : null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _username,
                  decoration: const InputDecoration(
                    labelText: 'Username (optional)',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password (optional)',
                  ),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Use TLS'),
                  value: _useTls,
                  onChanged: (value) => setState(() => _useTls = value),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save MQTT')),
      ],
    );
  }
}
