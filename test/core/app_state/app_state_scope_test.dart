import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilowatts_mobile/core/app_state/app_state.dart';
import 'package:kilowatts_mobile/core/app_state/app_state_scope.dart';
import 'package:kilowatts_mobile/core/services/local_state_service.dart';
import 'package:kilowatts_mobile/core/services/mqtt_service.dart';
import 'package:kilowatts_mobile/features/auth/data/auth_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

/// Guards against regressing the exact compile break this pass fixed:
/// `KilowattsApp`/`AppRouter` previously threaded three raw services by
/// constructor while `main.dart` had already moved to building one shared
/// [AppState] — nothing wired it to the widget tree. This asserts the
/// [AppStateScope] mechanism that replaced that threading actually works:
/// a descendant widget can read the one [AppState] instance installed at
/// the root, at any depth, without any constructor plumbing.
void main() {
  testWidgets('a deeply nested descendant reads the AppState installed at the root', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final auth = _MockFirebaseAuth();
    when(() => auth.userChanges()).thenAnswer((_) => const Stream.empty());
    when(() => auth.currentUser).thenReturn(null);

    final appState = AppState(
      authService: AuthService(firebaseAuth: auth),
      mqttService: MqttService(),
      localStateService: LocalStateService(),
    );
    addTearDown(appState.dispose);

    AppState? observed;

    await tester.pumpWidget(
      AppStateScope(
        appState: appState,
        child: const MaterialApp(
          home: _NestedReader(),
        ),
      ),
    );

    final finder = find.byType(_NestedReader);
    final state = tester.state<_NestedReaderState>(finder);
    observed = state.appState;

    expect(observed, same(appState));
  });
}

class _NestedReader extends StatefulWidget {
  const _NestedReader();

  @override
  State<_NestedReader> createState() => _NestedReaderState();
}

class _NestedReaderState extends State<_NestedReader> {
  late final AppState appState = AppStateScope.of(context);

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(appState.connectionStatus.value.name)));
  }
}
