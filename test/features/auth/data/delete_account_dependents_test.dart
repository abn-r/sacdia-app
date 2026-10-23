import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/auth/social_auth_client.dart';
import 'package:sacdia_app/core/auth/social_credential.dart';
import 'package:sacdia_app/core/constants/app_constants.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/core/storage/secure_storage.dart';
import 'package:sacdia_app/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:sacdia_app/features/auth/domain/entities/delete_account_reauth.dart';

import '../../../support/http_adapters.dart';

class _Storage implements SecureStorage {
  final _store = <String, String>{AppConstants.tokenKey: 'jwt'};

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

class _NoSocial implements SocialAuthClient {
  @override
  Future<SocialCredential?> signIn(SocialProvider provider) async => null;
  @override
  bool supports(SocialProvider provider) => false;
}

AuthRemoteDataSourceImpl _build(JsonAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000'))
    ..httpClientAdapter = adapter;
  return AuthRemoteDataSourceImpl(
    dio: dio,
    baseUrl: 'http://localhost:3000',
    secureStorage: _Storage(),
    socialAuth: _NoSocial(),
  );
}

void main() {
  group('DeleteAccountReauth body', () {
    test('never sends acknowledge_dependents unless the guardian accepted', () {
      expect(const PasswordReauth('pw').toBody(), {'password': 'pw'});
    });

    test('acknowledged() adds acknowledge_dependents next to the credentials',
        () {
      final body = const PasswordReauth('pw').acknowledged().toBody();

      expect(body, {'password': 'pw', 'acknowledge_dependents': true});
    });

    test('a social reauth keeps its credentials when acknowledged', () {
      const credential = SocialCredential(
        provider: SocialProvider.google,
        idToken: 'g-token',
        nonce: 'n-1',
      );
      final plain = const SocialReauth(credential).toBody();
      final acked = const SocialReauth(credential).acknowledged().toBody();

      expect(acked, {...plain, 'acknowledge_dependents': true});
      expect(
          const SocialReauth(credential).acknowledged(), isA<SocialReauth>());
    });
  });

  group('deleteAccount datasource', () {
    test('sends acknowledge_dependents: true when acknowledged', () async {
      final adapter = JsonAdapter(204, const {});

      await _build(adapter).deleteAccount(
        const PasswordReauth('pw').acknowledged(),
      );

      expect(adapter.lastRequest!.method, 'DELETE');
      expect(adapter.lastRequest!.data, {
        'password': 'pw',
        'acknowledge_dependents': true,
      });
    });

    test('409 ACK_REQUIRED keeps the code and never reads details', () async {
      final adapter = JsonAdapter(409, {
        'status': 'error',
        'statusCode': 409,
        'code': 'AUTH_DELETE_DEPENDENTS_ACK_REQUIRED',
        'message': 'raw server text',
        'details': {'dependents_count': 2},
      });

      await expectLater(
        _build(adapter).deleteAccount(const PasswordReauth('pw')),
        throwsA(
          isA<AuthException>()
              .having((e) => e.code, 'code', 409)
              .having(
                (e) => e.errorCode,
                'errorCode',
                kDeleteDependentsAckRequiredCode,
              )
              // Mensaje localizado de la app, no el texto crudo del servidor.
              .having((e) => e.message, 'message', isNot('raw server text')),
        ),
      );
    });

    test('a wrong password still reads as a rejected re-auth', () async {
      final adapter = JsonAdapter(401, {
        'code': 'AUTH_INVALID_PASSWORD',
        'message': 'x',
      });

      await expectLater(
        _build(adapter).deleteAccount(const PasswordReauth('nope')),
        throwsA(
          isA<AuthException>().having(
            (e) => e.errorCode,
            'errorCode',
            'AUTH_INVALID_PASSWORD',
          ),
        ),
      );
    });
  });

  test('DeleteAccountResult.needsDependentsAck only for the ack code', () {
    expect(
      const DeleteAccountResult(
        errorMessage: 'x',
        errorCode: kDeleteDependentsAckRequiredCode,
      ).needsDependentsAck,
      isTrue,
    );
    expect(
      const DeleteAccountResult(errorMessage: 'x', errorCode: 'OTHER')
          .needsDependentsAck,
      isFalse,
    );
    expect(const DeleteAccountResult.success().isSuccess, isTrue);
  });
}
