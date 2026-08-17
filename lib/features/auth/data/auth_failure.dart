import 'package:firebase_auth/firebase_auth.dart';

enum AuthAction { signIn, register, passwordReset, verification, general }

abstract final class AuthFailure {
  static String message(
    Object error, {
    AuthAction action = AuthAction.general,
  }) {
    if (error is! FirebaseAuthException) {
      return 'Something went wrong. Please try again.';
    }

    switch (error.code) {
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'network-request-failed':
        return 'Unable to reach the authentication service. Check your connection and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a little before trying again.';
      case 'user-disabled':
        return 'This account is currently unavailable. Contact support if this is unexpected.';
      case 'weak-password':
        return 'Choose a stronger password.';
      case 'operation-not-allowed':
        return 'Email and password sign-in is not enabled for this app.';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return action == AuthAction.signIn
            ? 'Email or password is incorrect.'
            : 'We could not complete that request.';
      case 'email-already-in-use':
        return 'Unable to create an account with those details. Try signing in or resetting your password.';
      case 'requires-recent-login':
        return 'Please sign in again before continuing.';
      default:
        return 'We could not complete that request. Please try again.';
    }
  }
}
