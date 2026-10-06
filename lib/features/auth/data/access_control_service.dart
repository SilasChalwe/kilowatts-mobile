import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum KilowattsRole { homeowner, installer, unassigned }

class InstallationAccess {
  const InstallationAccess({
    required this.role,
    this.uid,
    this.fullName,
    this.phoneNumber,
  });

  final KilowattsRole role;
  final String? uid;
  final String? fullName;
  final String? phoneNumber;

  /// A homeowner's installation is identified by their own Firebase Auth
  /// UID — there is no separately generated installation ID.
  String? get installationId =>
      role == KilowattsRole.homeowner && uid != null && uid!.isNotEmpty
      ? uid
      : null;

  bool get hasInstallation => installationId != null;
}

class KilowattsUserAccess {
  const KilowattsUserAccess({
    this.uid,
    required this.email,
    required this.role,
    this.fullName,
    this.phoneNumber,
  });

  /// Null until the account has signed in at least once (profile docs
  /// created by hand in the Firebase Console won't have this field yet).
  final String? uid;
  final String email;
  final KilowattsRole role;
  final String? fullName;
  final String? phoneNumber;

  String? get installationId =>
      role == KilowattsRole.homeowner && uid != null && uid!.isNotEmpty
      ? uid
      : null;

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
    KilowattsRole.unassigned => 'Unassigned',
  };
}

/// Firestore authorization and commissioning boundary.
///
/// Profiles are keyed by the account's lowercased email address. A
/// homeowner's installation is identified by their own Firebase Auth UID
/// rather than a separately generated ID; MQTT, assets, presence and
/// telemetry belong to that installation. See docs/firestore-schema.md.
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

  static String _userDocId(String email) => email.trim().toLowerCase();

  static InstallationAccess _accessFromData(
    String? uid,
    Map<String, dynamic>? data,
  ) {
    final values = data ?? const <String, dynamic>{};
    return InstallationAccess(
      role: _parseRole(values['role']),
      uid: uid,
      fullName: _optionalString(values['fullName']),
      phoneNumber: _optionalString(values['phoneNumber']),
    );
  }

  Future<InstallationAccess> resolve(User? user) async {
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) {
      return InstallationAccess(role: KilowattsRole.unassigned, uid: user?.uid);
    }
    final snapshot = await _users.doc(_userDocId(email)).get();
    return _accessFromData(user.uid, snapshot.data());
  }

  Stream<InstallationAccess> watchCurrent(User? user) {
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) {
      return Stream.value(
        InstallationAccess(role: KilowattsRole.unassigned, uid: user?.uid),
      );
    }
    return _users
        .doc(_userDocId(email))
        .snapshots()
        .map((snapshot) => _accessFromData(user.uid, snapshot.data()));
  }

  Stream<List<KilowattsUserAccess>> watchUsers() {
    return _users.snapshots().map((snapshot) {
      final users = snapshot.docs.map((doc) {
        final data = doc.data();
        return KilowattsUserAccess(
          uid: _optionalString(data['uid']),
          email: _optionalString(data['email']) ?? doc.id,
          role: _parseRole(data['role']),
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

  /// Sets a user's role. Promoting to [KilowattsRole.homeowner] ensures
  /// their `installations/{uid}` doc exists and is active; moving a
  /// homeowner to any other role marks their installation unassigned.
  /// A homeowner's own name/phone number stay theirs to edit — this only
  /// ever touches `role` (plus `uid`, to self-heal a hand-authored doc).
  Future<void> setRole({
    required String email,
    required String uid,
    required KilowattsRole role,
  }) async {
    final normalizedEmail = _userDocId(email);
    final normalizedUid = uid.trim();
    if (!normalizedEmail.contains('@')) {
      throw ArgumentError('A valid account email is required.');
    }
    if (normalizedUid.isEmpty) {
      throw ArgumentError('A registered user is required.');
    }

    final userRef = _users.doc(normalizedEmail);
    final installationRef = _installations.doc(normalizedUid);
    await _firestore.runTransaction((transaction) async {
      final user = await transaction.get(userRef);
      if (!user.exists) {
        throw StateError('The user account no longer exists.');
      }
      final wasHomeowner = user.data()?['role'] == 'homeowner';
      if (role == KilowattsRole.homeowner) {
        final installation = await transaction.get(installationRef);
        transaction.set(installationRef, {
          'ownerUid': normalizedUid,
          'status': 'active',
          if (!installation.exists) 'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else if (wasHomeowner) {
        transaction.set(installationRef, {
          'status': 'unassigned',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      transaction.update(userRef, {
        'role': role.name,
        'uid': normalizedUid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
