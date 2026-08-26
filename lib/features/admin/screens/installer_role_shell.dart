import 'package:flutter/material.dart';

import '../../shell/screens/main_shell.dart';

/// Installer access is a superset of the homeowner product.
///
/// There is intentionally no second Scaffold, drawer or app bar here. The
/// shared product shell owns navigation and exposes installer-only destinations
/// when [installerMode] is enabled.
class InstallerRoleShell extends StatelessWidget {
  const InstallerRoleShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const MainShell(installerMode: true);
  }
}
