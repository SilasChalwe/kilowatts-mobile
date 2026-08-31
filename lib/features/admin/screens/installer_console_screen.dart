import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/services/mqtt_config.dart';
import '../../../core/services/mqtt_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/responsive_content.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../loads/models/load_model.dart';
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
    final appState = AppStateScope.of(context);
    final userUid = appState.selectedUserUid;
    if (userUid == null || userUid.isEmpty) return;
    final initial = (_config ?? const MqttConfig.unconfigured()).copyWith();
    final updated = await showInstallerBrokerDialog(context, initial);
    if (updated == null || !mounted) return;

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

  Future<void> _removeBroker() async {
    final appState = AppStateScope.of(context);
    final userUid = appState.selectedUserUid;
    if (userUid == null || userUid.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove broker connection?'),
        content: Text('Remove the connection for this user?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await appState.removeMqttConfig(uid: userUid);
    if (!mounted) return;
    setState(() => _config = null);
    _message('Shared MQTT settings removed.');
  }

  Future<void> _configureSafety() async {
    // Same fix as _configureBattery: prefer Central's live values over the
    // local cache, which can be stale (e.g. changed since via the reserve
    // slider) and would otherwise silently overwrite a real live value with
    // an old one the moment the installer hits Apply.
    final liveState = AppStateScope.of(context).systemState.value;
    final initial = <String, dynamic>{
      ..._lastSafety ?? const {},
      if (liveState?.reserveSoCPercent != null)
        'minimumStateOfChargePercent': liveState!.reserveSoCPercent,
      if (liveState?.requiredRuntimeHours != null)
        'requiredRuntimeHours': liveState!.requiredRuntimeHours,
    };
    final draft = await showSafetyPolicyDialog(context, initial);
    if (draft == null || !mounted) return;

    final appState = AppStateScope.of(context);
    final outcome = await appState.applySafetyConfig(draft);
    if (!mounted) return;
    if (!outcome.isConfirmed) {
      _message(
        outcome.message ?? 'Central rejected the safety policy.',
        error: true,
      );
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
    // Prefer Central's live-reported values over the local cache — the
    // cache can be empty or stale (e.g. on a different device than whoever
    // last configured this installation), which would otherwise silently
    // overwrite a real configured value with a generic placeholder the
    // moment the installer hits Apply without changing anything.
    final liveState = AppStateScope.of(context).systemState.value;
    final initial = <String, dynamic>{
      ...?_lastBattery,
      if (liveState?.batteryCapacityAmpHours != null)
        'batteryCapacityAmpHours': liveState!.batteryCapacityAmpHours,
      if (liveState?.batteryNominalVoltageV != null)
        'nominalVoltageVolts': liveState!.batteryNominalVoltageV,
    };
    final draft = await showInstallerBatteryConfigDialog(context, initial);
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
    final outcome = await AppStateScope.of(
      context,
    ).setSimulationEnabled(enabled);
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
    final controller = TextEditingController(
      text: rename ? node.name ?? '' : '',
    );
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

  Future<void> _addLoad(InstallerNodeModel node) async {
    final appState = AppStateScope.of(context);
    final usedPins = appState.loads.value
        .where((load) => load.owningNodeMac == node.mac)
        .map((load) => load.relayPin)
        .toSet();
    final freePins = node.availableRelayPins
        .where((pin) => !usedPins.contains(pin))
        .toList();
    if (freePins.isEmpty) {
      _message('No free relay pins on ${node.displayName}.', error: true);
      return;
    }

    final configuration = await showAddInstallerLoadDialog(
      context,
      node: node,
      freePins: freePins,
    );
    if (configuration == null || !mounted) return;

    final outcome = await appState.configureLoad(configuration);
    if (!mounted) return;
    _message(
      outcome.isConfirmed
          ? 'Load added.'
          : outcome.message ?? 'Central rejected the load configuration.',
      error: !outcome.isConfirmed,
    );
  }

  Future<void> _removeLoad(LoadModel load) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove ${load.name}?'),
        content: Text('Relay GPIO ${load.relayPin} will be unassigned.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final outcome = await AppStateScope.of(
      context,
    ).removeLoad(nodeMac: load.owningNodeMac, relayPin: load.relayPin);
    if (!mounted) return;
    _message(
      outcome.isConfirmed
          ? 'Load removed.'
          : outcome.message ?? 'Central rejected the request.',
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

    final outcome = await AppStateScope.of(
      context,
    ).decommissionNode(nodeMac: node.mac);
    if (!mounted) return;
    _message(
      outcome.isConfirmed
          ? outcome.message ?? 'Node decommissioned.'
          : outcome.message ?? 'Could not decommission node.',
      error: !outcome.isConfirmed,
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
                  child: Text('Nodes', style: AppTextStyles.sectionTitle),
                ),
                Text('${nodes.length} nodes', style: AppTextStyles.caption),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (nodes.isEmpty)
              const EmptyState(
                icon: Icons.device_hub_outlined,
                title: 'No nodes reported',
              )
            else
              ResponsiveCardGrid(
                minCardWidth: 390,
                maxColumns: 2,
                children: [for (final node in nodes) _nodeCard(node)],
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
    final displayedStatus = config.isConfigured
        ? status
        : MqttConnectionStatus.notConfigured;
    return SectionCard(
      title: 'Connection',
      trailing: StatusBadge(
        label: _connectionLabel(displayedStatus),
        tone: _connectionTone(displayedStatus),
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
                Wrap(
                  spacing: AppSpacing.sm,
                  alignment: WrapAlignment.end,
                  children: [
                    if (status != MqttConnectionStatus.connected &&
                        status != MqttConnectionStatus.connecting)
                      OutlinedButton.icon(
                        onPressed: () =>
                            AppStateScope.of(context).connectMqtt(),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Retry connection'),
                      ),
                    OutlinedButton.icon(
                      onPressed: _editBroker,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit connection'),
                    ),
                    TextButton.icon(
                      onPressed: _removeBroker,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Remove'),
                    ),
                  ],
                ),
              ],
            )
          : const SizedBox.shrink(),
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
      // Live readings and configured specs (SoC, voltage, current, capacity)
      // already live on Battery & power — this card is installer-only
      // control surface: switch the input source and edit the spec.
      child: Column(
        children: [
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              OutlinedButton.icon(
                onPressed: central == null
                    ? null
                    : () => _configureBattery(central),
                icon: const Icon(Icons.tune_outlined, size: 18),
                label: const Text('Configure'),
              ),
              OutlinedButton(
                onPressed: _sourceBusy
                    ? null
                    : () => _setSimulation(!simulated),
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
    final state = AppStateScope.of(context).systemState.value;
    final liveMinSoc = state?.reserveConfigured == true
        ? state?.reserveSoCPercent
        : null;
    final liveRuntime = state?.requiredRuntimeConfigured == true
        ? state?.requiredRuntimeHours
        : null;
    final hasAnyValues =
        liveMinSoc != null || liveRuntime != null || _lastSafety != null;

    return SectionCard(
      title: 'Safety policy',
      child: Column(
        children: [
          if (!hasAnyValues)
            const SectionRow(
              label: 'Current values',
              value: 'Not published by Central',
              muted: true,
            )
          else ...[
            SectionRow(
              label: 'Minimum SoC',
              value: liveMinSoc != null
                  ? _optionalNumberText(liveMinSoc, '%')
                  : _numberText(
                      _lastSafety,
                      'minimumStateOfChargePercent',
                      '%',
                    ),
            ),
            SectionRow(
              label: 'Required runtime',
              value: liveRuntime != null
                  ? _optionalNumberText(liveRuntime, ' h')
                  : _numberText(_lastSafety, 'requiredRuntimeHours', ' h'),
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

  Widget _nodeCard(InstallerNodeModel node) {
    final configuredLoads = AppStateScope.of(context).loads.value
        .where((load) => load.owningNodeMac == node.mac)
        .toList(growable: false);
    return SectionCard(
      title: node.displayName,
      subtitle: node.mac,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusBadge(
            label: node.online == true ? 'Online' : 'Offline',
            tone: node.online == true
                ? StatusTone.positive
                : StatusTone.negative,
          ),
          if (node.isCommissioned) ...[
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              tooltip: 'Node actions',
              onSelected: (action) {
                if (action == 'rename') {
                  _commission(node, rename: true);
                } else if (action == 'addLoad') {
                  _addLoad(node);
                } else if (action == 'decommission') {
                  _decommission(node);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'rename',
                  child: Text('Rename node'),
                ),
                if (node.availableRelayPins.isNotEmpty)
                  const PopupMenuItem(
                    value: 'addLoad',
                    child: Text('Add load'),
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
          if (configuredLoads.isNotEmpty) ...[
            const Divider(),
            for (final load in configuredLoads)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(load.name),
                subtitle: Text('GPIO ${load.relayPin}'),
                trailing: IconButton(
                  tooltip: 'Remove load',
                  onPressed: () => _removeLoad(load),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ),
          ],
          if (node.canBeCommissioned || node.isSmartNode) ...[
            const SizedBox(height: AppSpacing.sm),
            if (node.canBeCommissioned)
              FilledButton.icon(
                onPressed: () => _commission(node),
                icon: const Icon(Icons.add_link_outlined, size: 18),
                label: const Text('Commission node'),
              ),
          ],
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

  String _optionalNumberText(double? value, String suffix) {
    if (value == null) return '—';
    final decimals = value % 1 == 0 ? 0 : 2;
    return '${value.toStringAsFixed(decimals)}$suffix';
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
