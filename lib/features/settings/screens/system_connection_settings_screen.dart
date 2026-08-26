import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/services/mqtt_config.dart';
import '../../../core/services/mqtt_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_text_field.dart';
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
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading && _config == null) _load();
  }

  Future<void> _load() async {
    final config = await AppStateScope.of(context).loadMqttConfig();
    if (!mounted) return;
    setState(() {
      _config = config;
      _loading = false;
    });
  }

  Future<void> _editConnection() async {
    final current = _config ?? const MqttConfig.unconfigured();
    final updated = await showDialog<MqttConfig>(
      context: context,
      builder: (_) => _ConnectionEditorDialog(initial: current),
    );
    if (updated == null || !mounted) return;

    setState(() => _saving = true);
    await AppStateScope.of(context).saveMqttConfig(updated);
    if (!mounted) return;
    setState(() {
      _config = updated;
      _saving = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Connection saved.')),
    );
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
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  const Text('System connection', style: AppTextStyles.title),
                  const SizedBox(height: AppSpacing.md),
                  ValueListenableBuilder<MqttConnectionStatus>(
                    valueListenable: appState.connectionStatus,
                    builder: (context, status, _) {
                      final config = _config!;
                      return SectionCard(
                        title: 'MQTT broker',
                        trailing: StatusBadge(
                          label: _statusLabel(status),
                          tone: _statusTone(status),
                        ),
                        child: config.isConfigured
                            ? Column(
                                children: [
                                  SectionRow(label: 'Host', value: config.host),
                                  SectionRow(
                                    label: 'Port',
                                    value: '${config.port}',
                                  ),
                                  SectionRow(
                                    label: 'Security',
                                    value: config.useTls ? 'TLS enabled' : 'TLS off',
                                  ),
                                  SectionRow(
                                    label: 'Topic namespace',
                                    value: config.topicNamespace,
                                  ),
                                  SectionRow(
                                    label: 'Broker account',
                                    value: config.username?.isNotEmpty == true
                                        ? config.username
                                        : 'No username',
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: OutlinedButton.icon(
                                      onPressed: _saving ? null : _editConnection,
                                      icon: const Icon(Icons.edit_outlined),
                                      label: Text(
                                        _saving ? 'Saving…' : 'Edit connection',
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('No broker connection is saved.'),
                                  const SizedBox(height: AppSpacing.md),
                                  FilledButton.icon(
                                    onPressed: _saving ? null : _editConnection,
                                    icon: const Icon(Icons.add_link_outlined),
                                    label: const Text('Add connection'),
                                  ),
                                ],
                              ),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const SectionCard(
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Broker credentials are stored on this device.',
                            style: AppTextStyles.caption,
                          ),
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

class _ConnectionEditorDialog extends StatefulWidget {
  const _ConnectionEditorDialog({required this.initial});

  final MqttConfig initial;

  @override
  State<_ConnectionEditorDialog> createState() =>
      _ConnectionEditorDialogState();
}

class _ConnectionEditorDialogState extends State<_ConnectionEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _namespace;
  late final TextEditingController _username;
  final _password = TextEditingController();
  late bool _useTls;
  bool _testing = false;
  String? _testMessage;
  bool _testSucceeded = false;

  @override
  void initState() {
    super.initState();
    _host = TextEditingController(text: widget.initial.host);
    _port = TextEditingController(text: '${widget.initial.port}');
    _namespace = TextEditingController(text: widget.initial.topicNamespace);
    _username = TextEditingController(text: widget.initial.username ?? '');
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

  String? _hostValidator(String? value) {
    final host = value?.trim() ?? '';
    if (host.isEmpty) return 'Broker host is required.';
    if (host.contains('://') ||
        host.contains('/') ||
        host.contains(':') ||
        host.contains(RegExp(r'\s'))) {
      return 'Enter only the host name.';
    }
    return null;
  }

  String? _namespaceValidator(String? value) {
    final valueText = value?.trim() ?? '';
    if (valueText.isEmpty) return 'Topic namespace is required.';
    if (valueText.startsWith('/') ||
        valueText.endsWith('/') ||
        valueText.contains('#') ||
        valueText.contains('+') ||
        valueText.contains(RegExp(r'\s'))) {
      return 'Use a concrete topic namespace.';
    }
    return null;
  }

  MqttConfig? _read() {
    if (!(_formKey.currentState?.validate() ?? false)) return null;
    final port = int.tryParse(_port.text.trim());
    if (port == null || port < 1 || port > 65535) {
      setState(() {
        _testSucceeded = false;
        _testMessage = 'Use a port from 1 to 65,535.';
      });
      return null;
    }
    final newPassword = _password.text.trim();
    return MqttConfig(
      host: _host.text.trim(),
      port: port,
      useTls: _useTls,
      topicNamespace: _namespace.text.trim(),
      username: _username.text.trim().isEmpty ? null : _username.text.trim(),
      password: newPassword.isEmpty ? widget.initial.password : newPassword,
    );
  }

  Future<void> _test() async {
    final config = _read();
    if (config == null) return;
    setState(() {
      _testing = true;
      _testMessage = null;
    });
    final status = await AppStateScope.of(context).testMqttConnection(config);
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testSucceeded = status == MqttConnectionStatus.connected;
      _testMessage = _testSucceeded
          ? 'Connection successful.'
          : 'Could not connect (${_SystemConnectionSettingsScreenState._statusLabel(status)}).';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial.isConfigured ? 'Edit connection' : 'Add connection'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(
                  label: 'Broker host',
                  controller: _host,
                  validator: _hostValidator,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Port',
                  controller: _port,
                  keyboardType: TextInputType.number,
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Use TLS'),
                  value: _useTls,
                  onChanged: (value) => setState(() => _useTls = value),
                ),
                AppTextField(
                  label: 'Topic namespace',
                  controller: _namespace,
                  validator: _namespaceValidator,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Broker username',
                  controller: _username,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Broker password',
                  controller: _password,
                  obscureText: true,
                  hintText: widget.initial.password == null
                      ? null
                      : 'Leave blank to keep saved password',
                ),
                if (_testMessage != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _testMessage!,
                      style: AppTextStyles.caption.copyWith(
                        color: _testSucceeded
                            ? AppColors.success
                            : AppColors.error,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _testing ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        OutlinedButton(
          onPressed: _testing ? null : _test,
          child: Text(_testing ? 'Testing…' : 'Test'),
        ),
        FilledButton(
          onPressed: _testing
              ? null
              : () {
                  final config = _read();
                  if (config != null) Navigator.of(context).pop(config);
                },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
