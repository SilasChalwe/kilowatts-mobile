import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
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
import '../../system/screens/system_topology_screen.dart';
import '../models/installer_node_model.dart';
import 'installer_configuration_dialogs.dart';

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
    final updated = await showInstallerBrokerDialog(context, initial);
    if (updated == null || !mounted) return;
    await AppStateScope.of(context).saveMqttConfig(updated);
    if (!mounted) return;
    setState(() => _config = updated);
    _message('Broker connection saved.');
  }

  Future<void> _configureSafety() async {
    final draft = await showSafetyPolicyDialog(context, _lastSafety);
    if (draft == null || !mounted) return;

    final appState = AppStateScope.of(context);
    final outcome = await appState.applySafetyConfig(draft);
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
    await appState.cacheLastInstallerSafetyConfig(values);
    if (!mounted) return;
    setState(() {
      _lastSafety = {
        ...values,
        'savedAt': DateTime.now().toIso8601String(),
      };
    });
    _message('Safety policy applied.');
  }

  Future<void> _configureBattery(InstallerNodeModel central) async {
    final draft = await showInstallerBatteryConfigDialog(context, _lastBattery);
    if (draft == null || !mounted) return;

    final appState = AppStateScope.of(context);
    final outcome = await appState.configureBatterySensor(
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
    await appState.cacheLastInstallerBatteryConfig(values);
    if (!mounted) return;
    setState(() {
      _lastBattery = {
        ...values,
        'savedAt': DateTime.now().toIso8601String(),
      };
    });
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
    final draft = await showSimulationInputDialog(context);
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
        content: const Text(
          'The node and its configured loads will be removed from this installation.',
        ),
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
    final outcome = await AppStateScope.of(
      context,
    ).decommissionNode(nodeMac: node.mac);
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

    final config = await showAddInstallerLoadDialog(
      context,
      node: node,
      freePins: freePins,
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
                    Text(
                      '${nodes.length} nodes · ${loads.length} loads',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                if (nodes.isEmpty)
                  const SectionCard(child: Text('No nodes reported.'))
                else
                  for (final node in nodes) ...[
                    _nodeCard(
                      node,
                      loads
                          .where((load) => load.owningNodeMac == node.mac)
                          .toList(),
                    ),
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
      trailing: StatusBadge(
        label: _connectionLabel(status),
        tone: _connectionTone(status),
      ),
      child: config.isConfigured
          ? Column(
              children: [
                SectionRow(label: 'Host', value: config.host),
                SectionRow(label: 'Port', value: '${config.port}'),
                SectionRow(
                  label: 'WebSocket path',
                  value: config.webSocketPath,
                ),
                SectionRow(
                  label: 'Topic namespace',
                  value: config.topicNamespace,
                ),
                SectionRow(
                  label: 'Security',
                  value: config.useTls ? 'TLS enabled' : 'TLS off',
                ),
                SectionRow(
                  label: 'Account',
                  value: config.username ?? 'No username',
                ),
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
          SectionRow(
            label: 'Input',
            value: state?.sensorInputSource ?? 'Unavailable',
          ),
          SectionRow(
            label: 'Voltage',
            value: Formatters.voltage(state?.batteryVoltage),
          ),
          SectionRow(
            label: 'Current',
            value: Formatters.current(state?.batteryCurrent),
          ),
          SectionRow(
            label: 'State of charge',
            value: Formatters.percent(state?.batterySocPercent),
          ),
          if (_lastBattery != null) ...[
            const Divider(),
            SectionRow(
              label: 'Nominal voltage',
              value: _numberText(_lastBattery, 'nominalVoltageVolts', ' V'),
            ),
            SectionRow(
              label: 'Capacity',
              value: _numberText(_lastBattery, 'batteryCapacityAmpHours', ' Ah'),
            ),
            SectionRow(
              label: 'Maximum sensor current',
              value: _numberText(
                _lastBattery,
                'maximumExpectedCurrentAmps',
                ' A',
              ),
            ),
            SectionRow(
              label: 'Shunt resistance',
              value: _numberText(_lastBattery, 'shuntResistanceOhms', ' Ω'),
            ),
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
            SectionRow(
              label: 'Minimum state of charge',
              value: _numberText(
                _lastSafety,
                'minimumStateOfChargePercent',
                '%',
              ),
            ),
            SectionRow(
              label: 'Required runtime',
              value: _numberText(_lastSafety, 'requiredRuntimeHours', ' h'),
            ),
            SectionRow(
              label: 'Maximum battery discharge',
              value: _numberText(
                _lastSafety,
                'maximumBatteryDischargeCurrentAmps',
                ' A',
              ),
            ),
            SectionRow(
              label: 'Maximum main current',
              value: _numberText(_lastSafety, 'maximumMainCurrentAmps', ' A'),
            ),
            SectionRow(label: 'Last applied', value: _savedAt(_lastSafety)),
          ] else
            const SectionRow(
              label: 'Current values',
              value: 'Not published by Central',
            ),
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
    final freePins = node.availableRelayPins
        .where((pin) => !usedPins.contains(pin))
        .toList();
    final canAddLoad =
        node.isSmartNode && node.isCommissioned && freePins.isNotEmpty;

    return SectionCard(
      title: node.displayName,
      trailing: StatusBadge(
        label: node.online == true
            ? 'Online'
            : (node.online == false ? 'Offline' : node.lifecycleState),
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
                  label: Text(
                    freePins.isEmpty ? 'No free relay pins' : 'Add load',
                  ),
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
          load.displayState == true
              ? Icons.flash_on_rounded
              : Icons.flash_off_outlined,
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
    if (value is num) {
      return '${value.toStringAsFixed(value % 1 == 0 ? 0 : 2)}$suffix';
    }
    return '—';
  }

  String _savedAt(Map<String, dynamic>? data) {
    final raw = data?['savedAt']?.toString();
    return Formatters.relativeTime(
      raw == null ? null : DateTime.tryParse(raw),
    );
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
