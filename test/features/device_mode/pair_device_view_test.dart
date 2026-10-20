import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/device_pair_link.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/notifications/push_notification_provider.dart';
import 'package:sacdia_app/core/storage/image_cache_purge.dart';
import 'package:sacdia_app/core/storage/json_file_cache.dart';
import 'package:sacdia_app/providers/json_file_cache_provider.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/profile_scope_purge.dart';
import 'package:sacdia_app/features/device_mode/domain/entities/device_pairing.dart';
import 'package:sacdia_app/features/device_mode/domain/repositories/device_pairing_repository.dart';
import 'package:sacdia_app/features/device_mode/presentation/providers/device_pairing_providers.dart';
import 'package:sacdia_app/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:sacdia_app/providers/storage_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/presentation/providers/auth_notifier_test_support.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/device_mode/presentation/providers/device_notice_provider.dart';
import 'package:sacdia_app/features/device_mode/presentation/views/pair_device_view.dart';

import '../family/family_test_harness.dart';
import 'device_test_harness.dart';

/// Cámara falsa: devuelve [value] y se cierra, como el lector real.
WidgetBuilder fakeScanner(String? value) => (context) => Scaffold(
      body: Center(
        child: TextButton(
          key: const ValueKey('fake_scan'),
          onPressed: () => Navigator.of(context).pop(value),
          child: const Text('scan'),
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initLocalization);

  late FakeDeviceAuth auth;

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    String? scanValue = 'sacdia://pair?t=TOKEN-1_a',
    UserEntity? user,
    DeviceNotice? notice,
    String? pendingLink,
    Size logicalSize = const Size(600, 1200),
    double textScale = 0.5,
  }) async {
    tester.view.physicalSize = logicalSize * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    auth = FakeDeviceAuth(user);
    late ProviderContainer container;
    await pumpFamilyApp(
      tester,
      initialLocation: RouteNames.devicePair,
      textScale: textScale,
      overrides: [
        authNotifierProvider.overrideWith(() => auth),
        metaOverride(),
        if (notice != null) deviceNoticeProvider.overrideWith((ref) => notice),
        if (pendingLink != null)
          pairingLinkProvider.overrideWith((ref) => pendingLink),
      ],
      routes: [
        GoRoute(
          path: RouteNames.devicePair,
          builder: (_, __) =>
              PairDeviceView(scannerBuilder: fakeScanner(scanValue)),
        ),
        stubRoute(RouteNames.login),
        stubRoute(RouteNames.splash),
      ],
    );
    container = ProviderScope.containerOf(
      tester.element(find.byType(PairDeviceView)),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> scan(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('pair_scan')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('fake_scan')));
    await tester.pumpAndSettle();
  }

  group('PairDeviceView: scanning', () {
    testWidgets(
        'at phone width (402x874) the phone-name helper wraps instead of '
        'ending in an ellipsis', (tester) async {
      // The test font (Ahem) is wider than the real one, so 1.0 would overflow
      // the unrelated ghost buttons; 0.6 still forces the helper onto 2 lines.
      await pump(
        tester,
        logicalSize: const Size(402, 874),
        textScale: 0.6,
      );
      await scan(tester);

      final helper = find.text(
        'Tu tutor verá este nombre en su lista de teléfonos vinculados.',
      );
      expect(helper, findsOneWidget);
      expect(
        tester.renderObject<RenderParagraph>(helper).didExceedMaxLines,
        isFalse,
        reason: 'the full sentence must be visible',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a valid QR asks for the phone name, prefilled',
        (tester) async {
      await pump(tester);

      expect(find.byKey(const ValueKey('pair_scan')), findsOneWidget);
      expect(find.byKey(const ValueKey('pair_label_field')), findsNothing);

      await scan(tester);

      expect(find.byKey(const ValueKey('pair_label_field')), findsOneWidget);
      expect(find.text('Pixel 8'), findsOneWidget,
          reason: 'default label from the device model');
      expect(find.byKey(const ValueKey('pair_error')), findsNothing);
      expect(auth.pairCalls, isEmpty,
          reason: 'nothing is sent before confirming');
    });

    testWidgets('linking sends the token, label, platform and version',
        (tester) async {
      await pump(tester);
      await scan(tester);

      await tester.enterText(
        find.byKey(const ValueKey('pair_label_field')),
        'Tablet de Ana',
      );
      await tester.tap(find.byKey(const ValueKey('pair_submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(auth.pairCalls, hasLength(1));
      final call = auth.pairCalls.single;
      expect(call.pairingToken, 'TOKEN-1_a');
      expect(call.label, 'Tablet de Ana');
      expect(call.platform, 'android');
      expect(call.appVersion, '2.4.0');
    });

    testWidgets('the label is sanitized: controls, spaces and length',
        (tester) async {
      await pump(tester);
      await scan(tester);

      await tester.enterText(
        find.byKey(const ValueKey('pair_label_field')),
        '  Tablet\n\u0007 de    Ana  ',
      );
      await tester.tap(find.byKey(const ValueKey('pair_submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(auth.pairCalls.single.label, 'Tablet de Ana');
    });

    testWidgets('an empty label falls back to the device model',
        (tester) async {
      await pump(tester);
      await scan(tester);

      await tester.enterText(
          find.byKey(const ValueKey('pair_label_field')), '  ');
      await tester.tap(find.byKey(const ValueKey('pair_submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(auth.pairCalls.single.label, 'Pixel 8');
    });

    testWidgets('a QR that is not a pairing link gets one message and no call',
        (tester) async {
      for (final value in [
        'https://example.com',
        'sacdia://pair',
        'not a url at all',
        'sacdia://other?c=abc',
      ]) {
        await pump(tester, scanValue: value);
        await scan(tester);

        expect(find.byKey(const ValueKey('pair_error')), findsOneWidget,
            reason: value);
        expect(find.textContaining('no es de SACDIA'), findsOneWidget);
        expect(find.byKey(const ValueKey('pair_label_field')), findsNothing);
        expect(auth.pairCalls, isEmpty, reason: value);
      }
    });

    testWidgets('cancelling the camera changes nothing', (tester) async {
      await pump(tester, scanValue: null);
      await scan(tester);

      expect(find.byKey(const ValueKey('pair_label_field')), findsNothing);
      expect(find.byKey(const ValueKey('pair_error')), findsNothing);
    });
  });

  group('PairDeviceView: failures', () {
    testWidgets('a rejected redeem shows the message and asks to scan again',
        (tester) async {
      await pump(tester);
      auth.pairError = 'Este código no es válido o ya venció.';
      await scan(tester);

      await tester.tap(find.byKey(const ValueKey('pair_submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
          find.text('Este código no es válido o ya venció.'), findsOneWidget);
      // El token es de un solo uso: se vuelve a escanear.
      expect(find.byKey(const ValueKey('pair_scan')), findsOneWidget);
      expect(find.byKey(const ValueKey('pair_label_field')), findsNothing);
      expect(find.byKey(const ValueKey('pair_submit')), findsNothing);
    });
  });

  group('PairDeviceView: an account session refuses', () {
    testWidgets('says "sign out first" and offers no scanning', (tester) async {
      await pump(tester, user: guardianUser);

      expect(find.byKey(const ValueKey('pair_refused_title')), findsOneWidget);
      expect(find.text('Cierra sesión primero'), findsOneWidget);
      expect(find.byKey(const ValueKey('pair_scan')), findsNothing);
      expect(find.byKey(const ValueKey('pair_submit')), findsNothing);
      expect(auth.pairCalls, isEmpty);
    });

    testWidgets('a deep link is dropped, never used', (tester) async {
      final container = await pump(
        tester,
        user: guardianUser,
        pendingLink: 'LINKTOKEN',
      );

      expect(find.byKey(const ValueKey('pair_refused_title')), findsOneWidget);
      expect(container.read(pairingLinkProvider), isNull,
          reason: 'consumed and cleared');
      expect(auth.pairCalls, isEmpty, reason: 'NO API call');
    });
  });

  group('PairDeviceView: deep link', () {
    testWidgets('a pending link goes straight to the name step and is cleared',
        (tester) async {
      final container = await pump(tester, pendingLink: 'LINK-token_9');

      expect(find.byKey(const ValueKey('pair_label_field')), findsOneWidget);
      expect(container.read(pairingLinkProvider), isNull);

      await tester.tap(find.byKey(const ValueKey('pair_submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(auth.pairCalls.single.pairingToken, 'LINK-token_9');
    });

    testWidgets('a link arriving while the screen is open is adopted too',
        (tester) async {
      final container = await pump(tester, notice: DeviceNotice.unpaired);
      expect(find.byKey(const ValueKey('pair_label_field')), findsNothing);

      container.read(pairingLinkProvider.notifier).state = 'LATE-token_2';
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('pair_label_field')), findsOneWidget);
      expect(container.read(pairingLinkProvider), isNull);

      await tester.tap(find.byKey(const ValueKey('pair_submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(auth.pairCalls.single.pairingToken, 'LATE-token_2');
    });
  });

  group('PairDeviceView: lost link notice', () {
    testWidgets('unpaired phones see why', (tester) async {
      await pump(tester, notice: DeviceNotice.unpaired);

      expect(find.byKey(const ValueKey('pair_notice')), findsOneWidget);
      expect(find.textContaining('desvinculó este teléfono'), findsOneWidget);
    });

    testWidgets('an expired link says it expired', (tester) async {
      await pump(tester, notice: DeviceNotice.sessionExpired);

      expect(find.textContaining('venció'), findsOneWidget);
    });

    testWidgets('the notice can be dismissed', (tester) async {
      final container = await pump(tester, notice: DeviceNotice.unpaired);

      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('pair_notice')), findsNothing);
      expect(container.read(deviceNoticeProvider), isNull);
    });

    testWidgets('"back to sign in" drops the notice and leaves',
        (tester) async {
      final container = await pump(tester, notice: DeviceNotice.unpaired);

      await tester.tap(find.byKey(const ValueKey('pair_back')));
      await tester.pumpAndSettle();

      expect(container.read(deviceNoticeProvider), isNull);
      expect(find.text('route:${RouteNames.login}'), findsOneWidget);
    });
  });

  group('PairDeviceView with the real AuthNotifier: errors by code', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('home_widget'),
        (_) async => true,
      );
    });
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('home_widget'), null);
    });

    Future<void> pumpWith(
      WidgetTester tester,
      Either<Failure, DevicePairingSession> result,
    ) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await pumpFamilyApp(
        tester,
        initialLocation: RouteNames.devicePair,
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          secureStorageProvider.overrideWithValue(FakeSecureStorage()),
          sharedPreferencesProvider.overrideWithValue(prefs),
          notificationsRepositoryProvider
              .overrideWithValue(FakeNotificationsRepository()),
          pushNotificationServiceProvider.overrideWith(
            (ref) => FakePushNotificationService(ref: ref, prefs: prefs),
          ),
          imageCachePurgerProvider.overrideWithValue(() async {}),
          jsonFileCacheProvider.overrideWithValue(MemoryJsonFileCache()),
          profileScopedProvidersProvider.overrideWithValue(const []),
          devicePairingRepositoryProvider
              .overrideWithValue(_FixedPairing(result)),
          metaOverride(),
        ],
        routes: [
          GoRoute(
            path: RouteNames.devicePair,
            builder: (_, __) => PairDeviceView(
                scannerBuilder: fakeScanner('sacdia://pair?t=T1')),
          ),
          stubRoute(RouteNames.login),
          stubRoute(RouteNames.splash),
        ],
      );
      await tester.pumpAndSettle();
      await scan(tester);
      await tester.tap(find.byKey(const ValueKey('pair_submit')));
      await tester.pumpAndSettle();
    }

    testWidgets('an invalid or expired token', (tester) async {
      await pumpWith(
        tester,
        const Left(ServerFailure(
          message: 'RAW',
          code: 400,
          errorCode: 'DEVICE_PAIRING_TOKEN_INVALID',
        )),
      );
      expect(find.textContaining('no es válido o ya venció'), findsOneWidget);
      expect(find.text('RAW'), findsNothing);
    });

    testWidgets('the device limit', (tester) async {
      await pumpWith(
        tester,
        const Left(ServerFailure(
          message: 'RAW',
          code: 409,
          errorCode: 'DEVICE_LIMIT_REACHED',
        )),
      );
      expect(find.textContaining('máximo de teléfonos vinculados'),
          findsOneWidget);
    });

    testWidgets('the feature being off', (tester) async {
      await pumpWith(
        tester,
        const Left(ServerFailure(
          message: 'RAW',
          code: 404,
          errorCode: 'FAMILY_FEATURE_DISABLED',
        )),
      );
      expect(
          find.textContaining('no está disponible por ahora'), findsOneWidget);
    });

    testWidgets('an unknown failure gets the generic message', (tester) async {
      await pumpWith(
        tester,
        const Left(ServerFailure(message: 'RAW', code: 500)),
      );
      expect(
          find.text('No pudimos vincular este teléfono. Inténtalo de nuevo.'),
          findsOneWidget);
    });

    testWidgets('no connection', (tester) async {
      await pumpWith(tester, const Left(NetworkFailure(message: 'offline')));
      expect(find.byKey(const ValueKey('pair_error')), findsOneWidget);
    });
  });
}

class _FixedPairing implements DevicePairingRepository {
  _FixedPairing(this.result);

  final Either<Failure, DevicePairingSession> result;

  @override
  Future<Either<Failure, DevicePairingSession>> pair(
    DevicePairingInput input,
  ) async =>
      result;
}
