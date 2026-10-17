import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/auth/acting_for_session.dart';
import 'package:sacdia_app/core/constants/app_constants.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/core/network/interceptors/acting_generation_interceptor.dart';
import 'package:sacdia_app/core/network/interceptors/auth_interceptor.dart';
import 'package:sacdia_app/core/network/interceptors/error_interceptor.dart';

const _ana = ActingDependent(userId: 'ana-1', firstName: 'Ana');
const _luis = ActingDependent(userId: 'luis-1', firstName: 'Luis');

/// Adaptador cuyas respuestas se liberan a mano, para simular peticiones en
/// vuelo mientras el usuario cambia de perfil.
class _GatedAdapter implements HttpClientAdapter {
  final gates = <String, Completer<void>>{};
  final sent = <RequestOptions>[];
  final statusByPath = <String, int>{};

  Completer<void> gate(String path) =>
      gates.putIfAbsent(path, () => Completer<void>());

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    sent.add(options);
    final pending = gates[options.path];
    if (pending != null) await pending.future;
    final status = statusByPath[options.path] ?? 200;
    final who = options.headers['X-Acting-For'] ?? 'guardian';
    return ResponseBody.fromString(
      jsonEncode({
        'status': status < 400 ? 'success' : 'error',
        'data': {'owner': who},
      }),
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
  late _GatedAdapter adapter;
  late Dio dio;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      AppConstants.tokenKey: 'access-token',
    });
    session = ActingForSession();
    adapter = _GatedAdapter();
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000'))
      ..httpClientAdapter = adapter;
    dio.interceptors.addAll([
      AuthInterceptor(dio: dio, actingForSession: session),
      ActingGenerationInterceptor(session),
      ErrorInterceptor(),
    ]);
  });

  /// Espera a que [count] peticiones hayan llegado al adaptador (la lectura del
  /// token del almacenamiento seguro es asíncrona).
  Future<void> untilSent(int count) async {
    for (var i = 0; i < 200 && adapter.sent.length < count; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(adapter.sent, hasLength(count));
  }

  /// Imita un repositorio: solo escribe en el caché si la petición tuvo éxito.
  Future<void> fetchInto(Map<String, Object?> cache, String path) async {
    final response = await dio.get<Map<String, dynamic>>(path);
    cache[path] = response.data;
  }

  test('requests are stamped with the current generation', () async {
    session.enter(_ana);
    await dio.get('/users/ana-1/classes');

    expect(
      adapter.sent.single.extra[ActingGenerationInterceptor.generationKey],
      session.generation,
    );
  });

  test('a response from the same profile goes through untouched', () async {
    session.enter(_ana);
    final response = await dio.get<Map<String, dynamic>>('/users/ana-1/x');
    expect(response.data?['data']['owner'], 'ana-1');
  });

  test(
      'Ana in flight, switch to Luis: Ana response is discarded and nothing '
      'is cached', () async {
    final cache = <String, Object?>{};
    session.enter(_ana);
    adapter.gate('/users/ana-1/classes'); // Ana's request will hang

    final anaRequest = fetchInto(cache, '/users/ana-1/classes');
    await untilSent(1);

    // The guardian switches to Luis within milliseconds.
    session.enter(_luis);
    await fetchInto(cache, '/users/luis-1/classes');

    // Ana's response finally arrives.
    adapter.gate('/users/ana-1/classes').complete();
    await expectLater(
      anaRequest,
      throwsA(
        isA<DioException>()
            .having((e) => e.type, 'type', DioExceptionType.cancel)
            .having((e) => e.error, 'error', isA<ServerException>()),
      ),
    );

    expect(cache.keys, ['/users/luis-1/classes']);
    expect(
      (cache['/users/luis-1/classes']! as Map)['data']['owner'],
      'luis-1',
    );
  });

  test('the guardian request in flight is dropped after entering a profile',
      () async {
    final cache = <String, Object?>{};
    adapter.gate('/dashboard/summary');

    final guardianRequest = fetchInto(cache, '/dashboard/summary');
    await untilSent(1);

    session.enter(_ana);
    adapter.gate('/dashboard/summary').complete();

    await expectLater(guardianRequest, throwsA(isA<DioException>()));
    expect(cache, isEmpty);
  });

  test('a stale ERROR response is also turned into a cancellation', () async {
    session.enter(_ana);
    adapter.statusByPath['/users/ana-1/slow'] = 403;
    adapter.gate('/users/ana-1/slow');

    final request = dio.get('/users/ana-1/slow');
    await untilSent(1);
    session.enter(_luis);
    adapter.gate('/users/ana-1/slow').complete();

    await expectLater(
      request,
      throwsA(
        isA<DioException>().having(
          (e) => e.type,
          'type',
          DioExceptionType.cancel,
        ),
      ),
    );
  });

  test('a fresh request after the switch is not affected', () async {
    session.enter(_ana);
    session.enter(_luis);
    final response = await dio.get<Map<String, dynamic>>('/users/luis-1/x');
    expect(response.data?['data']['owner'], 'luis-1');
  });

  test('exiting to the guardian also invalidates in-flight dependent calls',
      () async {
    final cache = <String, Object?>{};
    session.enter(_ana);
    adapter.gate('/users/ana-1/honors');

    final anaRequest = fetchInto(cache, '/users/ana-1/honors');
    await untilSent(1);

    session.exit();
    adapter.gate('/users/ana-1/honors').complete();

    await expectLater(anaRequest, throwsA(isA<DioException>()));
    expect(cache, isEmpty);
  });

  test('a stale retry is rejected before it is even sent', () async {
    session.enter(_ana);
    final staleGeneration = session.generation;
    session.enter(_luis);

    final stale = dio.get(
      '/users/ana-1/classes',
      options: Options(
        extra: {ActingGenerationInterceptor.generationKey: staleGeneration},
      ),
    );

    await expectLater(stale, throwsA(isA<DioException>()));
    expect(adapter.sent, isEmpty);
  });

  test('generationOf reads the stamp (and null when absent)', () {
    final stamped = RequestOptions(
      path: '/x',
      extra: {ActingGenerationInterceptor.generationKey: 4},
    );
    expect(ActingGenerationInterceptor.generationOf(stamped), 4);
    expect(ActingGenerationInterceptor.generationOf(RequestOptions()), isNull);
  });
}
