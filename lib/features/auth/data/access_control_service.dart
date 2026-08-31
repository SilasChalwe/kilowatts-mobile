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

  bool get canManageHardware => role == KilowattsRole.installer;
  bool get canManageUsers => role == KilowattsRole.installer;
}

class KilowattsUserAccess {
  const KilowattsUserAccess({
    required this.email,
    required this.role,
    this.uid,
    this.fullName,
    this.phoneNumber,
  });

  final String email;
  final KilowattsRole role;
  final String? uid;
  final String? fullName;
  final String? phoneNumber;

  String get displayName {
    final name = fullName?.trim() ?? '';
    return name.isEmpty ? email : name;
  }

  String get initials {
    final name = fullName?.trim() ?? '';
    final source = name.isEmpty ? email : name;
    final parts = source
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  String get roleLabel {
    switch (role) {
      case KilowattsRole.installer:
        return 'Installer';
      case KilowattsRole.homeowner:
        return 'Homeowner';
      case KilowattsRole.unassigned:
        return 'Unassigned';
    }
  }
}

/// Firestore `users/{email}` is the Kilowatts user directory and authorization
/// boundary. Firebase Authentication proves identity; this document stores the
/// installer-managed profile and role. The Firebase Authentication UID is
/// also the household/installation key; there is no second assigned ID. Signed-in
/// users may read their own record, while only an existing installer may create,
/// edit or remove user records.
class AccessControlService {
  AccessControlService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  static String _docIdFor(String email) => email.trim().toLowerCase();

  static KilowattsRole _parseRole(Object? value) {
    switch (value?.toString().toLowerCase()) {
      case 'installer':
      case 'admin':
        return KilowattsRole.installer;
      case 'homeowner':
        return KilowattsRole.homeowner;
      default:
        return KilowattsRole.unassigned;
    }
  }

  static String? _optionalString(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static InstallationAccess _accessFromData(
    Map<String, dynamic>? data, {
    String? authenticatedUid,
  }) {
    final values = data ?? const <String, dynamic>{};
    return InstallationAccess(
      role: _parseRole(values['role']),
      uid: authenticatedUid ?? _optionalString(values['uid']),
      fullName: _optionalString(values['fullName']),
      phoneNumber: _optionalString(values['phoneNumber']),
    );
  }

  Future<InstallationAccess> resolve(User? user) async {
    final email = user?.email;
    final authenticatedUid = user?.uid;
    if (email == null || authenticatedUid == null) {
      return const InstallationAccess(role: KilowattsRole.unassigned);
    }

    final snapshot = await _users.doc(_docIdFor(email)).get();
    if (snapshot.exists) {
      return _accessFromData(
        snapshot.data(),
        authenticatedUid: authenticatedUid,
      );
    }

    final byUid = await _users
        .where('uid', isEqualTo: authenticatedUid)
        .limit(1)
        .get();
    return _accessFromData(
      byUid.docs.isEmpty ? null : byUid.docs.first.data(),
      authenticatedUid: authenticatedUid,
    );
  }

  Stream<InstallationAccess> watchCurrent(User? user) {
    final email = user?.email;
    final authenticatedUid = user?.uid;
    if (email == null || authenticatedUid == null) {
      return Stream.value(
        const InstallationAccess(role: KilowattsRole.unassigned),
      );
    }
    return _users
        .doc(_docIdFor(email))
        .snapshots()
        .map(
          (snapshot) => _accessFromData(
            snapshot.data(),
            authenticatedUid: authenticatedUid,
          ),
        );
  }

  /// Live installer view of the Firestore user directory. The UI intentionally
  /// does not invent local fallback users when Firestore has not returned data.
  Stream<List<KilowattsUserAccess>> watchUsers() {
    return _users.snapshots().map((snapshot) {
      final users = snapshot.docs.map((doc) {
        final data = doc.data();
        return KilowattsUserAccess(
          email: doc.id,
          role: _parseRole(data['role']),
          uid: _optionalString(data['uid']),
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

  /// Registers a user or updates an existing user's profile/access record.
  /// Firestore rules allow this only for an existing installer account.
  Future<void> saveUser({
    required String email,
    required String fullName,
    required String phoneNumber,
    required String role,
  }) {
    final normalizedEmail = _docIdFor(email);
    final normalizedName = fullName.trim();
    final normalizedPhone = phoneNumber.trim();
    final normalizedRole = role.trim().toLowerCase();

    if (normalizedEmail.isEmpty || !normalizedEmail.contains('@')) {
      throw ArgumentError('A valid account email is required.');
    }
    if (normalizedName.length < 2) {
      throw ArgumentError('A user name is required.');
    }
    if (normalizedPhone.length < 7) {
      throw ArgumentError('A valid phone number is required.');
    }
    if (normalizedRole != 'installer' &&
        normalizedRole != 'homeowner' &&
        normalizedRole != 'unassigned') {
      throw ArgumentError('Role must be installer, homeowner, or unassigned.');
    }

    return _users.doc(normalizedEmail).set({
      'fullName': normalizedName,
      'phoneNumber': normalizedPhone,
      'role': normalizedRole,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Role-only update retained for existing setup/integration call sites.
  /// It never fabricates missing name or phone profile values.
  Future<void> assignRole({required String email, required String role}) {
    final normalizedEmail = _docIdFor(email);
    final normalizedRole = role.trim().toLowerCase();
    if (normalizedEmail.isEmpty || !normalizedEmail.contains('@')) {
      throw ArgumentError('A valid account email is required.');
    }
    if (normalizedRole != 'installer' && normalizedRole != 'homeowner') {
      throw ArgumentError('Role must be installer or homeowner.');
    }
    return _users.doc(normalizedEmail).set({
      'role': normalizedRole,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Revokes access without deleting the user record: the Firestore rules
  /// grant installers update rights but no delete rights on this collection,
  /// and a soft revoke keeps the profile (name/phone/history) as an audit
  /// trail. A revoked account lands on the "unassigned" access-required
  /// screen the next time it reads its own profile.
  Future<void> revokeAccess(String email) => _users.doc(_docIdFor(email)).set({
    'role': 'unassigned',
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}
