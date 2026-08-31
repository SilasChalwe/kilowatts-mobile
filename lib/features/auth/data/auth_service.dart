import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  AuthService({FirebaseAuth? firebaseAuth, this._firestore})
    : _auth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore? _firestore;
  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;

  Stream<User?> get userChanges => _auth.userChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> signIn({required String email, required String password}) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user != null) await _ensureProfile(user);
  }

  Future<void> createAccount({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;
    if (user == null) {
      throw StateError('Firebase created no user for the new account.');
    }

    await user.updateDisplayName(fullName.trim());
    await _ensureProfile(user, fullName: fullName.trim());
    await user.sendEmailVerification();
    await user.reload();
  }

  Future<void> _ensureProfile(User user, {String? fullName}) async {
    final email = user.email?.trim();
    if (email == null || email.isEmpty) return;
    final profile = firestore.collection('users').doc(email.toLowerCase());
    final existing = await profile.get();
    await profile.set({
      'uid': user.uid,
      'email': email,
      if (fullName != null && fullName.isNotEmpty) 'fullName': fullName,
      'updatedAt': FieldValue.serverTimestamp(),
      if (!existing.exists) 'role': 'unassigned',
    }, SetOptions(merge: true));
  }

  Future<void> sendPasswordReset({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      // Do not disclose whether an account exists for a submitted email.
      if (error.code == 'user-not-found') {
        return;
      }
      rethrow;
    }
  }

  Future<void> resendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user is available for verification.');
    }
    if (!user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  Future<bool> refreshEmailVerificationStatus() async {
    final user = _auth.currentUser;
    if (user == null) {
      return false;
    }

    await user.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  Future<void> signOut() => _auth.signOut();
}
