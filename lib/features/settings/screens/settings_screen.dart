import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/responsive_content.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/data/access_control_service.dart';
import 'system_connection_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<InstallationAccess>? _profile;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _profile ??= AppStateScope.of(context).resolveCurrentAccess();
  }

  Future<void> _signOut(BuildContext context) async {
    final appState = AppStateScope.of(context);
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Sign out?',
      message: 'You will need to sign in again to control this installation.',
      confirmLabel: 'Sign out',
      isDestructive: true,
    );
    if (!confirmed) return;

    await appState.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.root, (_) => false);
  }

  Widget _content(BuildContext context) {
    final appState = AppStateScope.of(context);
    final authUser = appState.currentUser;
    final config = appState.mqttConfig;

    return SingleChildScrollView(
      child: ResponsiveContent(
        maxWidth: 1080,
        child: FutureBuilder<InstallationAccess>(
          future: _profile,
          builder: (context, snapshot) {
            final profile = snapshot.data;
            final profileLoaded =
                snapshot.connectionState == ConnectionState.done &&
                !snapshot.hasError &&
                profile != null;
            final fullName = profileLoaded ? profile?.fullName : null;
            final phoneNumber = profileLoaded ? profile?.phoneNumber : null;
            final installationId = profileLoaded ? profile?.installationId : null;
            final role = profileLoaded ? profile?.role : null;

            final account = SectionCard(
              title: 'Account',
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.primarySoft,
                        child: Text(
                          _initials(fullName, authUser?.email),
                          style: AppTextStyles.sectionTitle.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fullName?.trim().isNotEmpty == true
                                  ? fullName!.trim()
                                  : authUser?.email ?? 'Signed in',
                              style: AppTextStyles.sectionTitle,
                            ),
                            if (fullName?.trim().isNotEmpty == true) ...[
                              const SizedBox(height: 3),
                              Text(
                                authUser?.email ?? '—',
                                style: AppTextStyles.caption,
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (role != null)
                        StatusBadge(
                          label: _roleLabel(role),
                          tone: role == KilowattsRole.installer
                              ? StatusTone.info
                              : StatusTone.neutral,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Divider(height: 1),
                  const SizedBox(height: AppSpacing.xs),
                  SectionRow(
                    label: 'Phone',
                    value: profileLoaded
                        ? phoneNumber ?? 'Not recorded'
                        : snapshot.hasError
                            ? 'Profile unavailable'
                            : 'Loading…',
                  ),
                  if (installationId != null)
                    SectionRow(
                      label: 'Installation',
                      value: installationId,
                    ),
                  SectionRow(
                    label: 'Email verification',
                    valueWidget: StatusBadge(
                      label: authUser?.emailVerified == true
                          ? 'Verified'
                          : 'Unverified',
                      tone: authUser?.emailVerified == true
                          ? StatusTone.positive
                          : StatusTone.warning,
                    ),
                  ),
                ],
              ),
            );

            final preferences = SectionCard(
              title: 'Application',
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _SettingsRow(
                    icon: Icons.router_outlined,
                    title: 'System connection',
                    value: config.isConfigured
                        ? '${config.host}:${config.port}'
                        : 'Not configured',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SystemConnectionSettingsScreen(),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  const _SettingsRow(
                    icon: Icons.info_outline_rounded,
                    title: 'About Kilowatts',
                    value: 'Version ${AppConstants.appVersion}',
                  ),
                ],
              ),
            );

            final signOut = SectionCard(
              padding: EdgeInsets.zero,
              child: _SettingsRow(
                icon: Icons.logout_rounded,
                title: 'Sign out',
                value: 'End this session on this device',
                destructive: true,
                onTap: () => _signOut(context),
              ),
            );

            return LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 760) {
                  return Column(
                    children: [
                      account,
                      const SizedBox(height: AppSpacing.md),
                      preferences,
                      const SizedBox(height: AppSpacing.md),
                      signOut,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: account),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          preferences,
                          const SizedBox(height: AppSpacing.md),
                          signOut,
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  static String _roleLabel(KilowattsRole role) {
    switch (role) {
      case KilowattsRole.installer:
        return 'Installer';
      case KilowattsRole.homeowner:
        return 'Homeowner';
      case KilowattsRole.unassigned:
        return 'Unassigned';
    }
  }

  static String _initials(String? name, String? email) {
    final source = name?.trim().isNotEmpty == true
        ? name!.trim()
        : email?.trim() ?? '';
    if (source.isEmpty) return '?';
    final parts = source
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return Material(
        color: Colors.transparent,
        child: SafeArea(child: _content(context)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(child: _content(context)),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.value,
    this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final foreground = destructive ? AppColors.error : AppColors.textPrimary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: foreground),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.label.copyWith(color: foreground),
                    ),
                    const SizedBox(height: 3),
                    Text(value, style: AppTextStyles.caption),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  color: destructive ? AppColors.error : AppColors.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
