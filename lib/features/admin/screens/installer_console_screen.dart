import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/services/command_outcome.dart';
import '../../../core/services/mqtt_config.dart';
import '../../../core/services/mqtt_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../alerts/screens/alerts_screen.dart';
import '../../loads/models/load_model.dart';
import '../../loads/screens/load_details_screen.dart';
import '../../setup/models/setup_session.dart';
import '../../system/screens/system_topology_screen.dart';
import '../models/installer_node_model.dart';

class InstallerConsoleScreen extends StatefulWidget {
  const InstallerConsoleScreen({super.key});

  @override
  State<InstallerConsoleScreen> createState() => _InstallerConsoleScreenState();
}

class _InstallerConsoleScreenState extends State<InstallerConsoleScreen> {
  MqttConfig? _config;
  Map<String, dynamic>? _lastSafety;
  Map<String, dynamic>? _lastBattery;
  bool _loading = true;
  bool _sourceBusy = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _loadSummaries();
  }

  Future<void> _loadSummaries() async {
    final appState = AppStateScope.of(context);
    final config = await appState.loadMqttConfig();
    final safety = await appState.readLastInstallerSafetyConfig();
    final battery = await appState.readLastInstallerBatteryConfig();
    if (!mounted) return;
    setState(() {
      _config = config;
      _lastSafety = safety;
      _lastBattery = battery;
      _loading = false;
    });
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _editBroker() async {
    final initial = _config ?? const MqttConfig.unconfigured();
    final updated = await showDialog<MqttConfig>(
      context: context,
      builder: (_) => _InstallerBrokerDialog(initial: initial),
    );
    if (updated == null || !mounted) return;
    await AppStateScope.of(context).saveMqttConfig(updated);
    if (!mounted) return;
    setState(() => _config = updated);
    _message('Broker connection saved.');
  }

  Future<void> _configureSafety() async {
    final draft = await showDialog<SafetyConfigDraft>(
      context: context,
      builder: (_) => _SafetyPolicyDialog(initial: _lastSafety),
    );
    if (draft == null || !mounted) return;

    final outcome = await AppStateScope.of(context).applySafetyConfig(draft);
    if (!mounted) return;
    if (!outcome.isConfirmed) {
      _message(outcome.message ?? 'Central rejected the safety policy.');
      return;
    }

    final values = <String, dynamic>{
      'minimumStateOfChargePercent': draft.lowBatteryCutoffPercent,
      'requiredRuntimeHours': draft.targetRuntimeHours,
      'maximumBatteryDischargeCurrentAmps': draft.maxBatteryDischargeCurrentA,
      'maximumMainCurrentAmps': draft.mainCurrentLimitA,
    };
    await AppStateScope.of(context).cacheLastInstallerSafetyConfig(values);
    if (!mounted) return;
    setState(() => _lastSafety = {...values, 'savedAt': DateTime.now().toIso8601String()});
    _message('Safety policy applied.');
  }

  Future<void> _configureBattery(InstallerNodeModel central) async {
    final draft = await showDialog<_BatteryConfigDraft>(
      context: context,
      builder: (_) => _BatteryConfigDialog(initial: _lastBattery),
    );
    if (draft == null || !mounted) return;

    final outcome = await AppStateScope.of(context).configureBatterySensor(
      centralNodeMac: central.mac,
      i2cAddress: 0x40,
      shuntResistanceOhms: draft.shuntResistanceOhms,
      nominalVoltageVolts: draft.nominalVoltageVolts,
      maximumExpectedCurrentAmps: draft.maximumExpectedCurrentAmps,
      emaAlpha: draft.emaAlpha,
      batteryCapacityAmpHours: draft.batteryCapacityAmpHours,
      initialStateOfChargePercent: draft.initialStateOfChargePercent,
    );
    if (!mounted) return;
    if (!outcome.isConfirmed) {
      _message(outcome.message ?? 'Central rejected the battery configuration.');
      return;
    }

    final values = draft.toJson();
    await AppStateScope.of(context).cacheLastInstallerBatteryConfig(values);
    if (!mounted) return;
    setState(() => _lastBattery = {...values, 'savedAt': DateTime.now().toIso8601String()});
    _message('Battery monitor configuration applied.');
  }

  Future<void> _setSimulation(bool simulated) async {
    if (_sourceBusy) return;
    setState(() => _sourceBusy = true);
    final outcome = await AppStateScope.of(context).setSimulationEnabled(simulated);
    if (!mounted) return;
    setState(() => _sourceBusy = false);
    _message(
      outcome.isConfirmed
          ? (simulated ? 'Simulation enabled.' : 'INA219 input enabled.')
          : outcome.message ?? 'Central rejected the request.',
    );
  }

  Future<void> _setSimulationValues() async {
    final draft = await showDialog<_SimulationDraft>(
      context: context,
      builder: (_) => const _SimulationDialog(),
    );
    if (draft == null || !mounted) return;
    final outcome = await AppStateScope.of(context).setSimulationValues(
      batteryVoltageVolts: draft.voltage,
      batteryCurrentAmps: draft.current,
      stateOfChargePercent: draft.soc,
    );
    if (!mounted) return;
    _message(
      outcome.isConfirmed
          ? 'Simulation values applied.'
          : outcome.message ?? 'Central rejected the values.',
    );
  }

  Future<void> _commission(
    InstallerNodeModel node, {
    bool rename = false,
  }) async {
    final controller = TextEditingController(text: rename ? node.name ?? '' : '');
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(rename ? 'Rename node' : 'Commission node'),
        content: SizedBox(
          width: 420,
          child: AppTextField(
            label: 'Friendly name',
            controller: controller,
            hintText: 'Kitchen node',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty || value.length >= 20) return;
              Navigator.of(dialogContext).pop(value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || !mounted) return;

    final outcome = rename
        ? await AppStateScope.of(
            context,
          ).renameNode(nodeMac: node.mac, friendlyName: name)
        : await AppStateScope.of(
            context,
          ).commissionNode(nodeMac: node.mac, friendlyName: name);
    if (!mounted) return;
    _message(
      outcome.isConfirmed
          ? 'Node configuration applied.'
          : outcome.message ?? 'Node rejected the request.',
    );
  }

  Future<void> _decommission(InstallerNodeModel node) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Decommission ${node.displayName}?'),
        content: const Text('The node and its configured loads will be removed from this installation.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Decommission'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final outcome = await AppStateScope.of(context).decommissionNode(nodeMac: node.mac);
    if (!mounted) return;
    _message(
      outcome.isConfirmed
          ? outcome.message ?? 'Node decommissioned.'
          : outcome.message ?? 'Could not decommission node.',
    );
  }

  Future<void> _addLoad(
    InstallerNodeModel node,
    List<LoadModel> nodeLoads,
  ) async {
    final usedPins = nodeLoads.map((load) => load.relayPin).toSet();
    final freePins = node.availableRelayPins
        .where((pin) => !usedPins.contains(pin))
        .toList();
    if (freePins.isEmpty) return;

    final config = await showDialog<InstallerLoadConfiguration>(
      context: context,
      builder: (_) => _AddLoadDialog(node: node, freePins: freePins),
    );
    if (config == null || !mounted) return;
    final outcome = await AppStateScope.of(context).configureLoad(config);
    if (!mounted) return;
    _message(
      outcome.isConfirmed
          ? 'Load configured.'
          : outcome.message ?? 'Node rejected the load configuration.',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final appState = AppStateScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Installer console'),
        actions: [
          IconButton(
            tooltip: 'Topology',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SystemTopologyScreen()),
            ),
            icon: const Icon(Icons.account_tree_outlined),
          ),
          IconButton(
            tooltip: 'Activity',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AlertsScreen()),
            ),
            icon: const Icon(Icons.notifications_outlined),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([
            appState.connectionStatus,
            appState.systemState,
            appState.installerNodes,
            appState.loads,
          ]),
          builder: (context, _) {
            final nodes = appState.installerNodes.value;
            final loads = appState.loads.value;
            InstallerNodeModel? central;
            for (final node in nodes) {
              if (node.isCentralNode) {
                central = node;
                break;
              }
            }

            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                _brokerCard(appState.connectionStatus.value),
                const SizedBox(height: AppSpacing.md),
                _batteryCard(central),
                const SizedBox(height: AppSpacing.md),
                _safetyCard(),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    const Expanded(
                      child: Text('Nodes & loads', style: AppTextStyles.title),
                    ),
                    Text('${nodes.length} nodes · ${loads.length} loads', style: AppTextStyles.caption),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                if (nodes.isEmpty)
                  const SectionCard(child: Text('No nodes reported.'))
                else
                  for (final node in nodes) ...[
                    _nodeCard(node, loads.where((load) => load.owningNodeMac == node.mac).toList()),
                    const SizedBox(height: AppSpacing.sm),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _brokerCard(MqttConnectionStatus status) {
    final config = _config!;
    return SectionCard(
      title: 'Broker connection',
      trailing: StatusBadge(label: _connectionLabel(status), tone: _connectionTone(status)),
      child: config.isConfigured
          ? Column(
              children: [
                SectionRow(label: 'Host', value: config.host),
                SectionRow(label: 'Port', value: '${config.port}'),
                SectionRow(label: 'WebSocket path', value: config.webSocketPath),
                SectionRow(label: 'Topic namespace', value: config.topicNamespace),
                SectionRow(label: 'Security', value: config.useTls ? 'TLS enabled' : 'TLS off'),
                SectionRow(label: 'Account', value: config.username ?? 'No username'),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: _editBroker,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit connection'),
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
                  onPressed: _editBroker,
                  icon: const Icon(Icons.add_link_outlined),
                  label: const Text('Add connection'),
                ),
              ],
            ),
    );
  }

  Widget _batteryCard(InstallerNodeModel? central) {
    final state = AppStateScope.of(context).systemState.value;
    final configured = state?.batterySensorConfigured == true;
    final simulated = state?.sensorInputSource?.toUpperCase() == 'SIMULATED';
    return SectionCard(
      title: 'Central battery monitor',
      trailing: StatusBadge(
        label: configured ? 'Configured' : 'Not configured',
        tone: configured ? StatusTone.positive : StatusTone.warning,
      ),
      child: Column(
        children: [
          SectionRow(label: 'Input', value: state?.sensorInputSource ?? 'Unavailable'),
          SectionRow(label: 'Voltage', value: Formatters.voltage(state?.batteryVoltage)),
          SectionRow(label: 'Current', value: Formatters.current(state?.batteryCurrent)),
          SectionRow(label: 'State of charge', value: Formatters.percent(state?.batterySocPercent)),
          if (_lastBattery != null) ...[
            const Divider(),
            SectionRow(label: 'Nominal voltage', value: _numberText(_lastBattery, 'nominalVoltageVolts', ' V')),
            SectionRow(label: 'Capacity', value: _numberText(_lastBattery, 'batteryCapacityAmpHours', ' Ah')),
            SectionRow(label: 'Maximum sensor current', value: _numberText(_lastBattery, 'maximumExpectedCurrentAmps', ' A')),
            SectionRow(label: 'Shunt resistance', value: _numberText(_lastBattery, 'shuntResistanceOhms', ' Ω')),
            SectionRow(label: 'Last applied', value: _savedAt(_lastBattery)),
          ],
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              OutlinedButton.icon(
                onPressed: central == null ? null : () => _configureBattery(central),
                icon: const Icon(Icons.tune_outlined),
                label: Text(configured ? 'Reconfigure' : 'Configure'),
              ),
              OutlinedButton(
                onPressed: _sourceBusy ? null : () => _setSimulation(!simulated),
                child: Text(
                  _sourceBusy
                      ? 'Applying…'
                      : (simulated ? 'Use INA219' : 'Use simulation'),
                ),
              ),
              if (simulated)
                OutlinedButton(
                  onPressed: _setSimulationValues,
                  child: const Text('Set simulated readings'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _safetyCard() {
    final hasSnapshot = _lastSafety != null;
    return SectionCard(
      title: 'Safety policy',
      trailing: StatusBadge(
        label: hasSnapshot ? 'Last applied here' : 'Values unavailable',
        tone: hasSnapshot ? StatusTone.info : StatusTone.neutral,
      ),
      child: Column(
        children: [
          if (hasSnapshot) ...[
            SectionRow(label: 'Minimum state of charge', value: _numberText(_lastSafety, 'minimumStateOfChargePercent', '%')),
            SectionRow(label: 'Required runtime', value: _numberText(_lastSafety, 'requiredRuntimeHours', ' h')),
            SectionRow(label: 'Maximum battery discharge', value: _numberText(_lastSafety, 'maximumBatteryDischargeCurrentAmps', ' A')),
            SectionRow(label: 'Maximum main current', value: _numberText(_lastSafety, 'maximumMainCurrentAmps', ' A')),
            SectionRow(label: 'Last applied', value: _savedAt(_lastSafety)),
          ] else
            const SectionRow(label: 'Current values', value: 'Not published by Central'),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: _configureSafety,
              icon: const Icon(Icons.edit_outlined),
              label: Text(hasSnapshot ? 'Edit policy' : 'Configure policy'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _nodeCard(InstallerNodeModel node, List<LoadModel> nodeLoads) {
    final usedPins = nodeLoads.map((load) => load.relayPin).toSet();
    final freePins = node.availableRelayPins.where((pin) => !usedPins.contains(pin)).toList();
    final canAddLoad = node.isSmartNode && node.isCommissioned && freePins.isNotEmpty;

    return SectionCard(
      title: node.displayName,
      trailing: StatusBadge(
        label: node.online == true ? 'Online' : (node.online == false ? 'Offline' : node.lifecycleState),
        tone: node.online == true ? StatusTone.positive : StatusTone.warning,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionRow(label: 'MAC address', value: node.mac),
          SectionRow(label: 'Role', value: node.role),
          if (node.firmwareVersion != null)
            SectionRow(label: 'Firmware', value: node.firmwareVersion),
          if (node.isSmartNode)
            SectionRow(
              label: 'Relay GPIOs',
              value: node.availableRelayPins.isEmpty
                  ? 'None declared'
                  : node.availableRelayPins.join(', '),
            ),
          const SizedBox(height: AppSpacing.sm),
          if (nodeLoads.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Text('No loads configured.'),
            )
          else
            ...nodeLoads.map(_loadTile),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              if (node.canBeCommissioned)
                FilledButton.icon(
                  onPressed: () => _commission(node),
                  icon: const Icon(Icons.add_link_outlined),
                  label: const Text('Commission'),
                ),
              if (node.isCommissioned)
                OutlinedButton.icon(
                  onPressed: () => _commission(node, rename: true),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Rename'),
                ),
              if (node.isSmartNode && node.isCommissioned)
                OutlinedButton.icon(
                  onPressed: () => _decommission(node),
                  icon: const Icon(Icons.link_off_outlined),
                  label: const Text('Decommission'),
                ),
              if (node.isSmartNode && node.isCommissioned)
                FilledButton.icon(
                  onPressed: canAddLoad ? () => _addLoad(node, nodeLoads) : null,
                  icon: const Icon(Icons.add_outlined),
                  label: Text(freePins.isEmpty ? 'No free relay pins' : 'Add load'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _loadTile(LoadModel load) {
    final schedule = load.schedule.enabled
        ? '${Formatters.timeOfDay(load.schedule.startHour ?? 0, load.schedule.startMinute ?? 0)} – ${Formatters.timeOfDay(load.schedule.endHour ?? 0, load.schedule.endMinute ?? 0)}'
        : 'No schedule';
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          load.displayState == true ? Icons.flash_on_rounded : Icons.flash_off_outlined,
        ),
        title: Text(load.name),
        subtitle: Text(
          'GPIO ${load.relayPin} · ${Formatters.power(load.plannedPowerW)} · ${load.mode == LoadMode.auto ? 'Auto' : 'Fixed'} · Priority ${load.priority}/10\n$schedule',
        ),
        isThreeLine: true,
        trailing: OutlinedButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => LoadDetailsScreen(load: load)),
          ),
          child: const Text('Open'),
        ),
      ),
    );
  }

  String _numberText(Map<String, dynamic>? data, String key, String suffix) {
    final value = data?[key];
    if (value is num) return '${value.toStringAsFixed(value % 1 == 0 ? 0 : 2)}$suffix';
    return '—';
  }

  String _savedAt(Map<String, dynamic>? data) {
    final raw = data?['savedAt']?.toString();
    return Formatters.relativeTime(raw == null ? null : DateTime.tryParse(raw));
  }

  String _connectionLabel(MqttConnectionStatus status) {
    switch (status) {
      case MqttConnectionStatus.connected:
        return 'Connected';
      case MqttConnectionStatus.connecting:
        return 'Connecting';
      case MqttConnectionStatus.reconnecting:
        return 'Reconnecting';
      case MqttConnectionStatus.notConfigured:
        return 'Not configured';
      case MqttConnectionStatus.authenticationFailure:
        return 'Authentication failed';
      case MqttConnectionStatus.tlsFailure:
        return 'TLS failed';
      case MqttConnectionStatus.networkFailure:
        return 'Network unavailable';
      case MqttConnectionStatus.disconnected:
        return 'Disconnected';
    }
  }

  StatusTone _connectionTone(MqttConnectionStatus status) {
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
    _path = TextEditingController(text: widget.initial.webSocketPath);
    _namespace = TextEditingController(text: widget.initial.topicNamespace);
    _username = TextEditingController(text: widget.initial.username ?? '');
    _useTls = widget.initial.useTls;
  }

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    _path.dispose();
    _namespace.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  MqttConfig? _read() {
    if (!(_formKey.currentState?.validate() ?? false)) return null;
    final port = int.tryParse(_port.text.trim());
    if (port == null || port < 1 || port > 65535) return null;
    final password = _password.text.trim();
    return MqttConfig(
      host: _host.text.trim(),
      port: port,
      useTls: _useTls,
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
      title: Text(widget.initial.isConfigured ? 'Edit broker connection' : 'Add broker connection'),
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
                    if (host.contains('://') || host.contains('/') || host.contains(':')) {
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
                        label: 'Port',
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
                        label: 'WebSocket path',
                        controller: _path,
                        validator: (value) {
                          final path = value?.trim() ?? '';
                          return path.startsWith('/') ? null : 'Start with /.';
                        },
                      ),
                    ),
                  ],
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
                    return text.isEmpty || text.contains('#') || text.contains('+')
                        ? 'Enter a concrete namespace.'
                        : null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(label: 'Broker username', controller: _username),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Broker password',
                  controller: _password,
                  obscureText: true,
                  hintText: widget.initial.password == null ? null : 'Leave blank to keep saved password',
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
    _minimumSoc = TextEditingController(text: _initial('minimumStateOfChargePercent', 20));
    _runtime = TextEditingController(text: _initial('requiredRuntimeHours', 4));
    _batteryCurrent = TextEditingController(text: _initial('maximumBatteryDischargeCurrentAmps', 40));
    _mainCurrent = TextEditingController(text: _initial('maximumMainCurrentAmps', 30));
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
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  final parsed = double.tryParse(value?.trim() ?? '');
                  return parsed == null || parsed < 0 || parsed > 100 ? 'Use 0–100.' : null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Required runtime (hours)',
                controller: _runtime,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: _positive,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Maximum battery discharge (A)',
                controller: _batteryCurrent,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: _positive,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Maximum main current (A)',
                controller: _mainCurrent,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: _positive,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Apply')),
      ],
    );
  }
}

class _BatteryConfigDraft {
  const _BatteryConfigDraft({
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
    _shunt = TextEditingController(text: _initial('shuntResistanceOhms', 0.005));
    _voltage = TextEditingController(text: _initial('nominalVoltageVolts', 12));
    _maxCurrent = TextEditingController(text: _initial('maximumExpectedCurrentAmps', 40));
    _ema = TextEditingController(text: _initial('emaAlpha', 0.2));
    _capacity = TextEditingController(text: _initial('batteryCapacityAmpHours', 100));
    _soc = TextEditingController(text: _initial('initialStateOfChargePercent', 80));
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
      _BatteryConfigDraft(
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
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: _positive,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Battery capacity (Ah)',
                  controller: _capacity,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: _positive,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Maximum sensor current (A)',
                  controller: _maxCurrent,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: _positive,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Shunt resistance (Ω)',
                  controller: _shunt,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: _positive,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Filter alpha (0–1]',
                  controller: _ema,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    final parsed = double.tryParse(value?.trim() ?? '');
                    return parsed == null || parsed <= 0 || parsed > 1 ? 'Use > 0 and ≤ 1.' : null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Initial state of charge (%)',
                  controller: _soc,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    final parsed = double.tryParse(value?.trim() ?? '');
                    return parsed == null || parsed < 0 || parsed > 100 ? 'Use 0–100.' : null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
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
                    return text.isEmpty || text.length >= 16 ? 'Use 1–15 characters.' : null;
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
                        decoration: const InputDecoration(labelText: 'Power type'),
                        items: const [
                          DropdownMenuItem(value: InstallerLoadPowerType.dc, child: Text('DC')),
                          DropdownMenuItem(value: InstallerLoadPowerType.ac, child: Text('AC')),
                        ],
                        onChanged: (value) => setState(() => _powerType = value!),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppTextField(
                        label: 'Power rating (W)',
                        controller: _power,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          final parsed = double.tryParse(value?.trim() ?? '');
                          return parsed == null || parsed < 0 ? 'Enter watts ≥ 0.' : null;
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
                    DropdownMenuItem(value: LoadMode.fixed, child: Text('Fixed')),
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
                  onChanged: (value) => setState(() => _priority = value.round()),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Add load')),
      ],
    );
  }
}

class _SimulationDraft {
  const _SimulationDraft({required this.voltage, required this.current, this.soc});

  final double voltage;
  final double current;
  final double? soc;
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
      _SimulationDraft(
        voltage: double.parse(_voltage.text.trim()),
        current: double.parse(_current.text.trim()),
        soc: _soc.text.trim().isEmpty ? null : double.parse(_soc.text.trim()),
      ),
    );
  }

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
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: _requiredNumber,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Current (A)',
                controller: _current,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                validator: _requiredNumber,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'State of charge (%)',
                controller: _soc,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value?.trim().isEmpty ?? true) return null;
                  final parsed = double.tryParse(value!.trim());
                  return parsed == null || parsed < 0 || parsed > 100 ? 'Use 0–100.' : null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Apply')),
      ],
    );
  }

  String? _requiredNumber(String? value) =>
      double.tryParse(value?.trim() ?? '') == null ? 'Enter a number.' : null;
}
