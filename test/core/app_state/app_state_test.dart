import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilowatts_mobile/core/app_state/app_state.dart';
import 'package:kilowatts_mobile/core/services/local_state_service.dart';
import 'package:kilowatts_mobile/core/services/mqtt_service.dart';
import 'package:kilowatts_mobile/features/alerts/models/alert_model.dart';
import 'package:kilowatts_mobile/features/auth/data/access_control_service.dart';
import 'package:kilowatts_mobile/features/auth/data/auth_service.dart';
import 'package:kilowatts_mobile/features/loads/models/load_model.dart';
import 'package:kilowatts_mobile/features/system/models/system_state_model.dart';
import 'package:kilowatts_mobile/features/system/models/topology_model.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockAccessControlService extends Mock implements AccessControlService {}

class _FakeMqttService extends MqttService {
  final systemStateController =
      StreamController<SystemStateModel>.broadcast(sync: true);
  final topologyController =
      StreamController<TopologyModel>.broadcast(sync: true);
  final loadsController = StreamController<List<LoadModel>>.broadcast(sync: true);
  final alertController = StreamController<AlertModel>.broadcast(sync: true);
  final connectionStatusController =
      StreamController<MqttConnectionStatus>.broadcast(sync: true);
  final centralAvailabilityController =
      StreamController<CentralAvailability>.broadcast(sync: true);

  @override
  Stream<SystemStateModel> get systemStateStream => systemStateController.stream;

  @override
  Stream<TopologyModel> get topologyStream => topologyController.stream;

  @override
  Stream<List<LoadModel>> get loadsStream => loadsController.stream;

  @override
  Stream<AlertModel> get alertStream => alertController.stream;

  @override
  Stream<MqttConnectionStatus> get connectionStatusStream =>
      connectionStatusController.stream;

  @override
  Stream<CentralAvailability> get centralAvailabilityStream =>
      centralAvailabilityController.stream;

  @override
  MqttConnectionStatus get currentStatus => MqttConnectionStatus.connected;

  @override
  Future<void> connect() async {}

  @override
  void dispose() {
    systemStateController.close();
    topologyController.close();
    loadsController.close();
    alertController.close();
    connectionStatusController.close();
    centralAvailabilityController.close();
  }
}

void main() {
  late _FakeMqttService mqtt;
  late AppState appState;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final auth = _MockFirebaseAuth();
    when(() => auth.userChanges()).thenAnswer((_) => const Stream.empty());
    when(() => auth.currentUser).thenReturn(null);

    mqtt = _FakeMqttService();
    appState = AppState(
      authService: AuthService(firebaseAuth: auth),
      mqttService: mqtt,
      localStateService: LocalStateService(),
      accessControlService: _MockAccessControlService(),
    );
  });

  tearDown(() {
    appState.dispose();
  });

  test('a system/state message updates systemState and lastLiveSystemUpdate only', () {
    var systemStateNotifications = 0;
    var loadsNotifications = 0;
    var topologyNotifications = 0;

    appState.systemState.addListener(() => systemStateNotifications++);
    appState.loads.addListener(() => loadsNotifications++);
    appState.topology.addListener(() => topologyNotifications++);

    expect(appState.lastLiveSystemUpdate.value, isNull);

    mqtt.systemStateController.add(
      SystemStateModel.fromJson(const {
        'battery': {
          'stateOfChargePercent': 55.0,
          'voltageVolts': 12.4,
          'currentAmps': 3.0,
        },
      }),
    );

    expect(systemStateNotifications, 1);
    expect(loadsNotifications, 0, reason: 'unrelated slices must not rebuild');
    expect(topologyNotifications, 0, reason: 'unrelated slices must not rebuild');
    expect(appState.systemState.value?.batterySocPercent, 55.0);
    expect(appState.lastLiveSystemUpdate.value, isNotNull);
  });

  test('SoC and battery-power history capture live system-state updates', () {
    mqtt.systemStateController.add(
      SystemStateModel.fromJson(const {
        'battery': {
          'stateOfChargePercent': 60.0,
          'voltageVolts': 12.0,
          'currentAmps': 5.0,
        },
      }),
    );

    expect(appState.socHistory.value, hasLength(1));
    expect(appState.socHistory.value.single.value, 60.0);
    expect(appState.batteryPowerHistory.value, hasLength(1));
    expect(appState.batteryPowerHistory.value.single.value, 60.0);
  });

  test('a loads message updates loads only, not systemState/topology', () {
    var systemStateNotifications = 0;
    appState.systemState.addListener(() => systemStateNotifications++);

    mqtt.loadsController.add([
      LoadModel.fromJson(const {
        'nodeMac': 'AA:BB:CC:DD:EE:FF',
        'relayPin': 4,
        'mode': 'AUTO_ON',
      }),
    ]);

    expect(appState.loads.value, hasLength(1));
    expect(systemStateNotifications, 0);
  });

  test(
    'isSystemStateLive requires a connected socket, an online Central and a recent update',
    () {
      expect(appState.isSystemStateLive, isFalse);

      mqtt.connectionStatusController.add(MqttConnectionStatus.connected);
      mqtt.systemStateController.add(SystemStateModel.fromJson(const {}));
      expect(
        appState.isSystemStateLive,
        isFalse,
        reason: 'Central has not reported itself online yet',
      );

      mqtt.centralAvailabilityController.add(CentralAvailability.online);
      expect(appState.isSystemStateLive, isTrue);
    },
  );

  test('acknowledgeAllAlerts marks every accumulated alert acknowledged', () {
    mqtt.alertController.add(
      AlertModel.fromJson(const {
        'severity': 'warning',
        'category': 'LOW_BATTERY',
        'message': 'test',
      }),
    );
    expect(appState.alerts.value.single.acknowledged, isFalse);

    appState.acknowledgeAllAlerts();
    expect(appState.alerts.value.single.acknowledged, isTrue);
  });
}
