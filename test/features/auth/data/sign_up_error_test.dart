import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/auth/social_auth_client.dart';
import 'package:sacdia_app/core/auth/social_credential.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/core/storage/secure_storage.dart';
import 'package:sacdia_app/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/http_adapters.dart';

class _MemoryStorage implements SecureStorage {
  final _store = <String, String>{};
  @override
  Future<void> write(String key, String value) async => _store[key] = value;
  @override
  Future<String?> read(String key) async => _store[key];
  @override
  Future<bool> contains(String key) async => _store.containsKey(key);
  @override
  Future<void> delete(String key) async => _store.remove(key);
  @override
  Future<void> deleteAll() async => _store.clear();
  @override
  Future<Map<String, String>> readAll() async => Map.unmodifiable(_store);
}

class _NoSocialAuth implements SocialAuthClient {
  @override
  Future<SocialCredential?> signIn(SocialProvider provider) async => null;
  @override
  bool supports(SocialProvider provider) => false;
}

AuthRemoteDataSourceImpl _dataSource(HttpClientAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  return AuthRemoteDataSourceImpl(
    dio: dio,
    baseUrl: 'http://localhost:3000',
    secureStorage: _MemoryStorage(),
    socialAuth: _NoSocialAuth(),
  );
}

Future<Object?> _signUpError(HttpClientAdapter adapter) async {
  try {
    await _dataSource(adapter).signUpWithEmailAndPassword(
      email: 'qa@sacdia.test',
      password: 'Short1aaaaa',
      name: 'Qa',
      paternalSurname: 'Registro',
      maternalSurname: 'Prueba',
      acceptedTermsVersion: '2.0.0-family',
      acceptedPrivacyVersion: '2.0.0-family',
      birthday: '2000-10-10',
    );
  } catch (e) {
    return e;
  }
  return null;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  group('signUpWithEmailAndPassword error mapping', () {
    test(
        'a 400 with class-validator details becomes an AuthException '
        'with a readable message', () async {
      // Real shape of the backend 400 for a weak password: `message` is a
      // LIST of validation errors, not a string.
      final error = await _signUpError(JsonAdapter(400, {
        'statusCode': 400,
        'message': [
          {
            'property': 'password',
            'children': <dynamic>[],
            'constraints': {
              'matches': 'La contraseña debe incluir: mayúscula, minúscula, '
                  'número y carácter especial (@\$!%*?&)',
            },
          },
        ],
      }));

      expect(error, isA<AuthException>());
      final auth = error! as AuthException;
      expect(auth.code, 400);
      expect(
        auth.message,
        'La contraseña debe incluir: mayúscula, minúscula, número y '
        'carácter especial (@\$!%*?&)',
      );
    });

    test('a 400 with a string message keeps it', () async {
      final error = await _signUpError(JsonAdapter(400, {
        'statusCode': 400,
        'code': 'AUTH_EMAIL_TAKEN',
        'message': 'El correo ya está registrado',
      }));

      expect(error, isA<AuthException>());
      final auth = error! as AuthException;
      expect(auth.message, 'El correo ya está registrado');
      expect(auth.errorCode, 'AUTH_EMAIL_TAKEN');
    });

    test(
        'an existing email (401 AUTH_INVALID_CREDENTIALS) gets a register '
        'message, not "invalid credentials"', () async {
      final error = await _signUpError(JsonAdapter(401, {
        'statusCode': 401,
        'code': 'AUTH_INVALID_CREDENTIALS',
        'message': 'Credenciales inválidas',
      }));

      expect(error, isA<AuthException>());
      final auth = error! as AuthException;
      expect(auth.code, 401);
      expect(auth.errorCode, 'AUTH_INVALID_CREDENTIALS');
      expect(auth.message, 'errors.register_email_unavailable'.tr());
    });
  });

  group('resetPasswordErrorMessage', () {
    test('never shows the English backend text for a 503', () {
      final message = resetPasswordErrorMessage(503, true);
      expect(message, isNot(contains('temporarily unavailable')));
      expect(message, 'auth.forgot_password_unavailable'.tr());
    });

    test('maps rate limit, network and other errors', () {
      expect(resetPasswordErrorMessage(429, true),
          'errors.too_many_attempts'.tr());
      expect(
          resetPasswordErrorMessage(null, false), 'common.error_network'.tr());
      expect(resetPasswordErrorMessage(500, true),
          'auth.forgot_password_error'.tr());
    });
  });
}
