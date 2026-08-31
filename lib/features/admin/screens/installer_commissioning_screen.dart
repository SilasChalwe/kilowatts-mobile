import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/services/mqtt_config.dart';
import '../../../core/services/mqtt_presence_store.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/responsive_content.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/data/access_control_service.dart';
import '../widgets/mqtt_configuration_dialog.dart';

class InstallerCommissioningScreen extends StatelessWidget {
  const InstallerCommissioningScreen({super.key});

  Future<void> _handover(BuildContext context, KilowattsUserAccess user) async {
    final controller = TextEditingController(
      text: user.installationId == null ? '${user.displayName} home' : '',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          user.installationId == null
              ? 'Start homeowner handover'
              : 'Update installation',
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Installation name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.length >= 2) Navigator.of(dialogContext).pop(value);
            },
            child: const Text('Assign homeowner'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || !context.mounted) return;
    try {
      final installationId = await AppStateScope.of(
        context,
      ).assignHomeowner(uid: user.uid, installationName: name);
      if (!context.mounted) return;
      _message(context, 'Handover ready. Installation: $installationId');
    } catch (_) {
      if (context.mounted) {
        _message(context, 'Could not assign homeowner.', true);
      }
    }
  }

  Future<void> _configureMqtt(
    BuildContext context,
    KilowattsUserAccess user,
  ) async {
    final installationId = user.installationId;
    if (installationId == null) return;
    final appState = AppStateScope.of(context);
    final current = await appState.readSharedMqttConfig(installationId);
    if (!context.mounted) return;
    final config = await showMqttConfigurationDialog(
      context,
      current ??
          MqttConfig(
            host: '',
            port: 8883,
            useTls: true,
            topicNamespace: 'kilowatts/v1/$installationId',
          ),
    );
    if (config == null || !context.mounted) return;
    try {
      await appState.saveSharedMqttConfig(installationId, config);
      if (context.mounted) _message(context, 'MQTT settings saved.');
    } catch (_) {
      if (context.mounted) {
        _message(context, 'Could not save MQTT settings.', true);
      }
    }
  }

  Future<void> _revoke(BuildContext context, KilowattsUserAccess user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Revoke homeowner access?'),
        content: Text(
          '${user.displayName} will be disconnected from this installation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await AppStateScope.of(context).revokeAccess(user.uid);
  }

  static void _message(
    BuildContext context,
    String text, [
    bool error = false,
  ]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: error ? AppColors.error : null,
        content: Text(text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Installer commissioning'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: appState.signOut,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<List<KilowattsUserAccess>>(
          stream: appState.watchAccessUsers(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const EmptyState(
                icon: Icons.cloud_off_outlined,
                title: 'Accounts unavailable',
                message: 'The user directory could not be loaded.',
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final users = snapshot.data!
                .where((user) => user.role != KilowattsRole.installer)
                .toList(growable: false);
            return ListView(
              children: [
                ResponsiveContent(
                  maxWidth: 920,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Homeowner handover', style: AppTextStyles.title),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Assign an account, MQTT connection and physical device assets. All system operation happens in the homeowner app.',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (users.isEmpty)
                        const EmptyState(
                          icon: Icons.person_add_alt_1_outlined,
                          title: 'No homeowner accounts',
                          message:
                              'The homeowner must register and verify an account before handover.',
                        )
                      else
                        for (final user in users) ...[
                          _HandoverCard(
                            user: user,
                            onHandover: () => _handover(context, user),
                            onMqtt: () => _configureMqtt(context, user),
                            onAssets: user.installationId == null
                                ? null
                                : () => showDialog<void>(
                                    context: context,
                                    builder: (_) => _AssetsDialog(
                                      installationId: user.installationId!,
                                    ),
                                  ),
                            onRevoke: () => _revoke(context, user),
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HandoverCard extends StatelessWidget {
  const _HandoverCard({
    required this.user,
    required this.onHandover,
    required this.onMqtt,
    required this.onAssets,
    required this.onRevoke,
  });

  final KilowattsUserAccess user;
  final VoidCallback onHandover;
  final VoidCallback onMqtt;
  final VoidCallback? onAssets;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final assigned = user.installationId != null;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(child: Text(user.initials)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.displayName, style: AppTextStyles.label),
                    Text(user.email, style: AppTextStyles.caption),
                  ],
                ),
              ),
              StatusBadge(
                label: user.roleLabel,
                tone: assigned ? StatusTone.positive : StatusTone.warning,
              ),
            ],
          ),
          if (assigned) ...[
            const SizedBox(height: AppSpacing.sm),
            SelectableText(
              'Installation ${user.installationId}',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSpacing.xs),
            StreamBuilder<MqttPresence?>(
              stream: AppStateScope.of(context).watchMqttPresence(
                installationId: user.installationId!,
                userUid: user.uid,
              ),
              builder: (context, snapshot) {
                final presence = snapshot.data;
                final connected =
                    presence?.online == true && presence?.isFresh == true;
                return Text(
                  connected
                      ? 'Homeowner app connected'
                      : 'Homeowner app not connected',
                  style: AppTextStyles.caption.copyWith(
                    color: connected
                        ? AppColors.success
                        : AppColors.textTertiary,
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              FilledButton.icon(
                onPressed: onHandover,
                icon: const Icon(Icons.assignment_ind_outlined, size: 18),
                label: Text(assigned ? 'Update handover' : 'Start handover'),
              ),
              OutlinedButton.icon(
                onPressed: assigned ? onMqtt : null,
                icon: const Icon(Icons.wifi_tethering_outlined, size: 18),
                label: const Text('MQTT'),
              ),
              OutlinedButton.icon(
                onPressed: onAssets,
                icon: const Icon(Icons.memory_outlined, size: 18),
                label: const Text('Device assets'),
              ),
              if (assigned)
                TextButton.icon(
                  onPressed: onRevoke,
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  icon: const Icon(Icons.link_off_rounded, size: 18),
                  label: const Text('Revoke'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AssetsDialog extends StatefulWidget {
  const _AssetsDialog({required this.installationId});

  final String installationId;

  @override
  State<_AssetsDialog> createState() => _AssetsDialogState();
}

class _AssetsDialogState extends State<_AssetsDialog> {
  final _name = TextEditingController();
  final _deviceId = TextEditingController();
  String _type = 'controller';
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _deviceId.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    if (_name.text.trim().isEmpty || _deviceId.text.trim().isEmpty) return;
    setState(() => _saving = true);
    await AppStateScope.of(context).addInstallationAsset(
      installationId: widget.installationId,
      deviceId: _deviceId.text,
      name: _name.text,
      type: _type,
    );
    if (!mounted) return;
    _name.clear();
    _deviceId.clear();
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Device assets'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Asset name'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _deviceId,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Device ID / serial number',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Asset type'),
                items: const [
                  DropdownMenuItem(
                    value: 'controller',
                    child: Text('Central controller'),
                  ),
                  DropdownMenuItem(value: 'node', child: Text('Smart node')),
                  DropdownMenuItem(
                    value: 'battery',
                    child: Text('Battery monitor'),
                  ),
                  DropdownMenuItem(value: 'meter', child: Text('Power meter')),
                ],
                onChanged: (value) => setState(() => _type = value!),
              ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _add,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(_saving ? 'Adding…' : 'Add asset'),
                ),
              ),
              const Divider(height: AppSpacing.xl),
              StreamBuilder<List<InstallationAsset>>(
                stream: AppStateScope.of(
                  context,
                ).watchInstallationAssets(widget.installationId),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const CircularProgressIndicator();
                  }
                  final assets = snapshot.data!;
                  if (assets.isEmpty) {
                    return const Text('No device assets assigned.');
                  }
                  return Column(
                    children: [
                      for (final asset in assets)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.memory_outlined),
                          title: Text(asset.name),
                          subtitle: Text('${asset.type} · ${asset.deviceId}'),
                          trailing: IconButton(
                            tooltip: 'Remove asset',
                            onPressed: () => AppStateScope.of(context)
                                .removeInstallationAsset(
                                  installationId: widget.installationId,
                                  assetId: asset.id,
                                ),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
