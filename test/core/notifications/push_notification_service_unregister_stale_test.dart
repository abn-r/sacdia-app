import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/network/interceptors/authorization_stale_interceptor.dart';
import 'package:sacdia_app/core/notifications/fcm_registrar.dart';
import 'package:sacdia_app/core/notifications/push_notification_service.dart';

import '../../support/http_adapters.dart';
import '../../support/riverpod_test_support.dart';

class _NoopRegistrar extends Fake implements FcmRegistrar {
  @override
  Future<void> unregister() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Dio real con el `AuthorizationStaleInterceptor` en modo obsoleto: toda
  /// mutación sin exención se rechaza antes de salir.
  ({Dio dio, JsonAdapter adapter}) staleDio() {
    final adapter = JsonAdapter(200, <String, dynamic>{});
    final dio = Dio()
      ..httpClientAdapter = adapter
      ..interceptors.insert(
        0,
        AuthorizationStaleInterceptor(isStale: () => true),
      );
    return (dio: dio, adapter: adapter);
  }

  Future<void> unregister(Dio dio) async {
    final provider = Provider(
      (ref) => PushNotificationService(
        dio: dio,
        ref: ref,
        registrar: _NoopRegistrar(),
      ),
    );
    await createTestContainer().read(provider).unregisterToken();
  }

  test('the DELETE by id reaches the backend with a stale authorization',
      () async {
    FlutterSecureStorage.setMockInitialValues({
      'fcm_registered_token': 'fcm-token',
      'fcm_registered_token_id': 'token-id',
      'fcm_registered_kind': 'fid',
    });
    final (:dio, :adapter) = staleDio();

    await unregister(dio);

    final request = adapter.lastRequest;
    expect(request, isNotNull, reason: 'the interceptor let it through');
    expect(request!.method, 'DELETE');
    expect(request.path, '/users/me/fcm-tokens/token-id');
    expect(request.extra[kAllowWhileAuthorizationStale], isTrue);
    expect(
      await const FlutterSecureStorage().read(key: 'fcm_registered_token_id'),
      isNull,
    );
  });

  test('the by-token fallback also passes while stale', () async {
    FlutterSecureStorage.setMockInitialValues({
      'fcm_registered_token': 'fcm-token',
      'fcm_registered_kind': 'token',
    });
    final (:dio, :adapter) = staleDio();

    await unregister(dio);

    final request = adapter.lastRequest;
    expect(request, isNotNull, reason: 'the interceptor let it through');
    expect(request!.method, 'DELETE');
    expect(request.path, '/fcm-tokens/by-token');
    expect(request.data, {'token': 'fcm-token'});
    expect(request.extra[kAllowWhileAuthorizationStale], isTrue);
  });
}
