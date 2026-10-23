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

/// W1 y W2 (verify 2b): el reintento tras refrescar el token y el sello de
/// generación del perfil. Todo usa un adaptador falso (sin red).

const _ana = ActingDependent(userId: 'ana-1', firstName: 'Ana');
const _luis = ActingDependent(userId: 'luis-1', firstName: 'Luis');
const _path = '/users/ana-1/classes';

/// Responde 401 a la primera petición de cada ruta y 200 a las siguientes;
/// `/auth/refresh` y el reintento pueden retenerse con compuertas.
class _ScriptedAdapter implements HttpClientAdapter {
  final sent = <RequestOptions>[];
  final calls = <String, int>{};
  Completer<void>? refreshGate;
  Completer<void>? retryGate;

  /// Si se da, el reintento (no el 401 inicial) responde con este estado/cuerpo.
  int? retryStatus;
  Map<String, Object?>? retryBody;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    sent.add(options);
    final count = calls.update(options.path, (c) => c + 1, ifAbsent: () => 1);
    int status;
    Object body;
    if (options.path == '/auth/refresh') {
      await refreshGate?.future;
      status = 200;
      body = {
        'data': {'accessToken': 'new-access', 'refreshToken': 'new-refresh'},
      };
    } else if (count == 1) {
      status = 401;
      body = {'status': 'error', 'code': 'AUTH_SESSION_EXPIRED'};
    } else {
      await retryGate?.future;
      status = retryStatus ?? 200;
      body = retryBody ??
          {
            'data': {'owner': options.headers['X-Acting-For'] ?? 'guardian'},
          };
    }
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

  /// Peticiones que no son el refresh ni la primera (el 401).
  List<RequestOptions> get retries =>
      sent.where((o) => o.path != '/auth/refresh').skip(1).toList();
}

/// Cambia el perfil justo entre `AuthInterceptor` y `ActingGenerationInterceptor`
/// para reproducir la ventana de W2.
class _SwitchBetween extends Interceptor {
  _SwitchBetween(this.onRequestHook);

  final void Function() onRequestHook;
  bool fired = false;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!fired) {
      fired = true;
      onRequestHook();
    }
    handler.next(options);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ActingForSession session;
  late _ScriptedAdapter adapter;
  late List<String> forbidden;

  Dio build({List<Interceptor> between = const []}) {
    FlutterSecureStorage.setMockInitialValues({
      AppConstants.tokenKey: 'old-access',
      AppConstants.refreshTokenKey: 'old-refresh',
    });
    session = ActingForSession();
    adapter = _ScriptedAdapter();
    forbidden = <String>[];
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000'))
      ..httpClientAdapter = adapter;
    dio.interceptors.addAll([
      AuthInterceptor(
        dio: dio,
        actingForSession: session,
        refreshAdapter: adapter,
      ),
      ...between,
      ActingGenerationInterceptor(session),
      ActingErrorInterceptor(session, onActingForbidden: forbidden.add),
      ErrorInterceptor(),
    ]);
    return dio;
  }

  Future<void> until(bool Function() condition) async {
    for (var i = 0; i < 400 && !condition(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(condition(), isTrue, reason: 'condition not reached in time');
  }

  Matcher staleCancel() => isA<DioException>().having(
        (e) => e.type,
        'type',
        DioExceptionType.cancel,
      );

  group('refresh retry (W1)', () {
    test('control: an unchanged profile retries with ITS header', () async {
      final dio = build();
      session.enter(_ana);

      final response = await dio.get<Map<String, dynamic>>(_path);

      expect(response.data?['data']['owner'], 'ana-1');
      expect(adapter.retries, hasLength(1));
      expect(adapter.retries.single.headers['X-Acting-For'], 'ana-1');
      expect(
          adapter.retries.single.headers['Authorization'], 'Bearer new-access');
    });

    test(
        'exiting during the refresh: no retry with the old header, '
        'nothing is delivered', () async {
      final dio = build();
      session.enter(_ana);
      adapter.refreshGate = Completer<void>();

      final request = dio.get<Map<String, dynamic>>(_path);
      await until(() => adapter.calls['/auth/refresh'] == 1);

      session.exit(); // "Volver a mi perfil" mientras se refresca
      adapter.refreshGate!.complete();

      await expectLater(request, throwsA(staleCancel()));
      expect(
        adapter.retries,
        isEmpty,
        reason: 'a retry would carry X-Acting-For: ana-1 while not acting',
      );
    });

    test(
        'switching Ana -> Luis during the refresh never replays '
        "Ana's header", () async {
      final dio = build();
      session.enter(_ana);
      adapter.refreshGate = Completer<void>();

      final request = dio.get<Map<String, dynamic>>(_path);
      await until(() => adapter.calls['/auth/refresh'] == 1);

      session.enter(_luis);
      adapter.refreshGate!.complete();

      await expectLater(request, throwsA(staleCancel()));
      expect(adapter.retries, isEmpty);
    });

    test('leaving the profile while the retry is in flight drops the response',
        () async {
      final dio = build();
      session.enter(_ana);
      adapter.retryGate = Completer<void>();

      final request = dio.get<Map<String, dynamic>>(_path);
      await until(() => adapter.retries.length == 1);
      expect(adapter.retries.single.headers['X-Acting-For'], 'ana-1');

      session.exit();
      adapter.retryGate!.complete();

      await expectLater(
        request,
        throwsA(staleCancel()),
        reason: 'the response must not reach the caller (e.g. a cache write)',
      );
    });
  });

  group('403 on the post-refresh retry (S2 of re-verify)', () {
    test(
        'ACTING_FOR_FORBIDDEN on the retry reaches the acting exit path '
        '(it is not swallowed as the original 401)', () async {
      final dio = build();
      session.enter(_ana);
      adapter
        ..retryStatus = 403
        ..retryBody = {'status': 'error', 'code': 'ACTING_FOR_FORBIDDEN'};

      await expectLater(
        dio.get<Map<String, dynamic>>(_path),
        throwsA(isA<DioException>()),
      );

      expect(forbidden, ['ana-1']);
    });

    test('ACTING_FOR_SCOPE_DENIED on the retry does NOT exit the profile',
        () async {
      final dio = build();
      session.enter(_ana);
      adapter
        ..retryStatus = 403
        ..retryBody = {'status': 'error', 'code': 'ACTING_FOR_SCOPE_DENIED'};

      await expectLater(
        dio.get<Map<String, dynamic>>(_path),
        throwsA(isA<DioException>()),
      );

      expect(forbidden, isEmpty);
    });

    test('a 403 for a profile already abandoned is dropped, not escalated',
        () async {
      final dio = build();
      session.enter(_ana);
      adapter
        ..retryGate = Completer<void>()
        ..retryStatus = 403
        ..retryBody = {'status': 'error', 'code': 'ACTING_FOR_FORBIDDEN'};

      final request = dio.get<Map<String, dynamic>>(_path);
      await until(() => adapter.retries.length == 1);
      session.enter(_luis);
      adapter.retryGate!.complete();

      await expectLater(request, throwsA(staleCancel()));
      expect(forbidden, isEmpty);
    });
  });

  group('header decision and generation stamp are atomic (W2)', () {
    test(
        'a switch between the header decision and the stamp rejects the '
        'request instead of stamping the NEW generation on the OLD header',
        () async {
      late ActingForSession live;
      final dio = build(between: [_SwitchBetween(() => live.enter(_luis))]);
      live = session;
      session.enter(_ana);

      await expectLater(
        dio.get<Map<String, dynamic>>('/users/ana-1/honors'),
        throwsA(staleCancel()),
      );

      expect(
        adapter.sent,
        isEmpty,
        reason: 'the request carried X-Acting-For: ana-1 but profile is luis',
      );
    });

    test('the stamp equals the generation seen when the header was chosen',
        () async {
      final dio = build();
      session.enter(_ana);
      final generation = session.generation;

      await dio.get<Map<String, dynamic>>('/users/ana-1/honors').catchError(
            (_) => Response<Map<String, dynamic>>(
              requestOptions: RequestOptions(),
            ),
          );

      final first = adapter.sent.firstWhere((o) => o.path.endsWith('/honors'));
      expect(
          first.extra[ActingGenerationInterceptor.generationKey], generation);
      expect(first.headers['X-Acting-For'], 'ana-1');
    });
  });
}
