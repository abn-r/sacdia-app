import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/family/domain/entities/linked_device.dart';
import 'package:sacdia_app/features/family/presentation/providers/linked_devices_providers.dart';
import 'package:sacdia_app/features/family/presentation/views/pairing_qr_view.dart';

import 'family_test_harness.dart';
import 'linked_devices_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initLocalization);

  late FakeLinkedDevicesRepository repo;
  late DateTime clock;

  setUp(() {
    repo = FakeLinkedDevicesRepository();
    clock = DateTime.utc(2026, 10, 20, 10);
    repo.now = () => clock;
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = await pumpFamilyApp(
      tester,
      overrides: [
        linkedDevicesRepositoryProvider.overrideWithValue(repo),
        ...familyOverrides(
            repo: FakeFamilyRepository(), auth: FakeAuthNotifier()),
      ],
      initialLocation: '/family/ana-1',
      routes: [
        stubRoute('/family/ana-1'),
        GoRoute(
          path: RouteNames.familyPairDevice,
          builder: (_, state) => PairingQrView(
            dependentId: state.pathParameters['dependentId']!,
            pollInterval: const Duration(seconds: 4),
            clock: () => clock,
          ),
        ),
      ],
    );
    unawaited(router.push(RouteNames.familyPairDevicePath('ana-1')));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Avanza [seconds] de reloj Y de timers (la vista lee el reloj inyectado).
  Future<void> elapse(WidgetTester tester, int seconds) async {
    for (var i = 0; i < seconds; i++) {
      clock = clock.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }
  }

  testWidgets('asks for a token as the guardian and shows its QR',
      (tester) async {
    await pump(tester);

    expect(repo.issueCalls, ['ana-1']);
    final qr = tester.widget<PairingQrCode>(find.byType(PairingQrCode));
    expect(qr.data, 'sacdia://pair?c=TOKEN-1');
    expect(find.text('Vence en 10:00'), findsOneWidget);
    expect(find.byKey(const ValueKey('pairing_error')), findsNothing);
  });

  testWidgets('the countdown ticks and the QR is retired at zero',
      (tester) async {
    await pump(tester);

    await elapse(tester, 65);
    expect(find.text('Vence en 08:55'), findsOneWidget);

    await elapse(tester, 540);
    expect(find.text('El código venció'), findsOneWidget);
    expect(find.byKey(const ValueKey('pairing_regenerate')), findsOneWidget);
    // El QR vencido se atenúa: ya no es escaneable.
    final opacity = tester.widget<Opacity>(
      find.descendant(
        of: find.byKey(const ValueKey('pairing_qr')),
        matching: find.byType(Opacity),
      ),
    );
    expect(opacity.opacity, lessThan(0.2));
  });

  testWidgets('regenerating asks for a NEW token and restarts the countdown',
      (tester) async {
    await pump(tester);
    await elapse(tester, 300);
    expect(find.text('Vence en 05:00'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('pairing_regenerate')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(repo.issueCalls, hasLength(2));
    expect(tester.widget<PairingQrCode>(find.byType(PairingQrCode)).data,
        'sacdia://pair?c=TOKEN-2');
    expect(find.text('Vence en 10:00'), findsOneWidget);
  });

  testWidgets('a regenerated code works after the first one expired',
      (tester) async {
    await pump(tester);
    await elapse(tester, 601);
    expect(find.text('El código venció'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('pairing_regenerate')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Vence en 10:00'), findsOneWidget);
    expect(find.text('El código venció'), findsNothing);
  });

  testWidgets('a new phone appearing while the QR is up is announced',
      (tester) async {
    await pump(tester);
    expect(find.byKey(const ValueKey('pairing_success')), findsNothing);

    // El niño escanea: en la siguiente consulta aparece su teléfono.
    repo.devices = Right(LinkedDevices(devices: [linkedDevice('d-new')]));
    await elapse(tester, 5);
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const ValueKey('pairing_success')), findsOneWidget);
    expect(find.text('Teléfono vinculado'), findsOneWidget);
    expect(find.byType(PairingQrCode), findsNothing,
        reason: 'the used QR is gone');
  });

  testWidgets('phones that were already linked do not count as the new one',
      (tester) async {
    repo.devices = Right(LinkedDevices(devices: [linkedDevice('d-old')]));
    await pump(tester);

    await elapse(tester, 13);

    expect(find.byKey(const ValueKey('pairing_success')), findsNothing);
    expect(find.byType(PairingQrCode), findsOneWidget);
  });

  group('errors by code', () {
    Future<void> failWith(
      WidgetTester tester,
      int status,
      String code,
    ) async {
      repo.tokenResult =
          Left(ServerFailure(message: 'RAW', code: status, errorCode: code));
      await pump(tester);
    }

    testWidgets('device limit reached', (tester) async {
      await failWith(tester, 409, 'DEVICE_LIMIT_REACHED');
      expect(find.textContaining('máximo de teléfonos vinculados'),
          findsOneWidget);
      expect(find.byType(PairingQrCode), findsNothing);
      expect(find.text('RAW'), findsNothing);
    });

    testWidgets('not eligible', (tester) async {
      await failWith(tester, 422, 'DEVICE_PAIRING_NOT_ELIGIBLE');
      expect(find.textContaining('no se puede vincular a un teléfono'),
          findsOneWidget);
    });

    testWidgets('age out of range', (tester) async {
      await failWith(tester, 422, 'LINKED_DEVICE_AGE_OUT_OF_RANGE');
      expect(find.textContaining('menores de 13 años'), findsOneWidget);
    });

    testWidgets('feature off', (tester) async {
      await failWith(tester, 404, 'FAMILY_FEATURE_DISABLED');
      expect(
          find.textContaining('no está disponible por ahora'), findsOneWidget);
    });

    testWidgets('a retry asks again', (tester) async {
      await failWith(tester, 409, 'DEVICE_LIMIT_REACHED');
      repo.tokenResult = null;

      await tester.tap(find.byKey(const ValueKey('pairing_retry')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(PairingQrCode), findsOneWidget);
    });
  });
}
