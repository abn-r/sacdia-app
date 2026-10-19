import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/auth/acting_for_session.dart';
import 'package:sacdia_app/core/auth/social_auth_client.dart';
import 'package:sacdia_app/core/auth/social_credential.dart';
import 'package:sacdia_app/core/constants/app_constants.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/core/network/interceptors/acting_error_interceptor.dart';
import 'package:sacdia_app/core/network/interceptors/auth_interceptor.dart';
import 'package:sacdia_app/core/network/interceptors/error_interceptor.dart';
import 'package:sacdia_app/core/storage/secure_storage.dart';
import 'package:sacdia_app/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoSocialAuth implements SocialAuthClient {
  @override
  Future<SocialCredential?> signIn(SocialProvider provider) async => null;
  @override
  bool supports(SocialProvider provider) => false;
}

class _FakeSecureStorage implements SecureStorage {
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

/// `/auth/me` configurable: éxito con el flag de post-registro o un 403.
class _MeAdapter implements HttpClientAdapter {
  int status = 200;
  Map<String, Object?> errorBody = const {};
  bool postRegisterComplete = true;
  final sent = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    sent.add(options);
    final body = status == 200
        ? {
            'data': {
              'user_id': 'ana-1',
              'name': 'Ana',
              'authorization': {
                'effective': {'permissions': <String>[]},
                'grants': {
                  'global_roles': <Object>[],
                  'club_assignments': <Object>[],
                },
                'active_assignment': null,
              },
            },
            'post_register_complete': postRegisterComplete,
          }
        : errorBody;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ActingForSession session;
  late _FakeSecureStorage storage;
  late _MeAdapter adapter;
  late AuthRemoteDataSourceImpl dataSource;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      AppConstants.tokenKey: 'jwt',
    });
    session = ActingForSession();
    storage = _FakeSecureStorage();
    await storage.write(AppConstants.tokenKey, 'jwt');
    await storage.write(AppConstants.refreshTokenKey, 'refresh');
    adapter = _MeAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000'))
      ..httpClientAdapter = adapter;
    dio.interceptors.addAll([
      AuthInterceptor(dio: dio, actingForSession: session),
      // Como en producción, la salida de "actuar por" ocurre ANTES de que el
      // datasource vea el error.
      ActingErrorInterceptor(
        session,
        onActingForbidden: (_) => session.exit(),
      ),
      ErrorInterceptor(),
    ]);
    dataSource = AuthRemoteDataSourceImpl(
      dio: dio,
      baseUrl: 'http://localhost:3000/api/v1',
      secureStorage: storage,
      socialAuth: _NoSocialAuth(),
      actingForSession: session,
    );
  });

  test(
      'while acting, /auth/me is sent with the header and no completion cache '
      'is written (FP-49)', () async {
    session.enter(const ActingDependent(userId: 'ana-1', firstName: 'Ana'));
    adapter.postRegisterComplete = false;

    final user = await dataSource.getCurrentUser();

    expect(user?.id, 'ana-1');
    expect(adapter.sent.single.headers['X-Acting-For'], 'ana-1');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('cached_post_register_complete'), isFalse);
    expect(await storage.read('cached_post_register_complete'), isNull);
  });

  test('control: without acting the completion cache IS written', () async {
    adapter.postRegisterComplete = true;

    await dataSource.getCurrentUser();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('cached_post_register_complete'), isTrue);
    expect(await storage.read('cached_post_register_complete'), 'true');
  });

  test(
      '403 ACTING_FOR_FORBIDDEN while acting keeps the guardian tokens and '
      'surfaces the code (FP-55)', () async {
    session.enter(const ActingDependent(userId: 'ana-1', firstName: 'Ana'));
    adapter
      ..status = 403
      ..errorBody = {
        'status': 'error',
        'statusCode': 403,
        'code': 'ACTING_FOR_FORBIDDEN',
        'message': 'forbidden',
      };

    await expectLater(
      dataSource.getCurrentUser(),
      throwsA(
        isA<AuthException>()
            .having((e) => e.code, 'http status', 403)
            .having((e) => e.errorCode, 'code', 'ACTING_FOR_FORBIDDEN'),
      ),
    );

    // El interceptor ya sacó a la app de "actuar por"; aun así los tokens del
    // tutor siguen intactos.
    expect(session.isActing, isFalse);
    expect(await storage.read(AppConstants.tokenKey), 'jwt');
    expect(await storage.read(AppConstants.refreshTokenKey), 'refresh');
  });

  test('control: a plain 403 without the acting header still clears the token',
      () async {
    adapter
      ..status = 403
      ..errorBody = {'status': 'error', 'statusCode': 403, 'message': 'no'};

    final user = await dataSource.getCurrentUser();

    expect(user, isNull);
    expect(await storage.read(AppConstants.tokenKey), isNull);
  });
}
