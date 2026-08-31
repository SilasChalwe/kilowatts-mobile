import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/services/mqtt_config.dart';
import '../../../core/services/mqtt_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../loads/models/load_model.dart';
import '../../setup/models/setup_session.dart';
import '../models/installer_node_model.dart';

Future<MqttConfig?> showInstallerBrokerDialog(
  BuildContext context,
  MqttConfig initial,
) {
  return showDialog<MqttConfig>(
    context: context,
    builder: (_) => _InstallerBrokerDialog(initial: initial),
  );
}

Future<SafetyConfigDraft?> showSafetyPolicyDialog(
  BuildContext context,
  Map<String, dynamic>? initial,
) {
  return showDialog<SafetyConfigDraft>(
    context: context,
    builder: (_) => _SafetyPolicyDialog(initial: initial),
  );
}

Future<InstallerBatteryConfigDraft?> showInstallerBatteryConfigDialog(
  BuildContext context,
  Map<String, dynamic>? initial,
) {
  return showDialog<InstallerBatteryConfigDraft>(
    context: context,
    builder: (_) => _BatteryConfigDialog(initial: initial),
  );
}

Future<InstallerLoadConfiguration?> showAddInstallerLoadDialog(
  BuildContext context, {
  required InstallerNodeModel node,
  required List<int> freePins,
}) {
  return showDialog<InstallerLoadConfiguration>(
    context: context,
    builder: (_) => _AddLoadDialog(node: node, freePins: freePins),
  );
}

Future<SimulationInputDraft?> showSimulationInputDialog(BuildContext context) {
  return showDialog<SimulationInputDraft>(
    context: context,
    builder: (_) => const _SimulationDialog(),
  );
}

class InstallerBatteryConfigDraft {
  const InstallerBatteryConfigDraft({
    required this.shuntResistanceOhms,
    required this.nominalVoltageVolts,
    required this.maximumExpectedCurrentAmps,
    required this.emaAlpha,
    required this.batteryCapacityAmpHours,
    required this.initialStateOfChargePercent,
  });

  final double shuntResistanceOhms;
  final double nominalVoltageVolts;
  final double maximumExpectedCurrentAmps;
  final double emaAlpha;
  final double batteryCapacityAmpHours;
  final double initialStateOfChargePercent;

  Map<String, dynamic> toJson() => {
    'shuntResistanceOhms': shuntResistanceOhms,
    'nominalVoltageVolts': nominalVoltageVolts,
    'maximumExpectedCurrentAmps': maximumExpectedCurrentAmps,
    'emaAlpha': emaAlpha,
    'batteryCapacityAmpHours': batteryCapacityAmpHours,
    'initialStateOfChargePercent': initialStateOfChargePercent,
  };
}

class SimulationInputDraft {
  const SimulationInputDraft({
    required this.voltage,
    required this.current,
    this.soc,
  });

  final double voltage;
  final double current;
  final double? soc;
}

class _InstallerBrokerDialog extends StatefulWidget {
  const _InstallerBrokerDialog({required this.initial});

  final MqttConfig initial;

  @override
  State<_InstallerBrokerDialog> createState() => _InstallerBrokerDialogState();
}

class _InstallerBrokerDialogState extends State<_InstallerBrokerDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _webSocketPort;
  late final TextEditingController _path;
  late final TextEditingController _namespace;
  late final TextEditingController _username;
  final _password = TextEditingController();
  late bool _useTls;
  bool _testing = false;
  String? _testResult;
  bool _testOkay = false;

  @override
  void initState() {
    super.initState();
    _host = TextEditingController(text: widget.initial.host);
    _port = TextEditingController(text: '${widget.initial.port}');
    _webSocketPort = TextEditingController(
      text: '${widget.initial.resolvedWebSocketPort}',
    );
    _path = TextEditingController(text: widget.initial.webSocketPath);
    _namespace = TextEditingController(text: widget.initial.topicNamespace);
    _username = TextEditingController(text: widget.initial.username ?? '');
    _useTls = widget.initial.useTls;
  }

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    _webSocketPort.dispose();
    _path.dispose();
    _namespace.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  MqttConfig? _read() {
    if (!(_formKey.currentState?.validate() ?? false)) return null;
    final port = int.tryParse(_port.text.trim());
    final webSocketPort = int.tryParse(_webSocketPort.text.trim());
    if (port == null ||
        port < 1 ||
        port > 65535 ||
        webSocketPort == null ||
        webSocketPort < 1 ||
        webSocketPort > 65535) {
      return null;
    }
    final password = _password.text.trim();
    return MqttConfig(
      host: _host.text.trim(),
      port: port,
      useTls: _useTls,
      webSocketPort: webSocketPort,
      webSocketPath: _path.text.trim(),
      topicNamespace: _namespace.text.trim(),
      username: _username.text.trim().isEmpty ? null : _username.text.trim(),
      password: password.isEmpty ? widget.initial.password : password,
    );
  }

  Future<void> _test() async {
    final config = _read();
    if (config == null) return;
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final status = await AppStateScope.of(context).testMqttConnection(config);
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testOkay = status == MqttConnectionStatus.connected;
      _testResult = _testOkay ? 'Connection successful.' : 'Connection failed.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initial.isConfigured
            ? 'Edit broker connection'
            : 'Add broker connection',
      ),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(
                  label: 'Broker host',
                  controller: _host,
                  validator: (value) {
                    final host = value?.trim() ?? '';
                    if (host.isEmpty) return 'Broker host is required.';
                    if (host.contains('://') ||
                        host.contains('/') ||
                        host.contains(':') ||
                        host.contains(RegExp(r'\s'))) {
                      return 'Enter only the host name.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: 'MQTT/TCP port',
                        controller: _port,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          final port = int.tryParse(value?.trim() ?? '');
                          return port == null || port < 1 || port > 65535
                              ? 'Use 1–65,535.'
                              : null;
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppTextField(
                        label: 'WebSocket port',
                        controller: _webSocketPort,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          final port = int.tryParse(value?.trim() ?? '');
                          return port == null || port < 1 || port > 65535
                              ? 'Use 1–65,535.'
                              : null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'WebSocket path',
                  controller: _path,
                  validator: (value) {
                    final path = value?.trim() ?? '';
                    return path.startsWith('/') ? null : 'Start with /.';
                  },
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
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty ||
                        text.startsWith('/') ||
                        text.endsWith('/') ||
                        text.contains('#') ||
                        text.contains('+') ||
                        text.contains(RegExp(r'\s'))) {
                      return 'Enter a concrete namespace.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(label: 'Broker username', controller: _username),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Broker password',
                  controller: _password,
                  obscureText: true,
                  hintText: widget.initial.password == null
                      ? null
                      : 'Leave blank to keep saved password',
                ),
                if (_testResult != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _testResult!,
                      style: AppTextStyles.caption.copyWith(
                        color: _testOkay ? AppColors.success : AppColors.error,
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

class _SafetyPolicyDialog extends StatefulWidget {
  const _SafetyPolicyDialog({this.initial});

  final Map<String, dynamic>? initial;

  @override
  State<_SafetyPolicyDialog> createState() => _SafetyPolicyDialogState();
}

class _SafetyPolicyDialogState extends State<_SafetyPolicyDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _minimumSoc;
  late final TextEditingController _runtime;
  late final TextEditingController _batteryCurrent;
  late final TextEditingController _mainCurrent;

  @override
  void initState() {
    super.initState();
    _minimumSoc = TextEditingController(
      text: _initial('minimumStateOfChargePercent', 20),
    );
    _runtime = TextEditingController(text: _initial('requiredRuntimeHours', 4));
    _batteryCurrent = TextEditingController(
      text: _initial('maximumBatteryDischargeCurrentAmps', 40),
    );
    _mainCurrent = TextEditingController(
      text: _initial('maximumMainCurrentAmps', 30),
    );
  }

  String _initial(String key, num fallback) =>
      (widget.initial?[key] as num? ?? fallback).toString();

  @override
  void dispose() {
    _minimumSoc.dispose();
    _runtime.dispose();
    _batteryCurrent.dispose();
    _mainCurrent.dispose();
    super.dispose();
  }

  String? _positive(String? value) {
    final parsed = double.tryParse(value?.trim() ?? '');
    return parsed == null || parsed <= 0 ? 'Enter a positive value.' : null;
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      SafetyConfigDraft(
        lowBatteryCutoffPercent: double.parse(_minimumSoc.text.trim()),
        targetRuntimeHours: double.parse(_runtime.text.trim()),
        maxBatteryDischargeCurrentA: double.parse(_batteryCurrent.text.trim()),
        mainCurrentLimitA: double.parse(_mainCurrent.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Safety policy'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                label: 'Minimum state of charge (%)',
                controller: _minimumSoc,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  final parsed = double.tryParse(value?.trim() ?? '');
                  return parsed == null || parsed < 0 || parsed > 100
                      ? 'Use 0–100.'
                      : null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Required runtime (hours)',
                controller: _runtime,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: _positive,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Maximum battery discharge (A)',
                controller: _batteryCurrent,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: _positive,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Maximum main current (A)',
                controller: _mainCurrent,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: _positive,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Apply')),
      ],
    );
  }
}

class _BatteryConfigDialog extends StatefulWidget {
  const _BatteryConfigDialog({this.initial});

  final Map<String, dynamic>? initial;

  @override
  State<_BatteryConfigDialog> createState() => _BatteryConfigDialogState();
}

class _BatteryConfigDialogState extends State<_BatteryConfigDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _shunt;
  late final TextEditingController _voltage;
  late final TextEditingController _maxCurrent;
  late final TextEditingController _ema;
  late final TextEditingController _capacity;
  late final TextEditingController _soc;

  @override
  void initState() {
    super.initState();
    _shunt = TextEditingController(
      text: _initial('shuntResistanceOhms', 0.005),
    );
    _voltage = TextEditingController(text: _initial('nominalVoltageVolts', 12));
    _maxCurrent = TextEditingController(
      text: _initial('maximumExpectedCurrentAmps', 40),
    );
    _ema = TextEditingController(text: _initial('emaAlpha', 0.2));
    _capacity = TextEditingController(
      text: _initial('batteryCapacityAmpHours', 100),
    );
    _soc = TextEditingController(
      text: _initial('initialStateOfChargePercent', 80),
    );
  }

  String _initial(String key, num fallback) =>
      (widget.initial?[key] as num? ?? fallback).toString();

  @override
  void dispose() {
    _shunt.dispose();
    _voltage.dispose();
    _maxCurrent.dispose();
    _ema.dispose();
    _capacity.dispose();
    _soc.dispose();
    super.dispose();
  }

  String? _positive(String? value) {
    final parsed = double.tryParse(value?.trim() ?? '');
    return parsed == null || parsed <= 0 ? 'Enter a positive value.' : null;
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      InstallerBatteryConfigDraft(
        shuntResistanceOhms: double.parse(_shunt.text.trim()),
        nominalVoltageVolts: double.parse(_voltage.text.trim()),
        maximumExpectedCurrentAmps: double.parse(_maxCurrent.text.trim()),
        emaAlpha: double.parse(_ema.text.trim()),
        batteryCapacityAmpHours: double.parse(_capacity.text.trim()),
        initialStateOfChargePercent: double.parse(_soc.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Battery monitor configuration'),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(
                  label: 'Nominal battery voltage (V)',
                  controller: _voltage,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: _positive,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Battery capacity (Ah)',
                  controller: _capacity,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: _positive,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Maximum sensor current (A)',
                  controller: _maxCurrent,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: _positive,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Shunt resistance (Ω)',
                  controller: _shunt,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: _positive,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Filter alpha (0–1]',
                  controller: _ema,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    final parsed = double.tryParse(value?.trim() ?? '');
                    return parsed == null || parsed <= 0 || parsed > 1
                        ? 'Use > 0 and ≤ 1.'
                        : null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Initial state of charge (%)',
                  controller: _soc,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    final parsed = double.tryParse(value?.trim() ?? '');
                    return parsed == null || parsed < 0 || parsed > 100
                        ? 'Use 0–100.'
                        : null;
                  },
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
        FilledButton(onPressed: _save, child: const Text('Apply')),
      ],
    );
  }
}

class _AddLoadDialog extends StatefulWidget {
  const _AddLoadDialog({required this.node, required this.freePins});

  final InstallerNodeModel node;
  final List<int> freePins;

  @override
  State<_AddLoadDialog> createState() => _AddLoadDialogState();
}

class _AddLoadDialogState extends State<_AddLoadDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _power = TextEditingController();
  late int _pin;
  bool _activeHigh = false;
  InstallerLoadPowerType _powerType = InstallerLoadPowerType.dc;
  LoadMode _mode = LoadMode.auto;
  int _priority = 5;

  @override
  void initState() {
    super.initState();
    _pin = widget.freePins.first;
  }

  @override
  void dispose() {
    _name.dispose();
    _power.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      InstallerLoadConfiguration(
        nodeMac: widget.node.mac,
        name: _name.text.trim(),
        relayPin: _pin,
        relayActiveHigh: _activeHigh,
        powerRatingWatts: double.parse(_power.text.trim()),
        priority: _priority,
        mode: _mode,
        powerType: _powerType,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add load to ${widget.node.displayName}'),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(
                  label: 'Load name',
                  controller: _name,
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    return text.isEmpty || text.length >= 16
                        ? 'Use 1–15 characters.'
                        : null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<int>(
                  initialValue: _pin,
                  decoration: const InputDecoration(labelText: 'Relay GPIO'),
                  items: [
                    for (final pin in widget.freePins)
                      DropdownMenuItem(value: pin, child: Text('GPIO $pin')),
                  ],
                  onChanged: (value) => setState(() => _pin = value!),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active-high relay'),
                  value: _activeHigh,
                  onChanged: (value) => setState(() => _activeHigh = value),
                ),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<InstallerLoadPowerType>(
                        initialValue: _powerType,
                        decoration: const InputDecoration(
                          labelText: 'Power type',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: InstallerLoadPowerType.dc,
                            child: Text('DC'),
                          ),
                          DropdownMenuItem(
                            value: InstallerLoadPowerType.ac,
                            child: Text('AC'),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _powerType = value!),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppTextField(
                        label: 'Power rating (W)',
                        controller: _power,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          final parsed = double.tryParse(value?.trim() ?? '');
                          return parsed == null || parsed < 0
                              ? 'Enter watts ≥ 0.'
                              : null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<LoadMode>(
                  initialValue: _mode,
                  decoration: const InputDecoration(labelText: 'Initial mode'),
                  items: const [
                    DropdownMenuItem(value: LoadMode.auto, child: Text('Auto')),
                    DropdownMenuItem(
                      value: LoadMode.fixed,
                      child: Text('Fixed'),
                    ),
                  ],
                  onChanged: (value) => setState(() => _mode = value!),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Priority $_priority/10', style: AppTextStyles.label),
                Slider(
                  value: _priority.toDouble(),
                  min: 0,
                  max: 10,
                  divisions: 10,
                  label: '$_priority',
                  onChanged: (value) =>
                      setState(() => _priority = value.round()),
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
        FilledButton(onPressed: _save, child: const Text('Add load')),
      ],
    );
  }
}

class _SimulationDialog extends StatefulWidget {
  const _SimulationDialog();

  @override
  State<_SimulationDialog> createState() => _SimulationDialogState();
}

class _SimulationDialogState extends State<_SimulationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _voltage = TextEditingController();
  final _current = TextEditingController();
  final _soc = TextEditingController();

  @override
  void dispose() {
    _voltage.dispose();
    _current.dispose();
    _soc.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      SimulationInputDraft(
        voltage: double.parse(_voltage.text.trim()),
        current: double.parse(_current.text.trim()),
        soc: _soc.text.trim().isEmpty ? null : double.parse(_soc.text.trim()),
      ),
    );
  }

  String? _requiredNumber(String? value) =>
      double.tryParse(value?.trim() ?? '') == null ? 'Enter a number.' : null;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Simulated battery readings'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                label: 'Voltage (V)',
                controller: _voltage,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: _requiredNumber,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Current (A)',
                controller: _current,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                validator: _requiredNumber,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'State of charge (%)',
                controller: _soc,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (value?.trim().isEmpty ?? true) return null;
                  final parsed = double.tryParse(value!.trim());
                  return parsed == null || parsed < 0 || parsed > 100
                      ? 'Use 0–100.'
                      : null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Apply')),
      ],
    );
  }
}
