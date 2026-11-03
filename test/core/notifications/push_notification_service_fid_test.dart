import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/auth/acting_for_session.dart';
import 'package:sacdia_app/core/notifications/fcm_registrar.dart';
import 'package:sacdia_app/core/notifications/push_notification_service.dart';

import '../../support/riverpod_test_support.dart';

/// Registrar falso: `register()` re-emite el FID configurado, como el real.
class FakeFcmRegistrar implements FcmRegistrar {
  FakeFcmRegistrar({this.fid = 'fid-1'});

  String? fid;
  int registerCalls = 0;
  int unregisterCalls = 0;
  Object? registerError;
  Object? unregisterError;

  /// Si es `true`, `unregister()` no termina nunca (simula red colgada).
  bool unregisterHangs = false;

  final _registered = StreamController<String>.broadcast();
  final _unregistered = StreamController<String>.broadcast();

  void emit(String value) => _registered.add(value);

  @override
  Future<void> register() async {
    registerCalls++;
    final error = registerError;
    if (error != null) throw error;
    final value = fid;
    if (value != null) _registered.add(value);
  }

  @override
  Future<void> unregister() async {
    unregisterCalls++;
    if (unregisterHangs) return Completer<void>().future;
    final error = unregisterError;
    if (error != null) throw error;
  }

  @override
  Stream<String> get onRegistered => _registered.stream;

  @override
  Stream<String> get onUnregistered => _unregistered.stream;

  @override
  Future<String?> getAPNSToken() async => null;
}

class RecordedRequest {
  RecordedRequest(this.method, this.path, this.body);
  final String method;
  final String path;
  final Object? body;
}

/// Adaptador Dio que registra cada petición. El POST devuelve `{id: row-N}`.
class RecordingAdapter implements HttpClientAdapter {
  final requests = <RecordedRequest>[];
  int _posts = 0;
  bool failPost = false;

  Iterable<RecordedRequest> where(String method) =>
      requests.where((r) => r.method == method);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(
      RecordedRequest(options.method, options.path, options.data),
    );
    if (options.method == 'POST' && failPost) {
      return ResponseBody.fromString('{}', 500, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      });
    }
    final body = options.method == 'POST'
        ? {'id': 'row-${++_posts}'}
        : <String, dynamic>{};
    return ResponseBody.fromString(
      jsonEncode(body),
      options.method == 'POST' ? 201 : 200,
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

  const storage = FlutterSecureStorage();

  late FakeFcmRegistrar registrar;
  late RecordingAdapter adapter;
  late ProviderContainer container;
  late PushNotificationService service;

  void build({Map<String, String> stored = const {}}) {
    // Copia: el mock muta el mapa que recibe.
    FlutterSecureStorage.setMockInitialValues({...stored});
    registrar = FakeFcmRegistrar();
    adapter = RecordingAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final provider = Provider(
      (ref) => PushNotificationService(
        dio: dio,
        ref: ref,
        registrar: registrar,
      ),
    );
    container = createTestContainer();
    service = container.read(provider);
  }

  /// Deja que el stream broadcast entregue y que termine la cola de POST.
  Future<void> settle() async {
    await Future<void>.delayed(Duration.zero);
    await service.registrationIdleForTesting;
  }

  Future<void> start() async {
    await service.startRegistrationForTesting();
    await settle();
  }

  tearDown(() async => service.dispose());

  group('registration', () {
    test('a FID emitted by register() is POSTed with kind fid and stored',
        () async {
      build();

      await start();

      expect(registrar.registerCalls, 1);
      final posts = adapter.where('POST').toList();
      expect(posts, hasLength(1));
      expect(posts.single.path, '/users/me/fcm-tokens');
      expect(posts.single.body, {'token': 'fid-1', 'kind': 'fid'});
      expect(await storage.read(key: 'fcm_registered_token'), 'fid-1');
      expect(await storage.read(key: 'fcm_registered_kind'), 'fid');
      expect(await storage.read(key: 'fcm_registered_token_id'), 'row-1');
      expect(adapter.where('DELETE'), isEmpty);
    });

    test('re-emitting the same FID does not POST twice', () async {
      build();
      await start();

      registrar.emit('fid-1');
      await settle();
      // initialize() again re-calls register(), which re-emits.
      await start();

      expect(adapter.where('POST'), hasLength(1));
    });

    test('a different FID is POSTed again and replaces the stored one',
        () async {
      build();
      await start();

      registrar.emit('fid-2');
      await settle();

      expect(adapter.where('POST'), hasLength(2));
      expect(await storage.read(key: 'fcm_registered_token'), 'fid-2');
      expect(await storage.read(key: 'fcm_registered_token_id'), 'row-2');
      expect(adapter.where('DELETE'), isEmpty);
    });

    test('a failed POST stores nothing and a later emission retries', () async {
      build();
      adapter.failPost = true;
      await start();

      expect(await storage.read(key: 'fcm_registered_token'), isNull);

      adapter.failPost = false;
      registrar.emit('fid-1');
      await settle();

      expect(adapter.where('POST'), hasLength(2));
      expect(await storage.read(key: 'fcm_registered_token'), 'fid-1');
    });

    test('a register() failure is swallowed', () async {
      build();
      registrar.registerError = StateError('apns-token-not-set');

      await start();

      expect(adapter.requests, isEmpty);
    });

    test('a legacy token (no kind) is unregistered by id after the FID is in',
        () async {
      build(stored: {
        'fcm_registered_token': 'legacy-token',
        'fcm_registered_token_id': 'legacy-row',
      });

      await start();

      final posts = adapter.where('POST').toList();
      expect(posts.single.body, {'token': 'fid-1', 'kind': 'fid'});
      final deletes = adapter.where('DELETE').toList();
      expect(deletes, hasLength(1));
      expect(deletes.single.path, '/users/me/fcm-tokens/legacy-row');
      // Order matters: the FID must be registered before the old row goes.
      expect(
        adapter.requests.map((r) => r.method).toList(),
        ['POST', 'DELETE'],
      );
      expect(await storage.read(key: 'fcm_registered_token'), 'fid-1');
      expect(await storage.read(key: 'fcm_registered_kind'), 'fid');
      expect(await storage.read(key: 'fcm_registered_token_id'), 'row-1');
    });

    test('a legacy token without a stored id is removed by token value',
        () async {
      build(stored: {'fcm_registered_token': 'legacy-token'});

      await start();

      final deletes = adapter.where('DELETE').toList();
      expect(deletes.single.path, '/fcm-tokens/by-token');
      expect(deletes.single.body, {'token': 'legacy-token'});
    });

    test('the legacy row is kept when the FID POST fails', () async {
      build(stored: {
        'fcm_registered_token': 'legacy-token',
        'fcm_registered_token_id': 'legacy-row',
      });
      adapter.failPost = true;

      await start();

      expect(adapter.where('DELETE'), isEmpty);
      expect(await storage.read(key: 'fcm_registered_token'), 'legacy-token');
    });

    test('nothing is registered while acting for a dependent', () async {
      build();
      container.read(actingForSessionProvider).enter(
            const ActingDependent(userId: 'minor-1', firstName: 'Ana'),
          );

      await start();

      expect(adapter.requests, isEmpty);
      expect(await storage.read(key: 'fcm_registered_token'), isNull);
    });

    test('the FID is registered once acting ends and initialize runs again',
        () async {
      build();
      final session = container.read(actingForSessionProvider);
      session.enter(const ActingDependent(userId: 'minor-1'));
      await start();
      expect(adapter.requests, isEmpty);

      session.exit();
      await start();

      expect(adapter.where('POST'), hasLength(1));
    });
  });

  group('logout', () {
    final stored = {
      'fcm_registered_token': 'fid-1',
      'fcm_registered_kind': 'fid',
      'fcm_registered_token_id': 'row-9',
    };

    test('unregisterToken DELETEs by id and calls unregister()', () async {
      build(stored: stored);

      await service.unregisterToken();

      final deletes = adapter.where('DELETE').toList();
      expect(deletes.single.path, '/users/me/fcm-tokens/row-9');
      expect(registrar.unregisterCalls, 1);
      expect(await storage.read(key: 'fcm_registered_token'), isNull);
      expect(await storage.read(key: 'fcm_registered_kind'), isNull);
      expect(await storage.read(key: 'fcm_registered_token_id'), isNull);
    });

    test('unregister() is still called when nothing was registered', () async {
      build();

      await service.unregisterToken();

      expect(adapter.requests, isEmpty);
      expect(registrar.unregisterCalls, 1);
    });

    test('an unregister() failure does not break logout', () async {
      build(stored: stored);
      registrar.unregisterError = StateError('boom');

      await expectLater(service.unregisterToken(), completes);

      expect(adapter.where('DELETE'), hasLength(1));
      expect(await storage.read(key: 'fcm_registered_token'), isNull);
    });

    test('an unregister() that hangs is cut by the timeout', () async {
      build(stored: stored);
      registrar.unregisterHangs = true;

      final sw = Stopwatch()..start();
      await service.unregisterToken();
      sw.stop();

      expect(registrar.unregisterCalls, 1);
      expect(sw.elapsed, lessThan(const Duration(seconds: 6)));
    });

    test('clearLocalRegistration wipes storage, calls unregister(), no HTTP',
        () async {
      build(stored: stored);

      await service.clearLocalRegistration();

      expect(adapter.requests, isEmpty);
      expect(registrar.unregisterCalls, 1);
      expect(await storage.read(key: 'fcm_registered_token'), isNull);
      expect(await storage.read(key: 'fcm_registered_kind'), isNull);
      expect(await storage.read(key: 'fcm_registered_token_id'), isNull);
    });

    test('clearLocalRegistration survives an unregister() failure', () async {
      build(stored: stored);
      registrar.unregisterError = StateError('boom');

      await expectLater(service.clearLocalRegistration(), completes);
    });
  });
}
