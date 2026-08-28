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
import '../../../core/widgets/responsive_content.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../loads/models/load_model.dart';
import '../../loads/widgets/load_configuration_dialog.dart';
import '../models/installer_node_model.dart';
import 'installer_configuration_dialogs.dart';

class InstallerConsoleScreen extends StatefulWidget {
  const InstallerConsoleScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<InstallerConsoleScreen> createState() => _InstallerConsoleScreenState();
}

class _InstallerConsoleScreenState extends State<InstallerConsoleScreen> {
  MqttConfig? _config;
  Map<String, dynamic>? _lastSafety;
  Map<String, dynamic>? _lastBattery;
  final Set<String> _loadsBeingUpdated = <String>{};
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

  void _message(String text, {bool error = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: error ? AppColors.error : AppColors.textPrimary,
          content: Row(
            children: [
              Icon(
                error
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(child: Text(text)),
            ],
          ),
        ),
      );
  }

  Future<void> _editBroker() async {
    final initial = _config ?? const MqttConfig.unconfigured();
    final updated = await showInstallerBrokerDialog(context, initial);
    if (updated == null || !mounted) return;

    final appState = AppStateScope.of(context);
    await appState.saveMqttConfig(updated);
    if (!mounted) return;
    setState(() => _config = updated);

    final status = appState.connectionStatus.value;
    if (status == MqttConnectionStatus.connected) {
      _message('Connection saved and connected successfully.');
    } else {
      _message(
        'Connection saved, but the system is ${_connectionLabel(status).toLowerCase()}.',
        error: true,
      );
    }
  }

  Future<void> _configureSafety() async {
    final draft = await showSafetyPolicyDialog(context, _lastSafety);
    if (draft == null || !mounted) return;

    final appState = AppStateScope.of(context);
    final outcome = await appState.applySafetyConfig(draft);
    if (!mounted) return;
    if (!outcome.isConfirmed) {
      _message(outcome.message ?? 'Central rejected the safety policy.', error: true);
      return;
    }

    final values = <String, dynamic>{
      'minimumStateOfChargePercent': draft.lowBatteryCutoffPercent,
      'requiredRuntimeHours': draft.targetRuntimeHours,
      'maximumBatteryDischargeCurrentAmps': draft.maxBatteryDischargeCurrentA,
      'maximumMainCurrentAmps': draft.mainCurrentLimitA,
      'savedAt': DateTime.now().toIso8601String(),
    };
    await appState.cacheLastInstallerSafetyConfig(values);
    if (!mounted) return;
    setState(() => _lastSafety = values);
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
      _message(
        outcome.message ?? 'Central rejected the battery configuration.',
        error: true,
      );
      return;
    }

    final values = <String, dynamic>{
      ...draft.toJson(),
      'savedAt': DateTime.now().toIso8601String(),
    };
    await appState.cacheLastInstallerBatteryConfig(values);
    if (!mounted) return;
    setState(() => _lastBattery = values);
    _message('Battery monitor configuration applied.');
  }

  Future<void> _setSimulation(bool enabled) async {
    if (_sourceBusy) return;
    setState(() => _sourceBusy = true);
    final outcome = await AppStateScope.of(context).setSimulationEnabled(enabled);
    if (!mounted) return;
    setState(() => _sourceBusy = false);
    _message(
      outcome.isConfirmed
          ? (enabled ? 'Battery simulation enabled.' : 'INA219 input enabled.')
          : outcome.message ?? 'Central rejected the request.',
      error: !outcome.isConfirmed,
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
          ? 'Simulated battery readings applied.'
          : outcome.message ?? 'Central rejected the simulated readings.',
      error: !outcome.isConfirmed,
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
            label: 'Node name',
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

    final appState = AppStateScope.of(context);
    final outcome = rename
        ? await appState.renameNode(nodeMac: node.mac, friendlyName: name)
        : await appState.commissionNode(nodeMac: node.mac, friendlyName: name);
    if (!mounted) return;
    _message(
      outcome.isConfirmed
          ? (rename ? 'Node renamed.' : 'Node commissioned.')
          : outcome.message ?? 'Node rejected the request.',
      error: !outcome.isConfirmed,
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

    final outcome = await AppStateScope.of(context).decommissionNode(nodeMac: node.mac);
    if (!mounted) return;
    _message(
      outcome.isConfirmed
          ? outcome.message ?? 'Node decommissioned.'
          : outcome.message ?? 'Could not decommission node.',
      error: !outcome.isConfirmed,
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
    if (freePins.isEmpty) {
      _message('No free relay GPIOs are available on this node.', error: true);
      return;
    }

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
          ? 'Load added to ${node.displayName}.'
          : outcome.message ?? 'Node rejected the load configuration.',
      error: !outcome.isConfirmed,
    );
  }

  Future<void> _editLoad(LoadModel load) async {
    if (_loadsBeingUpdated.contains(load.id)) return;
    final draft = await showLoadConfigurationDialog(context, load: load);
    if (draft == null || !mounted) return;

    setState(() => _loadsBeingUpdated.add(load.id));
    final outcome = await AppStateScope.of(context).updateLoadConfiguration(
      nodeMac: load.owningNodeMac,
      relayPin: load.relayPin,
      mode: draft.mode,
      currentRequestedState: load.requestedState ?? load.confirmedState ?? false,
      priority: draft.priority,
      schedule: draft.mode == LoadMode.fixed
          ? LoadSchedule.disabled
          : draft.schedule,
    );
    if (!mounted) return;
    setState(() => _loadsBeingUpdated.remove(load.id));

    _message(
      outcome.status == CommandStatus.confirmed
          ? '${load.name} configuration updated.'
          : outcome.message ?? 'Central rejected the load configuration.',
      error: outcome.status == CommandStatus.failed,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      if (widget.embedded) {
        return const Material(
          color: Colors.transparent,
          child: Center(child: CircularProgressIndicator()),
        );
      }
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final content = SafeArea(child: _content(context));
    if (widget.embedded) {
      return Material(color: Colors.transparent, child: content);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Installer console')),
      body: content,
    );
  }

  Widget _content(BuildContext context) {
    final appState = AppStateScope.of(context);
    return AnimatedBuilder(
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

        final setupColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Installation setup', style: AppTextStyles.sectionTitle),
            const SizedBox(height: AppSpacing.sm),
            _connectionCard(appState.connectionStatus.value),
            const SizedBox(height: AppSpacing.sm),
            _batteryCard(central),
            const SizedBox(height: AppSpacing.sm),
            _safetyCard(),
          ],
        );

        final nodesWorkspace = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Nodes & loads', style: AppTextStyles.sectionTitle),
                ),
                Text(
                  '${nodes.length} nodes · ${loads.length} loads',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (nodes.isEmpty)
              const SectionCard(
                title: 'No nodes reported',
                child: Text(
                  'Connect Central and wait for node identity reports.',
                  style: AppTextStyles.caption,
                ),
              )
            else
              ResponsiveCardGrid(
                minCardWidth: 390,
                maxColumns: 2,
                children: [
                  for (final node in nodes)
                    _nodeCard(
                      node,
                      loads
                          .where((load) => load.owningNodeMac == node.mac)
                          .toList(),
                    ),
                ],
              ),
          ],
        );

        return ListView(
          children: [
            ResponsiveContent(
              maxWidth: 1320,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 980) {
                    return Column(
                      children: [
                        setupColumn,
                        const SizedBox(height: AppSpacing.lg),
                        nodesWorkspace,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 360, child: setupColumn),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(child: nodesWorkspace),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _connectionCard(MqttConnectionStatus status) {
    final config = _config ?? const MqttConfig.unconfigured();
    return SectionCard(
      title: 'Connection',
      trailing: StatusBadge(
        label: _connectionLabel(status),
        tone: _connectionTone(status),
      ),
      child: config.isConfigured
          ? Column(
              children: [
                SectionRow(label: 'Host', value: config.host),
                SectionRow(label: 'Port', value: '${config.port}'),
                SectionRow(label: 'Namespace', value: config.topicNamespace),
                SectionRow(
                  label: 'Security',
                  value: config.useTls ? 'TLS' : 'No TLS',
                ),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: _editBroker,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit connection'),
                  ),
                ),
              ],
            )
          : Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _editBroker,
                icon: const Icon(Icons.add_link_outlined, size: 18),
                label: const Text('Add connection'),
              ),
            ),
    );
  }

  Widget _batteryCard(InstallerNodeModel? central) {
    final state = AppStateScope.of(context).systemState.value;
    final simulated = state?.sensorInputSource?.toUpperCase() == 'SIMULATED';
    return SectionCard(
      title: 'Battery input',
      trailing: StatusBadge(
        label: simulated ? 'Simulation' : 'INA219',
        tone: simulated ? StatusTone.info : StatusTone.neutral,
      ),
      child: Column(
        children: [
          SectionRow(
            label: 'State of charge',
            value: Formatters.percent(state?.batterySocPercent),
          ),
          SectionRow(
            label: 'Voltage',
            value: Formatters.voltage(state?.batteryVoltage),
          ),
          SectionRow(
            label: 'Current',
            value: Formatters.current(state?.batteryCurrent),
          ),
          if (_lastBattery != null) ...[
            const Divider(),
            SectionRow(
              label: 'Capacity',
              value: _numberText(_lastBattery, 'batteryCapacityAmpHours', ' Ah'),
            ),
            SectionRow(
              label: 'Nominal voltage',
              value: _numberText(_lastBattery, 'nominalVoltageVolts', ' V'),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              OutlinedButton.icon(
                onPressed: central == null ? null : () => _configureBattery(central),
                icon: const Icon(Icons.tune_outlined, size: 18),
                label: const Text('Configure'),
              ),
              OutlinedButton(
                onPressed: _sourceBusy ? null : () => _setSimulation(!simulated),
                child: Text(simulated ? 'Use INA219' : 'Use simulation'),
              ),
              if (simulated)
                OutlinedButton(
                  onPressed: _setSimulationValues,
                  child: const Text('Set readings'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _safetyCard() {
    return SectionCard(
      title: 'Safety policy',
      child: Column(
        children: [
          if (_lastSafety == null)
            const SectionRow(
              label: 'Current values',
              value: 'Not published by Central',
              muted: true,
            )
          else ...[
            SectionRow(
              label: 'Minimum SoC',
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
          ],
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: _configureSafety,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(_lastSafety == null ? 'Configure' : 'Edit policy'),
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
      subtitle: node.mac,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusBadge(
            label: node.online == true ? 'Online' : 'Offline',
            tone:
                node.online == true ? StatusTone.positive : StatusTone.negative,
          ),
          if (node.isCommissioned) ...[
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              tooltip: 'Node actions',
              onSelected: (action) {
                if (action == 'rename') {
                  _commission(node, rename: true);
                } else if (action == 'decommission') {
                  _decommission(node);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'rename',
                  child: Text('Rename node'),
                ),
                if (node.isSmartNode)
                  const PopupMenuItem(
                    value: 'decommission',
                    child: Text('Decommission node'),
                  ),
              ],
              icon: const Icon(Icons.more_horiz_rounded),
            ),
          ],
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionRow(label: 'Role', value: node.role),
          if (node.isSmartNode)
            SectionRow(
              label: 'Relay GPIOs',
              value: node.availableRelayPins.isEmpty
                  ? 'None declared'
                  : node.availableRelayPins.join(', '),
            ),
          const SizedBox(height: AppSpacing.sm),
          Text('Loads', style: AppTextStyles.label),
          const SizedBox(height: AppSpacing.xs),
          if (nodeLoads.isEmpty)
            const Text('No loads configured.', style: AppTextStyles.caption)
          else
            for (final load in nodeLoads) _loadRow(load),
          if (node.canBeCommissioned || node.isSmartNode) ...[
            const SizedBox(height: AppSpacing.sm),
            if (node.canBeCommissioned)
              FilledButton.icon(
                onPressed: () => _commission(node),
                icon: const Icon(Icons.add_link_outlined, size: 18),
                label: const Text('Commission node'),
              )
            else if (node.isSmartNode && node.isCommissioned)
              FilledButton.icon(
                onPressed: canAddLoad ? () => _addLoad(node, nodeLoads) : null,
                icon: const Icon(Icons.add_outlined, size: 18),
                label: Text(freePins.isEmpty ? 'No free relays' : 'Add load'),
              ),
          ],
        ],
      ),
    );
  }

  Widget _loadRow(LoadModel load) {
    final updating = _loadsBeingUpdated.contains(load.id);
    final on = load.displayState == true;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          StatusBadge(
            label: on ? 'ON' : 'OFF',
            tone: on ? StatusTone.positive : StatusTone.negative,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(load.name, style: AppTextStyles.label),
                const SizedBox(height: 2),
                Text(
                  'GPIO ${load.relayPin} · ${load.mode == LoadMode.auto ? 'AUTO' : 'FIXED'} · Priority ${load.priority}/10 · ${Formatters.power(load.plannedPowerW)}',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit load',
            onPressed: updating ? null : () => _editLoad(load),
            icon: updating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.edit_outlined, size: 19),
          ),
        ],
      ),
    );
  }

  String _numberText(Map<String, dynamic>? data, String key, String suffix) {
    final value = data?[key];
    if (value is num) {
      final decimals = value % 1 == 0 ? 0 : 2;
      return '${value.toStringAsFixed(decimals)}$suffix';
    }
    return '—';
  }

  String _connectionLabel(MqttConnectionStatus status) {
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
