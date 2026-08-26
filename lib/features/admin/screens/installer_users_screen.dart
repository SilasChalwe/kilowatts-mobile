import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/data/access_control_service.dart';

class InstallerUsersScreen extends StatefulWidget {
  const InstallerUsersScreen({super.key});

  @override
  State<InstallerUsersScreen> createState() => _InstallerUsersScreenState();
}

class _InstallerUsersScreenState extends State<InstallerUsersScreen> {
  Future<void> _openEditor([KilowattsUserAccess? existing]) async {
    final result = await showDialog<_AccessDraft>(
      context: context,
      builder: (_) => _AccessEditorDialog(existing: existing),
    );
    if (result == null || !mounted) return;

    try {
      await AppStateScope.of(context).assignRole(
        email: result.email,
        role: result.role,
        installationId: result.installationId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Access saved for ${result.email}.')),
      );
    } catch (error) {
      if (!mounted) return;
      final message = error is ArgumentError
          ? error.message?.toString() ?? 'Invalid access configuration.'
          : 'Could not save access.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _revoke(KilowattsUserAccess user) async {
    final currentEmail =
        AppStateScope.of(context).currentUser?.email?.toLowerCase();
    if (user.email.toLowerCase() == currentEmail) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Revoke access?'),
        content: Text(user.email),
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
    if (confirmed != true || !mounted) return;

    try {
      await AppStateScope.of(context).revokeAccess(user.email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Access revoked for ${user.email}.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not revoke access.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Users & access'),
        actions: [
          FilledButton.icon(
            onPressed: _openEditor,
            icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
            label: const Text('Add user'),
          ),
          const SizedBox(width: AppSpacing.md),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<List<KilowattsUserAccess>>(
          stream: appState.watchAccessUsers(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const _StatePanel(
                icon: Icons.cloud_off_outlined,
                title: 'Users unavailable',
                message: 'Check Firestore access and connectivity.',
              );
            }

            final users = snapshot.data ?? const <KilowattsUserAccess>[];
            final homeowners = users
                .where((user) => user.role == KilowattsRole.homeowner)
                .toList();
            final installers = users
                .where((user) => user.role == KilowattsRole.installer)
                .toList();

            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _CountCard(
                      icon: Icons.home_outlined,
                      label: 'Homeowners',
                      value: homeowners.length,
                    ),
                    _CountCard(
                      icon: Icons.admin_panel_settings_outlined,
                      label: 'Installers',
                      value: installers.length,
                    ),
                    _CountCard(
                      icon: Icons.people_outline,
                      label: 'Total',
                      value: users.length,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _UserSection(
                  title: 'Homeowners',
                  users: homeowners,
                  currentEmail: appState.currentUser?.email,
                  onEdit: _openEditor,
                  onRevoke: _revoke,
                ),
                const SizedBox(height: AppSpacing.lg),
                _UserSection(
                  title: 'Installers / administrators',
                  users: installers,
                  currentEmail: appState.currentUser?.email,
                  onEdit: _openEditor,
                  onRevoke: _revoke,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AccessDraft {
  const _AccessDraft({
    required this.email,
    required this.role,
    this.installationId,
  });

  final String email;
  final String role;
  final String? installationId;
}

class _AccessEditorDialog extends StatefulWidget {
  const _AccessEditorDialog({this.existing});

  final KilowattsUserAccess? existing;

  @override
  State<_AccessEditorDialog> createState() => _AccessEditorDialogState();
}

class _AccessEditorDialogState extends State<_AccessEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email;
  late final TextEditingController _installation;
  late String _role;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.existing?.email ?? '');
    _installation = TextEditingController(
      text: widget.existing?.installationId ?? '',
    );
    _role = widget.existing?.role == KilowattsRole.installer
        ? 'installer'
        : 'homeowner';
  }

  @override
  void dispose() {
    _email.dispose();
    _installation.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      _AccessDraft(
        email: _email.text.trim(),
        role: _role,
        installationId: _role == 'homeowner'
            ? _installation.text.trim()
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add user' : 'Edit access'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _email,
                enabled: widget.existing == null,
                decoration: const InputDecoration(labelText: 'Account email'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  final email = value?.trim() ?? '';
                  return email.contains('@') ? null : 'Enter a valid email.';
                },
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(
                    value: 'homeowner',
                    child: Text('Homeowner'),
                  ),
                  DropdownMenuItem(
                    value: 'installer',
                    child: Text('Installer / Admin'),
                  ),
                ],
                onChanged: (value) => setState(() => _role = value!),
              ),
              if (_role == 'homeowner') ...[
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _installation,
                  decoration: const InputDecoration(labelText: 'Installation ID'),
                  validator: (value) => value?.trim().isNotEmpty == true
                      ? null
                      : 'Installation ID is required.',
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 165,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$value', style: AppTextStyles.title),
              Text(label, style: AppTextStyles.caption),
            ],
          ),
        ],
      ),
    );
  }
}

class _UserSection extends StatelessWidget {
  const _UserSection({
    required this.title,
    required this.users,
    required this.currentEmail,
    required this.onEdit,
    required this.onRevoke,
  });

  final String title;
  final List<KilowattsUserAccess> users;
  final String? currentEmail;
  final ValueChanged<KilowattsUserAccess> onEdit;
  final ValueChanged<KilowattsUserAccess> onRevoke;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.title),
        const SizedBox(height: AppSpacing.sm),
        if (users.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('None assigned.'),
          )
        else
          ...users.map((user) {
            final isCurrent =
                user.email.toLowerCase() == currentEmail?.toLowerCase();
            return Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.xs),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.surfaceMuted,
                  child: Icon(
                    user.role == KilowattsRole.installer
                        ? Icons.admin_panel_settings_outlined
                        : Icons.home_outlined,
                    color: AppColors.textSecondary,
                  ),
                ),
                title: Row(
                  children: [
                    Flexible(child: Text(user.email)),
                    if (isCurrent) ...[
                      const SizedBox(width: AppSpacing.xs),
                      const _YouBadge(),
                    ],
                  ],
                ),
                subtitle: Text(
                  user.role == KilowattsRole.homeowner
                      ? user.installationId ?? 'No installation'
                      : 'Installer / Administrator',
                ),
                trailing: PopupMenuButton<_UserAction>(
                  onSelected: (action) {
                    if (action == _UserAction.edit) onEdit(user);
                    if (action == _UserAction.revoke && !isCurrent) {
                      onRevoke(user);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: _UserAction.edit,
                      child: Text('Edit access'),
                    ),
                    PopupMenuItem(
                      value: _UserAction.revoke,
                      enabled: !isCurrent,
                      child: Text(
                        isCurrent ? 'Current account' : 'Revoke access',
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

enum _UserAction { edit, revoke }

class _YouBadge extends StatelessWidget {
  const _YouBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'You',
        style: AppTextStyles.caption.copyWith(color: AppColors.info),
      ),
    );
  }
}

class _StatePanel extends StatelessWidget {
  const _StatePanel({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: AppColors.textSecondary),
            const SizedBox(height: AppSpacing.sm),
            Text(title, style: AppTextStyles.title),
            const SizedBox(height: AppSpacing.xs),
            Text(message, style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }
}
