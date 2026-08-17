import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/services/mqtt_config.dart';
import '../../../core/services/mqtt_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/status_badge.dart';

/// Mobile-only connection setup for a homeowner's already-installed system.
/// It has no commissioning, GPIO, sensor or safety-policy controls; an
/// installer must provide a broker account restricted to this installation.
class SystemConnectionSettingsScreen extends StatefulWidget {
  const SystemConnectionSettingsScreen({super.key});

  @override
  State<SystemConnectionSettingsScreen> createState() =>
      _SystemConnectionSettingsScreenState();
}

class _SystemConnectionSettingsScreenState
    extends State<SystemConnectionSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '8883');
  final _topicNamespaceController = TextEditingController(
    text: 'kilowatts/v1',
  );
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _useTls = true;
  bool _saving = false;
  bool _testing = false;
  String? _savedPassword;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _loadSavedConfiguration();
  }

  Future<void> _loadSavedConfiguration() async {
    final config = await AppStateScope.of(context).loadMqttConfig();
    if (!mounted) return;
    _hostController.text = config.host;
    _portController.text = '${config.port}';
    _topicNamespaceController.text = config.topicNamespace;
    _usernameController.text = config.username ?? '';
    // A local password is not shown again after it has been saved. A blank
    // field preserves it; typing a value deliberately replaces it.
    _savedPassword = config.password;
    _passwordController.clear();
    setState(() => _useTls = config.useTls);
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _topicNamespaceController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _hostValidator(String? value) {
    final host = value?.trim() ?? '';
    if (host.isEmpty) return 'Broker host is required.';
    if (host.contains('://') ||
        host.contains('/') ||
        host.contains(':') ||
        host.contains(RegExp(r'\s'))) {
      return 'Enter only a host name, without a scheme, port or path.';
    }
    return null;
  }

  String? _namespaceValidator(String? value) {
    final namespace = value?.trim() ?? '';
    if (namespace.isEmpty) return 'Topic namespace is required.';
    if (namespace.startsWith('/') ||
        namespace.endsWith('/') ||
        namespace.contains('#') ||
        namespace.contains('+') ||
        namespace.contains(RegExp(r'\s'))) {
      return 'Use a concrete namespace without wildcards or edge slashes.';
    }
    return null;
  }

  MqttConfig? _readForm() {
    if (!(_formKey.currentState?.validate() ?? false)) return null;
    final port = int.tryParse(_portController.text.trim());
    if (port == null || port < 1 || port > 65535) {
      _showMessage('Enter a valid broker port (1–65535).');
      return null;
    }
    return MqttConfig(
      host: _hostController.text.trim(),
      port: port,
      useTls: _useTls,
      topicNamespace: _topicNamespaceController.text.trim(),
      username: _blankToNull(_usernameController.text),
      password: _blankToNull(_passwordController.text) ?? _savedPassword,
    );
  }

  String? _blankToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _testConnection() async {
    final config = _readForm();
    if (config == null) return;
    setState(() => _testing = true);
    final status = await AppStateScope.of(context).testMqttConnection(config);
    if (!mounted) return;
    setState(() => _testing = false);
    _showMessage(
      status == MqttConnectionStatus.connected
          ? 'Connection succeeded.'
          : 'Connection failed: ${_statusLabel(status)}.',
    );
  }

  Future<void> _saveAndConnect() async {
    final config = _readForm();
    if (config == null) return;
    setState(() => _saving = true);
    await AppStateScope.of(context).saveMqttConfig(config);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _savedPassword = config.password;
      _passwordController.clear();
    });
    _showMessage('System connection saved. Connecting to Central…');
  }

  void _showMessage(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('System connection')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            const Text('Connect your Kilowatts system', style: AppTextStyles.title),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Enter the mobile broker access details supplied by your installer. This page cannot configure hardware, sensors or safety limits.',
              style: AppTextStyles.subtitle,
            ),
            const SizedBox(height: AppSpacing.lg),
            ValueListenableBuilder<MqttConnectionStatus>(
              valueListenable: appState.connectionStatus,
              builder: (context, status, _) => SectionCard(
                title: 'Connection status',
                child: SectionRow(
                  label: 'MQTT broker',
                  valueWidget: StatusBadge(
                    label: _statusLabel(status),
                    tone: status == MqttConnectionStatus.connected
                        ? StatusTone.positive
                        : status == MqttConnectionStatus.connecting ||
                              status == MqttConnectionStatus.reconnecting
                        ? StatusTone.info
                        : StatusTone.warning,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SectionCard(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    AppTextField(
                      label: 'Broker host',
                      controller: _hostController,
                      hintText: 'broker.example.com',
                      validator: _hostValidator,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Secure MQTT port',
                      controller: _portController,
                      keyboardType: TextInputType.number,
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Use secure TLS'),
                      subtitle: const Text('Keep this enabled for a production system.'),
                      value: _useTls,
                      onChanged: (value) => setState(() => _useTls = value),
                    ),
                    AppTextField(
                      label: 'Installation topic namespace',
                      controller: _topicNamespaceController,
                      hintText: 'kilowatts/v1/home-42',
                      validator: _namespaceValidator,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Mobile broker username',
                      controller: _usernameController,
                      autofillHints: const [AutofillHints.username],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Mobile broker password',
                      controller: _passwordController,
                      hintText: _savedPassword == null
                          ? null
                          : 'Saved securely — enter only to replace',
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: SecondaryButton(
                            label: _testing ? 'Testing…' : 'Test connection',
                            onPressed: _testing ? null : _testConnection,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: PrimaryButton(
                            label: 'Save and connect',
                            isLoading: _saving,
                            onPressed: _saveAndConnect,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const SectionCard(
              title: 'Account safety',
              child: Text(
                'Use an account restricted by the broker to this installation. Account sign-in controls app access, but broker permissions must independently allow only the topics and load actions intended for this household.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(MqttConnectionStatus status) {
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
}
