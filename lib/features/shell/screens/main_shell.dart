import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/services/mqtt_service.dart' show MqttConnectionStatus;
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../admin/screens/installer_console_screen.dart';
import '../../admin/screens/installer_operations_screen.dart';
import '../../admin/screens/installer_users_screen.dart';
import '../../alerts/screens/alerts_screen.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import '../../loads/screens/loads_screen.dart';
import '../../system/screens/system_topology_screen.dart';
import '../widgets/app_bottom_navigation.dart';
import 'more_screen.dart';

/// One responsive product shell for homeowner and installer roles.
/// Phones use the familiar bottom navigation. Wider screens use a persistent
/// sidebar so the product does not look like a stretched mobile application.
class MainShell extends StatefulWidget {
  const MainShell({super.key, this.installerMode = false});

  final bool installerMode;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const _desktopBreakpoint = 900.0;

  int _currentIndex = 0;
  bool _didRequestConnect = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didRequestConnect) return;
    _didRequestConnect = true;

    final appState = AppStateScope.of(context);
    if (appState.connectionStatus.value == MqttConnectionStatus.disconnected ||
        appState.connectionStatus.value == MqttConnectionStatus.notConfigured) {
      appState.connectMqtt();
    }
  }

  void _openMore() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MoreScreen(installerMode: widget.installerMode),
      ),
    );
  }

  void _openInstallerConsole() {
    final desktop = MediaQuery.sizeOf(context).width >= _desktopBreakpoint;
    if (desktop && widget.installerMode) {
      setState(() => _currentIndex = 4);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const InstallerConsoleScreen()),
    );
  }

  void _handleMobileDestination(int index) {
    if (index == 4) {
      _openMore();
      return;
    }
    setState(() => _currentIndex = index);
  }

  List<Widget> _pages() => [
    DashboardScreen(
      onViewAllAlerts: () => setState(() => _currentIndex = 3),
      onOpenInstallerConsole: widget.installerMode ? _openInstallerConsole : null,
    ),
    const LoadsScreen(),
    const SystemTopologyScreen(embedded: true),
    const AlertsScreen(embedded: true),
    if (widget.installerMode) ...[
      const InstallerConsoleScreen(embedded: true),
      const InstallerOperationsScreen(embedded: true),
      const InstallerUsersScreen(embedded: true),
    ],
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= _desktopBreakpoint;
        final pages = _pages();
        final effectiveIndex = _currentIndex < pages.length ? _currentIndex : 0;

        if (desktop) {
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  _DesktopSidebar(
                    installerMode: widget.installerMode,
                    selectedIndex: effectiveIndex,
                    onSelect: (index) => setState(() => _currentIndex = index),
                    onMore: _openMore,
                  ),
                  const VerticalDivider(width: 1, color: AppColors.border),
                  Expanded(
                    child: IndexedStack(index: effectiveIndex, children: pages),
                  ),
                ],
              ),
            ),
          );
        }

        final mobileIndex = effectiveIndex > 3 ? 0 : effectiveIndex;
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: IndexedStack(
              index: mobileIndex,
              children: pages.take(4).toList(growable: false),
            ),
          ),
          bottomNavigationBar: AppBottomNavigation(
            currentIndex: mobileIndex,
            onTap: _handleMobileDestination,
          ),
        );
      },
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.installerMode,
    required this.selectedIndex,
    required this.onSelect,
    required this.onMore,
  });

  final bool installerMode;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 244,
      child: ColoredBox(
        color: AppColors.surface,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 20, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        Icons.bolt_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Kilowatts', style: AppTextStyles.label),
                          Text(
                            installerMode ? 'Installer workspace' : 'Energy manager',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _SidebarItem(
                icon: Icons.home_outlined,
                selectedIcon: Icons.home_rounded,
                label: 'Overview',
                selected: selectedIndex == 0,
                onTap: () => onSelect(0),
              ),
              _SidebarItem(
                icon: Icons.bolt_outlined,
                selectedIcon: Icons.bolt_rounded,
                label: 'Loads',
                selected: selectedIndex == 1,
                onTap: () => onSelect(1),
              ),
              _SidebarItem(
                icon: Icons.account_tree_outlined,
                selectedIcon: Icons.account_tree_rounded,
                label: 'System',
                selected: selectedIndex == 2,
                onTap: () => onSelect(2),
              ),
              _SidebarItem(
                icon: Icons.notifications_outlined,
                selectedIcon: Icons.notifications_rounded,
                label: 'Alerts',
                selected: selectedIndex == 3,
                onTap: () => onSelect(3),
              ),
              if (installerMode) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(10, 22, 10, 8),
                  child: Text('INSTALLATION', style: AppTextStyles.caption),
                ),
                _SidebarItem(
                  icon: Icons.build_outlined,
                  selectedIcon: Icons.build_rounded,
                  label: 'Installer console',
                  selected: selectedIndex == 4,
                  onTap: () => onSelect(4),
                ),
                _SidebarItem(
                  icon: Icons.tune_outlined,
                  selectedIcon: Icons.tune_rounded,
                  label: 'Operations',
                  selected: selectedIndex == 5,
                  onTap: () => onSelect(5),
                ),
                _SidebarItem(
                  icon: Icons.group_outlined,
                  selectedIcon: Icons.group_rounded,
                  label: 'Users & access',
                  selected: selectedIndex == 6,
                  onTap: () => onSelect(6),
                ),
              ],
              const Spacer(),
              _SidebarItem(
                icon: Icons.more_horiz_rounded,
                selectedIcon: Icons.more_horiz_rounded,
                label: 'More',
                selected: false,
                onTap: onMore,
              ),
              const SizedBox(height: AppSpacing.xs),
              _ConnectionFooter(),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? AppColors.surfaceMuted : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(
                  selected ? selectedIcon : icon,
                  size: 20,
                  color: selected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectionFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    return ValueListenableBuilder<MqttConnectionStatus>(
      valueListenable: appState.connectionStatus,
      builder: (context, status, _) {
        final connected = status == MqttConnectionStatus.connected;
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: connected ? AppColors.success : AppColors.offline,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  connected ? 'System connected' : 'System offline',
                  style: AppTextStyles.caption,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
