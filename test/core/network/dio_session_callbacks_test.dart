import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/auth/acting_for_session.dart';
import 'package:sacdia_app/core/auth/session_mode.dart';
import 'package:sacdia_app/features/device_mode/presentation/providers/device_notice_provider.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/qr/presentation/providers/qr_member_token_provider.dart';
import 'package:sacdia_app/features/qr/presentation/providers/qr_scan_provider.dart';
import 'package:sacdia_app/features/virtual_card/presentation/providers/virtual_card_providers.dart';
import 'package:sacdia_app/providers/dio_provider.dart';

import '../../support/http_adapters.dart';
import '../../support/riverpod_test_support.dart';

/// S3 (verify 2b): las instancias de Dio de la credencial virtual y de QR se
/// creaban sin `onAuthExpired` / `onActingForbidden`. Un 403
/// ACTING_FOR_FORBIDDEN o un refresh muerto en ellas no sacaba del perfil ni
/// cerraba la sesión, como sí hace el Dio principal.

class _RecordingAuth extends AuthNotifier {
  final expired = <int>[];
  final forbidden = <String>[];
  final unpaired = <DeviceNotice>[];

  @override
  Future<UserEntity?> build() async => null;

  @override
  void onDeviceUnpaired({DeviceNotice notice = DeviceNotice.unpaired}) =>
      unpaired.add(notice);

  @override
  void expireSession() => expired.add(expired.length + 1);

  @override
  void onActingForbidden(String dependentUserId) =>
      forbidden.add(dependentUserId);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final dios = <String, Provider<Dio>>{
    'main dio': dioProvider,
    'virtual card dio': virtualCardDioProvider,
    'qr member token dio': qrMemberTokenDioProvider,
    'qr scan dio': qrScanDioProvider,
  };

  late _RecordingAuth auth;
  late ActingForSession session;

  ProviderContainer build({bool device = false}) {
    FlutterSecureStorage.setMockInitialValues({});
    auth = _RecordingAuth();
    session = ActingForSession();
    final container = createTestContainer(
      overrides: [
        authNotifierProvider.overrideWith(() => auth),
        actingForSessionProvider.overrideWithValue(session),
        if (device)
          sessionModeProvider.overrideWith((ref) => SessionMode.device),
      ],
    );
    return container;
  }

  for (final entry in dios.entries) {
    group(entry.key, () {
      test('403 ACTING_FOR_FORBIDDEN while acting leaves the profile',
          () async {
        final container = build();
        session.enter(const ActingDependent(userId: 'ana-1'));
        final dio = container.read(entry.value)
          ..httpClientAdapter = JsonAdapter(403, {
            'status': 'error',
            'code': 'ACTING_FOR_FORBIDDEN',
            'message': 'forbidden',
          });

        await expectLater(
          dio.get('/qr/me/card'),
          throwsA(isA<DioException>()),
        );

        expect(auth.forbidden, ['ana-1']);
      });

      test('a dead refresh token expires the session', () async {
        final container = build();
        final dio = container.read(entry.value)
          ..httpClientAdapter = JsonAdapter(401, {
            'status': 'error',
            'code': 'AUTH_SESSION_EXPIRED',
          });

        await expectLater(
          dio.get('/qr/me/card'),
          throwsA(isA<DioException>()),
        );

        expect(auth.expired, isNotEmpty);
      });

      test('a revoked device goes back to pairing, not to the login', () async {
        final container = build(device: true);
        final dio = container.read(entry.value)
          ..httpClientAdapter = JsonAdapter(401, {
            'status': 'error',
            'code': 'AUTH_DEVICE_REVOKED',
          });

        await expectLater(
          dio.get('/qr/me/card'),
          throwsA(isA<DioException>()),
        );

        expect(auth.unpaired, [DeviceNotice.unpaired]);
        expect(auth.expired, isEmpty);
      });

      test('an expired device link leaves its own notice', () async {
        final container = build(device: true);
        final dio = container.read(entry.value)
          ..httpClientAdapter = JsonAdapter(401, {
            'status': 'error',
            'code': 'AUTH_DEVICE_SESSION_EXPIRED',
          });

        await expectLater(
          dio.get('/qr/me/card'),
          throwsA(isA<DioException>()),
        );

        expect(auth.unpaired, [DeviceNotice.sessionExpired]);
      });

      test('a dead refresh on a device unpairs it', () async {
        final container = build(device: true);
        final dio = container.read(entry.value)
          ..httpClientAdapter = JsonAdapter(401, {
            'status': 'error',
            'code': 'AUTH_SESSION_EXPIRED',
          });

        await expectLater(
          dio.get('/qr/me/card'),
          throwsA(isA<DioException>()),
        );

        expect(auth.unpaired, [DeviceNotice.unpaired]);
        expect(auth.expired, isEmpty);
      });

      test('a device never acts for anyone, even with an acting session',
          () async {
        final container = build(device: true);
        session.enter(const ActingDependent(userId: 'ana-1'));
        final adapter = JsonAdapter(200, {'status': 'success', 'data': {}});
        final dio = container.read(entry.value)..httpClientAdapter = adapter;

        await dio.get('/users/kid-1/classes');

        expect(
            adapter.lastRequest?.headers.containsKey('X-Acting-For'), isFalse);
      });
    });
  }
}
