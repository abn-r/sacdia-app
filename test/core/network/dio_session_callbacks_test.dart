import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/auth/acting_for_session.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/qr/presentation/providers/qr_member_token_provider.dart';
import 'package:sacdia_app/features/qr/presentation/providers/qr_scan_provider.dart';
import 'package:sacdia_app/features/virtual_card/presentation/providers/virtual_card_providers.dart';
import 'package:sacdia_app/providers/dio_provider.dart';

import '../../support/http_adapters.dart';

/// S3 (verify 2b): las instancias de Dio de la credencial virtual y de QR se
/// creaban sin `onAuthExpired` / `onActingForbidden`. Un 403
/// ACTING_FOR_FORBIDDEN o un refresh muerto en ellas no sacaba del perfil ni
/// cerraba la sesión, como sí hace el Dio principal.

class _RecordingAuth extends AuthNotifier {
  final expired = <int>[];
  final forbidden = <String>[];

  @override
  Future<UserEntity?> build() async => null;

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

  ProviderContainer build() {
    FlutterSecureStorage.setMockInitialValues({});
    auth = _RecordingAuth();
    session = ActingForSession();
    final container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(() => auth),
        actingForSessionProvider.overrideWithValue(session),
      ],
    );
    addTearDown(container.dispose);
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
    });
  }
}
