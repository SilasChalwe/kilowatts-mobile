import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/telemetry_point.dart';

class TelemetryHistorySnapshot {
  const TelemetryHistorySnapshot({
    this.soc = const [],
    this.batteryPower = const [],
    this.activeLoadPower = const [],
  });

  final List<TelemetryPoint> soc;
  final List<TelemetryPoint> batteryPower;
  final List<TelemetryPoint> activeLoadPower;

  static const empty = TelemetryHistorySnapshot();

  factory TelemetryHistorySnapshot.fromData(Map<String, dynamic>? data) {
    List<TelemetryPoint> points(String field) {
      final values = data?[field];
      if (values is! List) return const [];
      return values
          .whereType<Map>()
          .map((value) {
            try {
              return TelemetryPoint.fromJson(value.cast<String, dynamic>());
            } catch (_) {
              return null;
            }
          })
          .whereType<TelemetryPoint>()
          .toList(growable: false);
    }

    return TelemetryHistorySnapshot(
      soc: points('soc'),
      batteryPower: points('batteryPower'),
      activeLoadPower: points('activeLoadPower'),
    );
  }

  Map<String, dynamic> toData() => {
    'soc': soc.map((point) => point.toJson()).toList(growable: false),
    'batteryPower': batteryPower
        .map((point) => point.toJson())
        .toList(growable: false),
    'activeLoadPower': activeLoadPower
        .map((point) => point.toJson())
        .toList(growable: false),
  };
}

class TelemetryHistoryStore {
  TelemetryHistoryStore({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _document(String uid) => _firestore
      .collection('telemetry')
      .doc(uid)
      .collection('history')
      .doc('graphs');

  Future<TelemetryHistorySnapshot> read(String uid) async {
    final snapshot = await _document(uid).get();
    return TelemetryHistorySnapshot.fromData(snapshot.data());
  }

  Future<void> write(String uid, TelemetryHistorySnapshot history) => _document(
    uid,
  ).set({...history.toData(), 'updatedAt': FieldValue.serverTimestamp()});
}
