import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/utils/validators.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  group('Validators.validatePassword (new password, backend policy)', () {
    test('accepts a password that meets every backend rule', () {
      expect(Validators.validatePassword('Sacdia2026!x'), isNull);
    });

    test('rejects fewer than 12 characters (old 8-char rule)', () {
      expect(Validators.validatePassword('Sacdia26!'), isNotNull);
    });

    test('rejects a password without a special character', () {
      // Pasaba la regla anterior y el backend lo rechazaba con 400.
      expect(Validators.validatePassword('Sacdia2026abc'), isNotNull);
    });

    test('rejects special characters outside @\$!%*?&', () {
      expect(Validators.validatePassword('Sacdia2026#abc'), isNotNull);
    });

    test('rejects a first character the backend does not accept', () {
      expect(Validators.validatePassword('#Sacdia2026!x'), isNotNull);
    });

    test('rejects missing upper, lower or digit', () {
      expect(Validators.validatePassword('sacdia2026!xy'), isNotNull);
      expect(Validators.validatePassword('SACDIA2026!XY'), isNotNull);
      expect(Validators.validatePassword('SacdiaSacdia!x'), isNotNull);
    });

    test('rejects more than 128 characters', () {
      expect(Validators.validatePassword('Aa1!${'x' * 125}'), isNotNull);
    });
  });

  group('Validators.validateLoginPassword', () {
    test('only requires a value so older short passwords can still log in', () {
      expect(Validators.validateLoginPassword('Abc12345'), isNull);
      expect(Validators.validateLoginPassword(''), isNotNull);
      expect(Validators.validateLoginPassword(null), isNotNull);
    });
  });
}
