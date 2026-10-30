import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/notifications/push_notification_service.dart';

import '../../support/http_adapters.dart';
import '../../support/riverpod_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'clearLocalRegistration drops the stored token without any HTTP request',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'fcm_registered_token': 'fcm-token',
        'fcm_registered_token_id': 'token-id',
      });
      final adapter = JsonAdapter(200, <String, dynamic>{});
      final dio = Dio()..httpClientAdapter = adapter;
      final provider = Provider(
        (ref) => PushNotificationService(dio: dio, ref: ref),
      );
      final container = createTestContainer();

      // Firebase no está inicializado en tests: deleteToken() falla y el
      // servicio debe tragarse el error (best-effort).
      await container.read(provider).clearLocalRegistration();

      const storage = FlutterSecureStorage();
      expect(await storage.read(key: 'fcm_registered_token'), isNull);
      expect(await storage.read(key: 'fcm_registered_token_id'), isNull);
      expect(
        adapter.lastRequest,
        isNull,
        reason: 'sin sesión, un DELETE al backend expiraría la sesión',
      );
    },
  );
}
