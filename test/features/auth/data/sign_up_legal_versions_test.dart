import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/auth/social_auth_client.dart';
import 'package:sacdia_app/core/auth/social_credential.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/core/storage/secure_storage.dart';
import 'package:sacdia_app/features/auth/data/datasources/auth_remote_data_source.dart';

import '../../../support/http_adapters.dart';

class _MemorySecureStorage implements SecureStorage {
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

class _NoSocialAuthClient implements SocialAuthClient {
  @override
  Future<SocialCredential?> signIn(SocialProvider provider) async => null;
  @override
  bool supports(SocialProvider provider) => false;
}

void main() {
  test('register body carries the accepted legal versions', () async {
    final adapter = JsonAdapter(201, {
      'success': true,
      'userId': 'user-1',
    });
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000'))
      ..httpClientAdapter = adapter;
    final dataSource = AuthRemoteDataSourceImpl(
      dio: dio,
      baseUrl: 'http://localhost:3000',
      secureStorage: _MemorySecureStorage(),
      socialAuth: _NoSocialAuthClient(),
    );

    await dataSource.signUpWithEmailAndPassword(
      email: 'ana@example.com',
      password: 'Password123',
      name: 'Ana',
      paternalSurname: 'Perez',
      maternalSurname: 'Lopez',
      acceptedTermsVersion: '1.0.0-store',
      acceptedPrivacyVersion: '1.0.0-store',
    );

    expect(adapter.lastRequest?.uri.path, endsWith('/auth/register'));
    expect(adapter.lastRequest?.data, {
      'email': 'ana@example.com',
      'password': 'Password123',
      'name': 'Ana',
      'paternal_last_name': 'Perez',
      'maternal_last_name': 'Lopez',
      'accepted_terms_version': '1.0.0-store',
      'accepted_privacy_version': '1.0.0-store',
    });
  });

  AuthRemoteDataSourceImpl build(JsonAdapter adapter) {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000'))
      ..httpClientAdapter = adapter;
    return AuthRemoteDataSourceImpl(
      dio: dio,
      baseUrl: 'http://localhost:3000',
      secureStorage: _MemorySecureStorage(),
      socialAuth: _NoSocialAuthClient(),
    );
  }

  test('register body carries the birthday only when given', () async {
    final adapter = JsonAdapter(201, {'success': true, 'userId': 'user-1'});

    await build(adapter).signUpWithEmailAndPassword(
      email: 'ana@example.com',
      password: 'Password123',
      name: 'Ana',
      paternalSurname: 'Perez',
      maternalSurname: 'Lopez',
      acceptedTermsVersion: '1.0.0-store',
      acceptedPrivacyVersion: '1.0.0-store',
      birthday: '2000-01-02',
    );

    expect((adapter.lastRequest?.data as Map)['birthday'], '2000-01-02');
  });

  test('a 422 keeps the business code so the form can show the age gate',
      () async {
    final adapter = JsonAdapter(422, {
      'status': 'error',
      'code': 'AUTH_REGISTRATION_AGE_BELOW_MINIMUM',
      'message': 'Pide a tu tutor que te registre',
      'details': {'ignored': true},
    });

    await expectLater(
      build(adapter).signUpWithEmailAndPassword(
        email: 'ana@example.com',
        password: 'Password123',
        name: 'Ana',
        paternalSurname: 'Perez',
        maternalSurname: 'Lopez',
        acceptedTermsVersion: '1.0.0-store',
        acceptedPrivacyVersion: '1.0.0-store',
        birthday: '2018-01-02',
      ),
      throwsA(
        isA<AuthException>().having((e) => e.code, 'code', 422).having(
              (e) => e.errorCode,
              'errorCode',
              'AUTH_REGISTRATION_AGE_BELOW_MINIMUM',
            ),
      ),
    );
  });
}
