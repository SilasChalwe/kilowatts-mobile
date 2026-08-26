import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/data/access_control_service.dart';

/// Installer-only account administration. The screen separates homeowner
/// assignments from installer/admin accounts so installation ownership is
/// obvious at a glance.
class InstallerUsersScreen extends StatefulWidget {
  const InstallerUsersScreen({super.key});

  @override
  State<InstallerUsersScreen> createState() => _InstallerUsersScreenState();
}

class _InstallerUsersScreenState extends State<InstallerUsersScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _installationId = TextEditingController();
  String _role = 'homeowner';
  bool _saving = false;
  String? _error;
  bool _editing = false;

  @override
  void dispose() {
    _email.dispose();
    _installationId.dispose();
    super.dispose();
  }

  void _edit(KilowattsUserAccess user) {
    setState(() {
      _email.text = user.email;
      _role = user.role == KilowattsRole.installer ? 'installer' : 'homeowner';
      _installationId.text = user.installationId ?? '';
      _error = null;
      _editing = true;
    });
  }

  void _clearForm() {
    setState(() {
      _email.clear();
      _installationId.clear();
      _role = 'homeowner';
      _error = null;
      _editing = false;
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await AppStateScope.of(context).assignRole(
        email: _email.text.trim(),
        role: _role,
        installationId: _role == 'homeowner'
            ? _installationId.text.trim()
            : null,
      );
      if (!mounted) return;
      final savedEmail = _email.text.trim();
      setState(() => _saving = false);
      _clearForm();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Access updated for $savedEmail.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error is ArgumentError
            ? error.message?.toString()
            : 'Could not update this account. Check your installer access and connection.';
      });
    }
  }

  Future<void> _revoke(KilowattsUserAccess user) async {
    final currentEmail = AppStateScope.of(context).currentUser?.email?.toLowerCase();
    if (user.email.toLowerCase() == currentEmail) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot revoke the installer account you are using.'),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Revoke system access?'),
        content: Text(
          '${user.email} will no longer be able to enter the Kilowatts system after this access record is removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Revoke access'),
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
        const SnackBar(content: Text('Could not revoke this account.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Users & access')),
      body: SafeArea(
        child: StreamBuilder<List<KilowattsUserAccess>>(
          stream: appState.watchAccessUsers(),
          builder: (context, snapshot) {
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
                const Text('Access management', style: AppTextStyles.display),
                const SizedBox(height: AppSpacing.xs),
                const Text(
                  'Homeowners control one installation. Installers inherit homeowner controls and can also commission hardware, change system policy and manage access.',
                  style: AppTextStyles.subtitle,
                ),
                const SizedBox(height: AppSpacing.md),
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
                      label: 'Total access',
                      value: users.length,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _accessForm(),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _error!,
                      style: AppTextStyles.caption.copyWith(color: AppColors.error),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData)
                  const Center(child: CircularProgressIndicator())
                else if (snapshot.hasError)
                  const _MessagePanel(
                    icon: Icons.cloud_off_outlined,
                    title: 'Could not load users',
                    message: 'Verify Firestore installer permissions and connectivity.',
                  )
                else if (users.isEmpty)
                  const _MessagePanel(
                    icon: Icons.person_add_alt_1_outlined,
                    title: 'No assigned users yet',
                    message: 'Use the access form above to add the first homeowner or installer.',
                  )
                else ...[
                  _UserSection(
                    title: 'Homeowners',
                    subtitle: 'Every homeowner must be tied to an installation.',
                    users: homeowners,
                    currentEmail: appState.currentUser?.email,
                    onEdit: _edit,
                    onRevoke: _revoke,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _UserSection(
                    title: 'Installers / administrators',
                    subtitle: 'These accounts can configure hardware and manage access.',
                    users: installers,
                    currentEmail: appState.currentUser?.email,
                    onEdit: _edit,
                    onRevoke: _revoke,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _accessForm() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _editing ? 'Edit account access' : 'Add account access',
                    style: AppTextStyles.title,
                  ),
                ),
                if (_editing)
                  TextButton.icon(
                    onPressed: _saving ? null : _clearForm,
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Cancel edit'),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _role == 'homeowner'
                  ? 'Assign a homeowner to the installation they are allowed to control.'
                  : 'Installer access includes all homeowner controls plus administration.',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                SizedBox(
                  width: 300,
                  child: TextFormField(
                    controller: _email,
                    enabled: !_saving,
                    decoration: const InputDecoration(labelText: 'Account email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      return email.contains('@')
                          ? null
                          : 'Enter a valid email address.';
                    },
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    value: _role,
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
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _role = value!),
                  ),
                ),
                if (_role == 'homeowner')
                  SizedBox(
                    width: 220,
                    child: TextFormField(
                      controller: _installationId,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Installation ID',
                        hintText: 'home-42',
                      ),
                      validator: (value) =>
                          (value?.trim().isEmpty ?? true)
                              ? 'Required for homeowners.'
                              : null,
                    ),
                  ),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(_editing ? Icons.save_outlined : Icons.person_add_alt_1_outlined),
                  label: Text(_saving
                      ? 'Saving…'
                      : _editing
                          ? 'Save changes'
                          : 'Grant access'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
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
    required this.subtitle,
    required this.users,
    required this.currentEmail,
    required this.onEdit,
    required this.onRevoke,
  });

  final String title;
  final String subtitle;
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
        const SizedBox(height: 2),
        Text(subtitle, style: AppTextStyles.caption),
        const SizedBox(height: AppSpacing.sm),
        if (users.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('None assigned.', style: AppTextStyles.caption),
          )
        else
          ...users.map((user) {
            final isCurrent = user.email.toLowerCase() == currentEmail?.toLowerCase();
            return Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.xs),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'You',
                          style: AppTextStyles.caption.copyWith(color: AppColors.info),
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: Text(
                  user.role == KilowattsRole.homeowner
                      ? 'Homeowner · ${user.installationId ?? 'No installation'}'
                      : 'Installer / Administrator',
                ),
                trailing: Wrap(
                  spacing: AppSpacing.xs,
                  children: [
                    IconButton(
                      tooltip: 'Edit access',
                      onPressed: () => onEdit(user),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: isCurrent ? 'Current account cannot be revoked' : 'Revoke access',
                      onPressed: isCurrent ? null : () => onRevoke(user),
                      icon: const Icon(Icons.person_remove_outlined),
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

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: AppColors.textSecondary),
          const SizedBox(height: AppSpacing.sm),
          Text(title, style: AppTextStyles.label),
          const SizedBox(height: 3),
          Text(message, textAlign: TextAlign.center, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
