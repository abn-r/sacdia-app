import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/auth/acting_for_session.dart';
import 'package:sacdia_app/core/constants/app_constants.dart';
import 'package:sacdia_app/core/network/interceptors/auth_interceptor.dart';

import '../../../support/http_adapters.dart';

const _header = 'X-Acting-For';
const _ana = ActingDependent(userId: 'ana-1', firstName: 'Ana');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ActingForSession session;
  late JsonAdapter adapter;
  late Dio dio;

  Dio build({String baseUrl = 'http://localhost:3000'}) {
    FlutterSecureStorage.setMockInitialValues({
      AppConstants.tokenKey: 'access-token',
    });
    session = ActingForSession();
    adapter = JsonAdapter(200, {'status': 'success', 'data': {}});
    final instance = Dio(BaseOptions(baseUrl: baseUrl))
      ..httpClientAdapter = adapter;
    instance.interceptors.add(
      AuthInterceptor(dio: instance, actingForSession: session),
    );
    return instance;
  }

  String? sentHeader() => adapter.lastRequest?.headers[_header] as String?;

  setUp(() => dio = build());

  group('X-Acting-For injection', () {
    test('is added while acting', () async {
      session.enter(_ana);
      await dio.get('/users/ana-1/classes');

      expect(sentHeader(), 'ana-1');
      expect(
        adapter.lastRequest?.headers['Authorization'],
        'Bearer access-token',
      );
    });

    test('is never sent when not acting', () async {
      await dio.get('/users/guardian-1/classes');
      expect(adapter.lastRequest?.headers.containsKey(_header), isFalse);
    });

    test('follows the session: gone again after exiting', () async {
      session.enter(_ana);
      await dio.get('/auth/me');
      expect(sentHeader(), 'ana-1');

      session.exit();
      await dio.get('/auth/me');
      expect(adapter.lastRequest?.headers.containsKey(_header), isFalse);
    });

    test('switching dependent changes the header', () async {
      session.enter(_ana);
      await dio.get('/auth/me');
      session.enter(const ActingDependent(userId: 'luis-1'));
      await dio.get('/auth/me');
      expect(sentHeader(), 'luis-1');
    });

    test('a caller-supplied header is not trusted while not acting', () async {
      await dio.get(
        '/users/x/classes',
        options: Options(headers: {_header: 'someone-else'}),
      );
      expect(adapter.lastRequest?.headers.containsKey(_header), isFalse);
    });
  });

  group('skip list', () {
    const skipped = <String>[
      '/auth/refresh',
      '/auth/logout',
      '/auth/login',
      '/auth/register',
      '/guardianships/me/dependents',
      '/guardianships/link-codes/redeem',
      '/fcm-tokens',
      '/fcm-tokens/abc',
      // W4: the app registers/unregisters at /users/me/fcm-tokens; the
      // guardian's token refresh while acting must not carry the header.
      '/users/me/fcm-tokens',
      '/users/me/fcm-tokens/token-id-1',
      '/notifications/preferences',
      '/users/me/notification-preferences',
      '/users/me/data-export',
      '/users/me/data-export/latest',
    ];

    for (final path in skipped) {
      test('$path never carries the header while acting', () async {
        session.enter(_ana);
        await dio.get(path);
        expect(adapter.lastRequest?.headers.containsKey(_header), isFalse);
      });
    }

    test('extra[skipActingFor] opts a single request out', () async {
      session.enter(_ana);
      await dio.get(
        '/users/ana-1/classes',
        options: Options(extra: {'skipActingFor': true}),
      );
      expect(adapter.lastRequest?.headers.containsKey(_header), isFalse);

      await dio.get('/users/ana-1/classes');
      expect(sentHeader(), 'ana-1');
    });

    test('other /auth routes still carry the header (e.g. /auth/me)', () async {
      session.enter(_ana);
      await dio.get('/auth/me');
      expect(sentHeader(), 'ana-1');
    });

    test('/users/me/legal-acceptance carries the header', () async {
      session.enter(_ana);
      await dio.post('/users/me/legal-acceptance', data: {});
      expect(sentHeader(), 'ana-1');
    });
  });

  group('absolute URLs and base path', () {
    test('full URLs under /api/v1 are matched against the API path', () async {
      dio = build(baseUrl: 'http://localhost:3000/api/v1');
      session.enter(_ana);

      await dio.get('http://localhost:3000/api/v1/guardianships/me/dependents');
      expect(adapter.lastRequest?.headers.containsKey(_header), isFalse);

      await dio.get('http://localhost:3000/api/v1/users/ana-1/classes');
      expect(sentHeader(), 'ana-1');
    });

    test('relative paths under a base path are matched too', () async {
      dio = build(baseUrl: 'http://localhost:3000/api/v1');
      session.enter(_ana);

      await dio.get('/guardianships/me/dependents');
      expect(adapter.lastRequest?.headers.containsKey(_header), isFalse);

      await dio.get('/auth/me');
      expect(sentHeader(), 'ana-1');
    });

    test('apiPathOf strips the base path and normalises the slash', () {
      final options = RequestOptions(
        path: 'http://localhost:3000/api/v1/auth/me',
        baseUrl: 'http://localhost:3000/api/v1',
      );
      expect(AuthInterceptor.apiPathOf(options), '/auth/me');

      final relative = RequestOptions(
        path: 'auth/me',
        baseUrl: 'http://localhost:3000/api/v1/',
      );
      expect(AuthInterceptor.apiPathOf(relative), '/auth/me');
    });
  });

  test('without a session the interceptor behaves exactly as before', () async {
    FlutterSecureStorage.setMockInitialValues({
      AppConstants.tokenKey: 'access-token',
    });
    adapter = JsonAdapter(200, {'status': 'success'});
    final plain = Dio(BaseOptions(baseUrl: 'http://localhost:3000'))
      ..httpClientAdapter = adapter;
    plain.interceptors.add(AuthInterceptor(dio: plain));

    await plain.get('/auth/me');

    expect(adapter.lastRequest?.headers.containsKey(_header), isFalse);
    expect(
      adapter.lastRequest?.headers['Authorization'],
      'Bearer access-token',
    );
  });
}
