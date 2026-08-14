abstract final class Validators {
  static final RegExp _emailPattern = RegExp(r"^[^\s@]+@[^\s@]+\.[^\s@]+$");

  static String? requiredField(String? value, {String fieldName = 'Field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required.';
    }
    return null;
  }

  static String? fullName(String? value) {
    final requiredError = requiredField(value, fieldName: 'Full name');
    if (requiredError != null) {
      return requiredError;
    }

    final normalized = value!.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.length < 2) {
      return 'Enter your full name.';
    }
    return null;
  }

  static String? email(String? value) {
    final requiredError = requiredField(value, fieldName: 'Email');
    if (requiredError != null) {
      return requiredError;
    }

    final normalized = value!.trim();
    if (normalized.length > 254 || !_emailPattern.hasMatch(normalized)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  static String? password(String? value) {
    final requiredError = requiredField(value, fieldName: 'Password');
    if (requiredError != null) {
      return requiredError;
    }

    final password = value!;
    if (password.length < 8) {
      return 'Use at least 8 characters.';
    }
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Add at least one uppercase letter.';
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'Add at least one lowercase letter.';
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'Add at least one number.';
    }
    if (password.contains(RegExp(r'\s'))) {
      return 'Password cannot contain spaces.';
    }
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    final requiredError = requiredField(value, fieldName: 'Confirm password');
    if (requiredError != null) {
      return requiredError;
    }
    if (value != password) {
      return 'Passwords do not match.';
    }
    return null;
  }
}
