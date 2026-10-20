import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/features/auth/domain/entities/principal_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/family/data/models/dependent_models.dart';
import 'package:sacdia_app/features/family/domain/entities/dependent.dart';
import 'package:sacdia_app/features/family/domain/entities/linked_device.dart';
import 'package:sacdia_app/features/family/presentation/providers/linked_devices_providers.dart';
import 'package:sacdia_app/features/family/presentation/views/dependent_detail_view.dart';
import 'package:sacdia_app/features/family/presentation/widgets/devices_section.dart';

import 'family_fixtures.dart';
import 'family_test_harness.dart';
import 'linked_devices_test_support.dart';

UserEntity _guardian({bool? linkedDevice = true}) => UserEntity(
      id: 'guardian-1',
      email: 'maria@example.com',
      name: 'María',
      postRegisterComplete: true,
      familyFeatures: linkedDevice == null
          ? null
          : FamilyFeatures(linkedDevice: linkedDevice),
    );

DependentDetail _detail({
  String consent = 'verified',
  bool frozen = false,
  String access = 'guardian_managed',
  bool milestone = false,
  int devices = 0,
}) =>
    FamilyJson.detail({
      ...dependentJson(
        consent: consent,
        frozen: frozen,
        accessMode: access,
        ageMilestoneReached: milestone,
        linkedDevices: devices,
      ),
      'guardians': [guardianJson(consent: consent)],
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initLocalization);

  late FakeFamilyRepository family;
  late FakeLinkedDevicesRepository devices;

  setUp(() {
    family = FakeFamilyRepository();
    devices = FakeLinkedDevicesRepository();
  });

  Future<GoRouter> pump(
    WidgetTester tester, {
    DependentDetail? detail,
    UserEntity? user,
  }) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    family.detail = Right(detail ?? _detail());
    final router = await pumpFamilyApp(
      tester,
      overrides: [
        linkedDevicesRepositoryProvider.overrideWithValue(devices),
        ...familyOverrides(
          repo: family,
          auth: FakeAuthNotifier(user ?? _guardian()),
        ),
      ],
      initialLocation: '/family',
      routes: [
        stubRoute('/family'),
        GoRoute(
          path: RouteNames.familyPairDevice,
          builder: (_, s) => Scaffold(
            body: Text('pair:${s.pathParameters['dependentId']}'),
          ),
        ),
        GoRoute(
          path: '/family/:dependentId',
          builder: (_, state) => DependentDetailView(
            dependentId: state.pathParameters['dependentId']!,
          ),
        ),
      ],
    );
    unawaited(router.push('/family/ana-1'));
    await tester.pumpAndSettle();
    return router;
  }

  final section = find.byKey(const ValueKey('devices_section'));
  final pairButton = find.byKey(const ValueKey('devices_pair'));

  group('visibility', () {
    testWidgets('a verified guardian of an under-13 child sees it',
        (tester) async {
      await pump(tester);
      expect(section, findsOneWidget);
      expect(find.byKey(const ValueKey('devices_empty')), findsOneWidget);
      expect(pairButton, findsOneWidget);
      expect(devices.listCalls, ['ana-1']);
    });

    testWidgets('off or unknown feature flag hides it (fail closed)',
        (tester) async {
      await pump(tester, user: _guardian(linkedDevice: false));
      expect(section, findsNothing);
    });

    testWidgets('an unknown flag (no family_features) hides it',
        (tester) async {
      await pump(tester, user: _guardian(linkedDevice: null));
      expect(section, findsNothing);
      expect(devices.listCalls, isEmpty, reason: 'no call when hidden');
    });

    testWidgets('a pending guardian does not see it', (tester) async {
      await pump(tester, detail: _detail(consent: 'pending'));
      expect(section, findsNothing);
    });

    testWidgets('a frozen child does not have it', (tester) async {
      await pump(tester, detail: _detail(frozen: true));
      expect(section, findsNothing);
    });

    testWidgets('at 13+ with no phones it is hidden', (tester) async {
      await pump(tester, detail: _detail(milestone: true));
      expect(section, findsNothing);
    });

    testWidgets('a child with own login and no phones does not have it',
        (tester) async {
      await pump(tester, detail: _detail(access: 'supervised_login'));
      expect(section, findsNothing);
    });

    testWidgets('at 13+ existing phones stay visible, but no new pairing',
        (tester) async {
      devices.devices = Right(LinkedDevices(devices: [linkedDevice('d1')]));
      await pump(tester, detail: _detail(milestone: true, devices: 1));

      expect(section, findsOneWidget);
      expect(find.byKey(const ValueKey('device_d1')), findsOneWidget);
      expect(pairButton, findsNothing);
      expect(find.textContaining('Ya no se pueden vincular teléfonos nuevos'),
          findsOneWidget);
      // Y se puede desvincular.
      expect(find.byKey(const ValueKey('device_revoke_d1')), findsOneWidget);
    });
  });

  group('list', () {
    testWidgets('shows label, platform, who paired and last activity',
        (tester) async {
      devices.devices = Right(LinkedDevices(devices: [
        linkedDevice('d1', lastSeenAt: DateTime.utc(2026, 10, 20, 15)),
        linkedDevice('d2',
            label: 'iPad', platform: 'ios', pairedBy: 'Pedro Pérez'),
      ]));
      await pump(tester, detail: _detail(devices: 2));

      expect(find.text('Tablet de Ana'), findsOneWidget);
      expect(find.text('iPad'), findsOneWidget);
      expect(find.textContaining('Android'), findsOneWidget);
      expect(find.textContaining('iOS'), findsOneWidget);
      expect(find.textContaining('Vinculado por Pedro Pérez'), findsOneWidget);
      expect(find.textContaining('Última actividad'), findsOneWidget);
      expect(find.textContaining('Sin actividad todavía'), findsOneWidget);
      expect(find.text('2/2'), findsOneWidget);
    });

    testWidgets('at the limit pairing is disabled with a reason',
        (tester) async {
      devices.devices = Right(LinkedDevices(
        devices: [linkedDevice('d1'), linkedDevice('d2')],
      ));
      await pump(tester, detail: _detail(devices: 2));

      expect(find.byKey(const ValueKey('devices_limit_hint')), findsOneWidget);
      expect(find.textContaining('el máximo'), findsOneWidget);
      final button = tester.widget<SacButton>(pairButton);
      expect(button.onPressed, isNull, reason: 'no room for another phone');
    });

    testWidgets('revoked phones are shown as history, without a revoke button',
        (tester) async {
      devices.devices = Right(LinkedDevices(devices: [
        linkedDevice('d1'),
        linkedDevice('d9',
            label: 'Vieja', revokedAt: DateTime.utc(2026, 10, 18)),
      ]));
      await pump(tester, detail: _detail(devices: 1));

      expect(find.text('Desvinculados recientemente'), findsOneWidget);
      expect(find.text('Vieja'), findsOneWidget);
      expect(find.byKey(const ValueKey('device_revoke_d9')), findsNothing);
      expect(find.byKey(const ValueKey('device_revoke_d1')), findsOneWidget);
      expect(find.text('1/2'), findsOneWidget, reason: 'revoked do not count');
    });

    testWidgets('a failing list shows the mapped error and retries',
        (tester) async {
      devices.devices = const Left(ServerFailure(
        message: 'RAW',
        code: 404,
        errorCode: 'FAMILY_FEATURE_DISABLED',
      ));
      await pump(tester);

      expect(find.byKey(const ValueKey('devices_error')), findsOneWidget);
      expect(
          find.textContaining('no está disponible por ahora'), findsOneWidget);
      expect(find.text('RAW'), findsNothing);
    });
  });

  group('pairing entry', () {
    testWidgets('"Vincular un teléfono" opens the QR screen', (tester) async {
      await pump(tester);

      await tester.ensureVisible(pairButton);
      await tester.tap(pairButton);
      await tester.pumpAndSettle();

      expect(find.text('pair:ana-1'), findsOneWidget);
    });
  });

  group('revoke', () {
    setUp(() {
      devices.devices = Right(LinkedDevices(devices: [linkedDevice('d1')]));
    });

    testWidgets('asks first, then revokes and refreshes', (tester) async {
      await pump(tester, detail: _detail(devices: 1));
      final listsBefore = devices.listCalls.length;

      final revoke = find.byKey(const ValueKey('device_revoke_d1'));
      await tester.ensureVisible(revoke);
      await tester.tap(revoke);
      await tester.pumpAndSettle();
      expect(find.text('¿Desvincular Tablet de Ana?'), findsOneWidget);
      expect(devices.revokeCalls, isEmpty);

      devices.devices = const Right(LinkedDevices());
      await tester.tap(find.text('Desvincular').last);
      await tester.pumpAndSettle();

      expect(devices.revokeCalls, [(dependentId: 'ana-1', deviceId: 'd1')]);
      expect(devices.listCalls.length, greaterThan(listsBefore));
      expect(find.text('Teléfono desvinculado'), findsOneWidget);
      expect(find.byKey(const ValueKey('device_d1')), findsNothing);
    });

    testWidgets('cancelling changes nothing', (tester) async {
      await pump(tester, detail: _detail(devices: 1));

      final revoke = find.byKey(const ValueKey('device_revoke_d1'));
      await tester.ensureVisible(revoke);
      await tester.tap(revoke);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(devices.revokeCalls, isEmpty);
      expect(find.byKey(const ValueKey('device_d1')), findsOneWidget);
    });

    testWidgets('a server refusal shows its mapped message', (tester) async {
      devices.revokeResult = const Left(ServerFailure(
        message: 'RAW',
        code: 404,
        errorCode: 'DEVICE_NOT_FOUND',
      ));
      await pump(tester, detail: _detail(devices: 1));

      final revoke = find.byKey(const ValueKey('device_revoke_d1'));
      await tester.ensureVisible(revoke);
      await tester.tap(revoke);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Desvincular').last);
      await tester.pumpAndSettle();

      expect(
          find.text('No encontramos ese teléfono vinculado.'), findsOneWidget);
      expect(find.text('RAW'), findsNothing);
    });
  });

  group('shouldShowDevicesSection', () {
    test('matrix', () {
      DependentSummary s({
        String consent = 'verified',
        bool frozen = false,
        String access = 'guardian_managed',
        bool milestone = false,
        int devices = 0,
      }) =>
          FamilyJson.summary(dependentJson(
            consent: consent,
            frozen: frozen,
            accessMode: access,
            ageMilestoneReached: milestone,
            linkedDevices: devices,
          ));

      expect(shouldShowDevicesSection(s(), featureEnabled: true), isTrue);
      expect(shouldShowDevicesSection(s(), featureEnabled: false), isFalse);
      expect(
          shouldShowDevicesSection(s(consent: 'pending'), featureEnabled: true),
          isFalse);
      expect(
          shouldShowDevicesSection(s(frozen: true, devices: 1),
              featureEnabled: true),
          isFalse);
      expect(shouldShowDevicesSection(s(milestone: true), featureEnabled: true),
          isFalse);
      expect(
          shouldShowDevicesSection(s(milestone: true, devices: 1),
              featureEnabled: true),
          isTrue);
      expect(
          shouldShowDevicesSection(s(access: 'supervised_login'),
              featureEnabled: true),
          isFalse);
    });
  });
}
