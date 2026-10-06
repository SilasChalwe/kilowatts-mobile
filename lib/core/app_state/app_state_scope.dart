import 'package:flutter/widgets.dart';

import 'app_state.dart';

/// Exposes the single app-wide [AppState] instance to every widget below it
/// without threading it through constructors. Installed once at the root by
/// [KilowattsApp]; screens read it via [AppStateScope.of].
class AppStateScope extends InheritedWidget {
  const AppStateScope({
    required this.appState,
    required super.child,
    super.key,
  });

  final AppState appState;

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'No AppStateScope found in context');
    return scope!.appState;
  }

  @override
  bool updateShouldNotify(AppStateScope oldWidget) =>
      appState != oldWidget.appState;
}
