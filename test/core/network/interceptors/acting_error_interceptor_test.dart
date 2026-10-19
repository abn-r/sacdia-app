import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/auth/acting_for_session.dart';
import 'package:sacdia_app/core/constants/app_constants.dart';
import 'package:sacdia_app/core/network/interceptors/acting_error_interceptor.dart';
import 'package:sacdia_app/core/network/interceptors/acting_generation_interceptor.dart';
import 'package:sacdia_app/core/network/interceptors/auth_interceptor.dart';
import 'package:sacdia_app/core/network/interceptors/error_interceptor.dart';

const _ana = ActingDependent(userId: 'ana-1', firstName: 'Ana');
const _luis = ActingDependent(userId: 'luis-1', firstName: 'Luis');

/// Responde con el estado y el cuerpo configurados por ruta. Una ruta puede
/// quedar retenida (`gate`) para simular una petición en vuelo.
class _Adapter implements HttpClientAdapter {
  final statusByPath = <String, int>{};
  final bodyByPath = <String, Map<String, Object?>>{};
  final gates = <String, Completer<void>>{};
  final sent = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    sent.add(options);
    final gate = gates[options.path];
    if (gate != null) await gate.future;
    final status = statusByPath[options.path] ?? 200;
    final body = bodyByPath[options.path] ??
        {'status': status < 400 ? 'success' : 'error'};
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
  late _Adapter adapter;
  late Dio dio;
  late List<String> forbiddenCalls;

  Map<String, Object?> errorBody(String code) => {
        'status': 'error',
        'statusCode': 403,
        'code': code,
        'message': 'x',
      };

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      AppConstants.tokenKey: 'access-token',
    });
    session = ActingForSession();
    adapter = _Adapter();
    forbiddenCalls = [];
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000'))
      ..httpClientAdapter = adapter;
    // Mismo orden que DioClient.createDio.
    dio.interceptors.addAll([
      AuthInterceptor(dio: dio, actingForSession: session),
      ActingGenerationInterceptor(session),
      ActingErrorInterceptor(
        session,
        onActingForbidden: forbiddenCalls.add,
      ),
      ErrorInterceptor(),
    ]);
  });

  test('403 ACTING_FOR_FORBIDDEN while acting reports the dependent once',
      () async {
    session.enter(_ana);
    adapter.statusByPath['/users/ana-1/classes'] = 403;
    adapter.bodyByPath['/users/ana-1/classes'] =
        errorBody('ACTING_FOR_FORBIDDEN');

    await expectLater(
      dio.get('/users/ana-1/classes'),
      throwsA(isA<DioException>()),
    );

    expect(forbiddenCalls, ['ana-1']);
  });

  test('403 ACTING_FOR_SCOPE_DENIED does NOT report: the action fails only',
      () async {
    session.enter(_ana);
    adapter.statusByPath['/users/ana-1/classes/enroll'] = 403;
    adapter.bodyByPath['/users/ana-1/classes/enroll'] =
        errorBody('ACTING_FOR_SCOPE_DENIED');

    await expectLater(
      dio.get('/users/ana-1/classes/enroll'),
      throwsA(isA<DioException>()),
    );

    expect(forbiddenCalls, isEmpty);
    expect(session.isActing, isTrue);
  });

  test('the decision uses only the code, never details', () async {
    session.enter(_ana);
    adapter.statusByPath['/a'] = 403;
    adapter.bodyByPath['/a'] = {
      ...errorBody('ACTING_FOR_SCOPE_DENIED'),
      // Un `details` que parezca "forbidden" no debe engañar.
      'details': {'code': 'ACTING_FOR_FORBIDDEN'},
    };

    await expectLater(dio.get('/a'), throwsA(isA<DioException>()));
    expect(forbiddenCalls, isEmpty);

    adapter.statusByPath['/b'] = 403;
    adapter.bodyByPath['/b'] = errorBody('ACTING_FOR_FORBIDDEN');
    await expectLater(dio.get('/b'), throwsA(isA<DioException>()));
    expect(forbiddenCalls, ['ana-1']);
  });

  test('another 403 code or another status is ignored', () async {
    session.enter(_ana);
    adapter.statusByPath['/a'] = 403;
    adapter.bodyByPath['/a'] = errorBody('GUARD_PERMISSION_DENIED');
    adapter.statusByPath['/b'] = 500;
    adapter.bodyByPath['/b'] = {'code': 'ACTING_FOR_FORBIDDEN'};

    await expectLater(dio.get('/a'), throwsA(isA<DioException>()));
    await expectLater(dio.get('/b'), throwsA(isA<DioException>()));

    expect(forbiddenCalls, isEmpty);
  });

  test('a 403 without acting (no header sent) is ignored', () async {
    adapter.statusByPath['/users/me'] = 403;
    adapter.bodyByPath['/users/me'] = errorBody('ACTING_FOR_FORBIDDEN');

    await expectLater(dio.get('/users/me'), throwsA(isA<DioException>()));

    expect(forbiddenCalls, isEmpty);
  });

  test('a skip-listed request never carries the header and never reports',
      () async {
    session.enter(_ana);
    adapter.statusByPath['/guardianships/me/dependents'] = 403;
    adapter.bodyByPath['/guardianships/me/dependents'] =
        errorBody('ACTING_FOR_FORBIDDEN');

    await expectLater(
      dio.get('/guardianships/me/dependents'),
      throwsA(isA<DioException>()),
    );

    expect(adapter.sent.single.headers.containsKey('X-Acting-For'), isFalse);
    expect(forbiddenCalls, isEmpty);
  });

  test('a 403 for an abandoned profile does not expel the new one', () async {
    session.enter(_ana);
    adapter.gates['/users/ana-1/classes'] = Completer<void>();
    adapter.statusByPath['/users/ana-1/classes'] = 403;
    adapter.bodyByPath['/users/ana-1/classes'] =
        errorBody('ACTING_FOR_FORBIDDEN');

    final anaRequest = dio.get('/users/ana-1/classes');
    // Deja que la petición salga con el encabezado de Ana.
    for (var i = 0; i < 100 && adapter.sent.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(adapter.sent, hasLength(1));

    // El tutor cambia a Luis; después llega el 403 de Ana.
    session.enter(_luis);
    adapter.gates['/users/ana-1/classes']!.complete();

    await expectLater(anaRequest, throwsA(isA<DioException>()));

    expect(forbiddenCalls, isEmpty, reason: 'stale response is dropped first');
    expect(session.dependentUserId, 'luis-1');
  });

  test('a callback that throws never breaks the error chain', () async {
    final throwing = Dio(BaseOptions(baseUrl: 'http://localhost:3000'))
      ..httpClientAdapter = adapter;
    throwing.interceptors.addAll([
      AuthInterceptor(dio: throwing, actingForSession: session),
      ActingErrorInterceptor(
        session,
        onActingForbidden: (_) => throw StateError('boom'),
      ),
    ]);
    session.enter(_ana);
    adapter.statusByPath['/x'] = 403;
    adapter.bodyByPath['/x'] = errorBody('ACTING_FOR_FORBIDDEN');

    await expectLater(
      throwing.get('/x'),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'status',
          403,
        ),
      ),
    );
  });
}
