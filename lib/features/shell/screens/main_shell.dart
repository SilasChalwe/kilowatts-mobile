import 'package:flutter/foundation.dart';
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
import '../../battery/screens/battery_power_screen.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import '../../history/screens/history_screen.dart';
import '../../loads/screens/loads_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../system/screens/system_topology_screen.dart';
import '../widgets/app_bottom_navigation.dart';
import 'more_screen.dart';

/// Platform-aware application shell.
///
/// Web never renders the mobile bottom bar. Wide web gets a persistent
/// sidebar; compact web gets one hamburger/drawer. Native mobile keeps the
/// bottom navigation and does not add a competing hamburger navigation.
class MainShell extends StatefulWidget {
  const MainShell({super.key, this.installerMode = false});

  final bool installerMode;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const _wideWebBreakpoint = 980.0;

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

  List<_ShellPage> _webPages() => [
        _ShellPage(
          label: 'Overview',
          icon: Icons.home_outlined,
          selectedIcon: Icons.home_rounded,
          child: DashboardScreen(
            onViewAllAlerts: () => setState(() => _currentIndex = 3),
          ),
        ),
        const _ShellPage(
          label: 'Loads',
          icon: Icons.bolt_outlined,
          selectedIcon: Icons.bolt_rounded,
          child: LoadsScreen(),
        ),
        const _ShellPage(
          label: 'System',
          icon: Icons.account_tree_outlined,
          selectedIcon: Icons.account_tree_rounded,
          child: SystemTopologyScreen(embedded: true),
        ),
        const _ShellPage(
          label: 'Alerts',
          icon: Icons.notifications_outlined,
          selectedIcon: Icons.notifications_rounded,
          child: AlertsScreen(embedded: true),
        ),
        const _ShellPage(
          label: 'Battery & power',
          icon: Icons.battery_charging_full_outlined,
          selectedIcon: Icons.battery_charging_full_rounded,
          group: 'INSIGHTS',
          child: BatteryPowerScreen(embedded: true),
        ),
        const _ShellPage(
          label: 'History & reports',
          icon: Icons.bar_chart_outlined,
          selectedIcon: Icons.bar_chart_rounded,
          child: HistoryScreen(embedded: true),
        ),
        const _ShellPage(
          label: 'Settings',
          icon: Icons.settings_outlined,
          selectedIcon: Icons.settings_rounded,
          child: SettingsScreen(embedded: true),
        ),
        if (widget.installerMode) ...[
          const _ShellPage(
            label: 'Installer console',
            icon: Icons.build_outlined,
            selectedIcon: Icons.build_rounded,
            group: 'INSTALLATION',
            child: InstallerConsoleScreen(embedded: true),
          ),
          const _ShellPage(
            label: 'Operations',
            icon: Icons.tune_outlined,
            selectedIcon: Icons.tune_rounded,
            child: InstallerOperationsScreen(embedded: true),
          ),
          const _ShellPage(
            label: 'Users & access',
            icon: Icons.group_outlined,
            selectedIcon: Icons.group_rounded,
            child: InstallerUsersScreen(embedded: true),
          ),
        ],
      ];

  List<Widget> _mobilePages() => [
        DashboardScreen(
          onViewAllAlerts: () => setState(() => _currentIndex = 3),
        ),
        const LoadsScreen(),
        const SystemTopologyScreen(embedded: true),
        const AlertsScreen(embedded: true),
      ];

  void _select(int index) => setState(() => _currentIndex = index);

  void _openMore() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MoreScreen(installerMode: widget.installerMode),
      ),
    );
  }

  void _handleMobileDestination(int index) {
    if (index == 4) {
      _openMore();
      return;
    }
    _select(index);
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      final pages = _webPages();
      final effectiveIndex = _currentIndex < pages.length ? _currentIndex : 0;
      return LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= _wideWebBreakpoint;
          if (wide) {
            return Scaffold(
              body: SafeArea(
                child: Row(
                  children: [
                    _WebSidebar(
                      installerMode: widget.installerMode,
                      pages: pages,
                      selectedIndex: effectiveIndex,
                      onSelect: _select,
                    ),
                    const VerticalDivider(width: 1, color: AppColors.border),
                    Expanded(
                      child: IndexedStack(
                        index: effectiveIndex,
                        children: pages.map((page) => page.child).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Scaffold(
            appBar: AppBar(title: Text(pages[effectiveIndex].label)),
            drawer: _WebDrawer(
              installerMode: widget.installerMode,
              pages: pages,
              selectedIndex: effectiveIndex,
              onSelect: (index) {
                Navigator.of(context).pop();
                _select(index);
              },
            ),
            body: IndexedStack(
              index: effectiveIndex,
              children: pages.map((page) => page.child).toList(),
            ),
          );
        },
      );
    }

    // Native mobile: one navigation system only — the bottom bar.
    final pages = _mobilePages();
    final effectiveIndex = _currentIndex < 4 ? _currentIndex : 0;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: effectiveIndex, children: pages),
      ),
      bottomNavigationBar: AppBottomNavigation(
        currentIndex: effectiveIndex,
        onTap: _handleMobileDestination,
      ),
    );
  }
}

class _ShellPage {
  const _ShellPage({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.child,
    this.group,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget child;
  final String? group;
}

class _WebSidebar extends StatelessWidget {
  const _WebSidebar({
    required this.installerMode,
    required this.pages,
    required this.selectedIndex,
    required this.onSelect,
  });

  final bool installerMode;
  final List<_ShellPage> pages;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 252,
      child: ColoredBox(
        color: AppColors.surface,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 20, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BrandHeader(installerMode: installerMode),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: ListView(
                  children: [
                    for (var index = 0; index < pages.length; index++) ...[
                      if (pages[index].group != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 20, 10, 8),
                          child: Text(
                            pages[index].group!,
                            style: AppTextStyles.caption,
                          ),
                        ),
                      _NavItem(
                        page: pages[index],
                        selected: selectedIndex == index,
                        onTap: () => onSelect(index),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              const _ConnectionFooter(),
            ],
          ),
        ),
      ),
    );
  }
}

class _WebDrawer extends StatelessWidget {
  const _WebDrawer({
    required this.installerMode,
    required this.pages,
    required this.selectedIndex,
    required this.onSelect,
  });

  final bool installerMode;
  final List<_ShellPage> pages;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BrandHeader(installerMode: installerMode),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: ListView(
                  children: [
                    for (var index = 0; index < pages.length; index++) ...[
                      if (pages[index].group != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 18, 10, 8),
                          child: Text(
                            pages[index].group!,
                            style: AppTextStyles.caption,
                          ),
                        ),
                      _NavItem(
                        page: pages[index],
                        selected: selectedIndex == index,
                        onTap: () => onSelect(index),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.installerMode});

  final bool installerMode;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
            child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 22),
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
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.page,
    required this.selected,
    required this.onTap,
  });

  final _ShellPage page;
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
                  selected ? page.selectedIcon : page.icon,
                  size: 20,
                  color: selected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    page.label,
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
  const _ConnectionFooter();

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
