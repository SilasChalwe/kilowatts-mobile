import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/data/access_control_service.dart';

/// Installer-only account administration. Installers can view the assigned
/// Kilowatts accounts, grant/change roles and revoke access. Firestore rules
/// remain the final authorization boundary for every write.
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
      setState(() {
        _saving = false;
        _email.clear();
        _installationId.clear();
        _role = 'homeowner';
      });
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
          '${user.email} will no longer be able to enter the Kilowatts system after their access record is removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
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
        const SnackBar(content: Text('Could not revoke this account.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Users & access', style: AppTextStyles.display),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Installers can grant homeowner access to one installation or grant installer access for system administration.',
              style: AppTextStyles.subtitle,
            ),
            const SizedBox(height: AppSpacing.lg),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Form(
                  key: _formKey,
                  child: Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.end,
                    children: [
                      SizedBox(
                        width: 300,
                        child: TextFormField(
                          controller: _email,
                          decoration: const InputDecoration(
                            labelText: 'Account email',
                          ),
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
                        width: 190,
                        child: DropdownButtonFormField<String>(
                          initialValue: _role,
                          decoration: const InputDecoration(labelText: 'Role'),
                          items: const [
                            DropdownMenuItem(
                              value: 'homeowner',
                              child: Text('Homeowner'),
                            ),
                            DropdownMenuItem(
                              value: 'installer',
                              child: Text('Installer'),
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
                            decoration: const InputDecoration(
                              labelText: 'Installation ID',
                              hintText: 'home-42',
                            ),
                            validator: (value) => _role == 'homeowner' &&
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
                            : const Icon(Icons.person_add_alt_1_outlined),
                        label: Text(_saving ? 'Saving…' : 'Save access'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: StreamBuilder<List<KilowattsUserAccess>>(
                stream: appState.watchAccessUsers(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text(
                        'Could not load users. Verify Firestore installer permissions.',
                      ),
                    );
                  }

                  final users = snapshot.data ?? const <KilowattsUserAccess>[];
                  if (users.isEmpty) {
                    return const Center(child: Text('No assigned users yet.'));
                  }

                  return ListView.separated(
                    itemCount: users.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return ListTile(
                        leading: Icon(
                          user.role == KilowattsRole.installer
                              ? Icons.admin_panel_settings_outlined
                              : Icons.home_outlined,
                        ),
                        title: Text(user.email),
                        subtitle: Text(
                          user.role == KilowattsRole.homeowner
                              ? '${user.roleLabel} · ${user.installationId ?? 'No installation'}'
                              : user.roleLabel,
                        ),
                        trailing: Wrap(
                          spacing: AppSpacing.xs,
                          children: [
                            IconButton(
                              tooltip: 'Edit access',
                              onPressed: () => _edit(user),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'Revoke access',
                              onPressed: () => _revoke(user),
                              icon: const Icon(Icons.person_remove_outlined),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
