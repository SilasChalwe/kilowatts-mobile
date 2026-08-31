import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum KilowattsRole { homeowner, installer, unassigned }

class InstallationAccess {
  const InstallationAccess({
    required this.role,
    this.uid,
    this.installationId,
    this.fullName,
    this.phoneNumber,
  });

  final KilowattsRole role;
  final String? uid;
  final String? installationId;
  final String? fullName;
  final String? phoneNumber;

  bool get hasInstallation =>
      installationId != null && installationId!.isNotEmpty;
}

class KilowattsUserAccess {
  const KilowattsUserAccess({
    required this.uid,
    required this.email,
    required this.role,
    this.installationId,
    this.fullName,
    this.phoneNumber,
  });

  final String uid;
  final String email;
  final KilowattsRole role;
  final String? installationId;
  final String? fullName;
  final String? phoneNumber;

  String get displayName {
    final name = fullName?.trim() ?? '';
    return name.isEmpty ? email : name;
  }

  String get initials {
    final parts = displayName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  String get roleLabel => switch (role) {
    KilowattsRole.installer => 'Installer',
    KilowattsRole.homeowner => 'Homeowner',
    KilowattsRole.unassigned => 'Awaiting handover',
  };
}

class InstallationAsset {
  const InstallationAsset({
    required this.id,
    required this.deviceId,
    required this.name,
    required this.type,
  });

  final String id;
  final String deviceId;
  final String name;
  final String type;
}

/// Firestore authorization and commissioning boundary.
///
/// Profiles are keyed by Firebase Auth UID. A homeowner points to a separate
/// installation; MQTT, assets, presence and telemetry belong to that
/// installation rather than to a person.
class AccessControlService {
  AccessControlService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');
  CollectionReference<Map<String, dynamic>> get _installations =>
      _firestore.collection('installations');

  static KilowattsRole _parseRole(Object? value) =>
      switch (value?.toString().toLowerCase()) {
        'installer' => KilowattsRole.installer,
        'homeowner' => KilowattsRole.homeowner,
        _ => KilowattsRole.unassigned,
      };

  static String? _optionalString(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static InstallationAccess _accessFromData(
    String uid,
    Map<String, dynamic>? data,
  ) {
    final values = data ?? const <String, dynamic>{};
    return InstallationAccess(
      role: _parseRole(values['role']),
      uid: uid,
      installationId: _optionalString(values['installationId']),
      fullName: _optionalString(values['fullName']),
      phoneNumber: _optionalString(values['phoneNumber']),
    );
  }

  Future<InstallationAccess> resolve(User? user) async {
    if (user == null) {
      return const InstallationAccess(role: KilowattsRole.unassigned);
    }
    final snapshot = await _users.doc(user.uid).get();
    return _accessFromData(user.uid, snapshot.data());
  }

  Stream<InstallationAccess> watchCurrent(User? user) {
    if (user == null) {
      return Stream.value(
        const InstallationAccess(role: KilowattsRole.unassigned),
      );
    }
    return _users
        .doc(user.uid)
        .snapshots()
        .map((snapshot) => _accessFromData(user.uid, snapshot.data()));
  }

  Stream<List<KilowattsUserAccess>> watchUsers() {
    return _users.snapshots().map((snapshot) {
      final users = snapshot.docs.map((doc) {
        final data = doc.data();
        return KilowattsUserAccess(
          uid: doc.id,
          email: _optionalString(data['email']) ?? 'Unknown account',
          role: _parseRole(data['role']),
          installationId: _optionalString(data['installationId']),
          fullName: _optionalString(data['fullName']),
          phoneNumber: _optionalString(data['phoneNumber']),
        );
      }).toList();
      users.sort(
        (a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );
      return users;
    });
  }

  /// Creates or updates an installation and completes homeowner handover in
  /// one transaction. Firestore generates the installation ID independently
  /// of the homeowner UID.
  Future<String> assignHomeowner({
    required String uid,
    required String installationName,
  }) async {
    final normalizedUid = uid.trim();
    final normalizedName = installationName.trim();
    if (normalizedUid.isEmpty) {
      throw ArgumentError('A registered user is required.');
    }
    if (normalizedName.length < 2) {
      throw ArgumentError('An installation name is required.');
    }

    final userRef = _users.doc(normalizedUid);
    final newInstallationRef = _installations.doc();
    return _firestore.runTransaction((transaction) async {
      final user = await transaction.get(userRef);
      if (!user.exists) {
        throw StateError('The user account no longer exists.');
      }
      final existingId = _optionalString(user.data()?['installationId']);
      final installationRef = existingId == null
          ? newInstallationRef
          : _installations.doc(existingId);
      transaction.set(installationRef, {
        'name': normalizedName,
        'ownerUid': normalizedUid,
        'status': 'active',
        if (existingId == null) 'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      transaction.update(userRef, {
        'role': 'homeowner',
        'installationId': installationRef.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return installationRef.id;
    });
  }

  Future<void> revokeAccess(String uid) async {
    final userRef = _users.doc(uid.trim());
    await _firestore.runTransaction((transaction) async {
      final user = await transaction.get(userRef);
      if (!user.exists) return;
      final installationId = _optionalString(user.data()?['installationId']);
      if (installationId != null) {
        transaction.set(_installations.doc(installationId), {
          'status': 'unassigned',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      transaction.update(userRef, {
        'role': 'unassigned',
        'installationId': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Stream<List<InstallationAsset>> watchAssets(String installationId) {
    return _installations
        .doc(installationId)
        .collection('assets')
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => InstallationAsset(
                  id: doc.id,
                  deviceId: doc.data()['deviceId']?.toString() ?? '',
                  name: doc.data()['name']?.toString() ?? '',
                  type: doc.data()['type']?.toString() ?? 'controller',
                ),
              )
              .toList(growable: false),
        );
  }

  Future<void> addAsset({
    required String installationId,
    required String deviceId,
    required String name,
    required String type,
  }) async {
    final normalizedDeviceId = deviceId.trim();
    final normalizedName = name.trim();
    if (normalizedDeviceId.isEmpty || normalizedName.isEmpty) {
      throw ArgumentError('Asset name and device ID are required.');
    }
    await _installations.doc(installationId).collection('assets').add({
      'deviceId': normalizedDeviceId,
      'name': normalizedName,
      'type': type.trim().toLowerCase(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeAsset({
    required String installationId,
    required String assetId,
  }) => _installations
      .doc(installationId)
      .collection('assets')
      .doc(assetId)
      .delete();
}
