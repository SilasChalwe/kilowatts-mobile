import 'package:flutter_test/flutter_test.dart';
import 'package:kilowatts_mobile/core/utils/validators.dart';

void main() {
  group('Validators.email', () {
    test('accepts a valid email', () {
      expect(Validators.email('silas@example.com'), isNull);
    });

    test('rejects malformed email', () {
      expect(Validators.email('silas@'), isNotNull);
    });
  });

  group('Validators.password', () {
    test('accepts production baseline password', () {
      expect(Validators.password('Kilowatts2026'), isNull);
    });

    test('rejects short password', () {
      expect(Validators.password('Kw1'), isNotNull);
    });

    test('rejects password without uppercase', () {
      expect(Validators.password('kilowatts2026'), isNotNull);
    });

    test('rejects password without lowercase', () {
      expect(Validators.password('KILOWATTS2026'), isNotNull);
    });

    test('rejects password without number', () {
      expect(Validators.password('KilowattsApp'), isNotNull);
    });
  });

  test('confirmPassword rejects different passwords', () {
    expect(
      Validators.confirmPassword('Kilowatts2025', 'Kilowatts2026'),
      isNotNull,
    );
  });
}
