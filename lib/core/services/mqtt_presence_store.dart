import 'package:cloud_firestore/cloud_firestore.dart';

class MqttPresence {
  const MqttPresence({
    required this.online,
    required this.status,
    this.lastSeen,
  });

  final bool online;
  final String status;
  final DateTime? lastSeen;

  bool get isFresh =>
      lastSeen != null &&
      DateTime.now().difference(lastSeen!) < const Duration(minutes: 2);
}

class MqttPresenceStore {
  MqttPresenceStore({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _document(
    String installationId,
    String userUid,
  ) => _firestore
      .collection('installations')
      .doc(installationId)
      .collection('presence')
      .doc(userUid);

  Future<void> write({
    required String installationId,
    required String userUid,
    required String status,
  }) => _document(installationId, userUid).set({
    'online': status == 'connected',
    'status': status,
    'lastSeen': FieldValue.serverTimestamp(),
  });

  Stream<MqttPresence?> watch({
    required String installationId,
    required String userUid,
  }) => _document(installationId, userUid).snapshots().map((snapshot) {
    final data = snapshot.data();
    if (data == null) return null;
    final timestamp = data['lastSeen'];
    final lastSeen = timestamp is Timestamp ? timestamp.toDate() : null;
    return MqttPresence(
      online: data['online'] == true,
      status: data['status']?.toString() ?? 'disconnected',
      lastSeen: lastSeen,
    );
  });
}
