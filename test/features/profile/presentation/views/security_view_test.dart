import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/auth/acting_for_session.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/features/auth/domain/entities/principal_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/biometric/domain/entities/biometric_capability.dart';
import 'package:sacdia_app/features/biometric/presentation/providers/biometric_provider.dart';
import 'package:sacdia_app/features/profile/domain/entities/active_session.dart';
import 'package:sacdia_app/features/profile/presentation/providers/active_sessions_providers.dart';
import 'package:sacdia_app/features/profile/presentation/views/security_view.dart';
import 'package:sacdia_app/providers/storage_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../family/family_test_harness.dart';

/// Sesiones en memoria que registran lo que la pantalla pide cerrar.
class _FakeSessions extends ActiveSessionsNotifier {
  _FakeSessions(this.initial);

  final List<ActiveSession> initial;
  final revoked = <String>[];
  int revokeAllCalls = 0;

  @override
  Future<List<ActiveSession>> build() async => initial;

  @override
  Future<String?> revoke(String sessionId) async {
    revoked.add(sessionId);
    state = AsyncData(
      state.value!.where((s) => s.sessionId != sessionId).toList(),
    );
    return null;
  }

  @override
  Future<({int count, String? error})> revokeAllOthers() async {
    revokeAllCalls++;
    final others = state.value!.where((s) => !s.isCurrent).length;
    state = AsyncData(state.value!.where((s) => s.isCurrent).toList());
    return (count: others, error: null);
  }
}

ActiveSession _session(
  String id, {
  SessionDeviceType type = SessionDeviceType.android,
  String? name,
  String? ip,
  bool current = false,
  Duration ago = const Duration(days: 2),
}) {
  final now = DateTime.now();
  return ActiveSession(
    sessionId: id,
    deviceType: type,
    deviceName: name,
    ipAddress: ip,
    createdAt: now.subtract(const Duration(days: 9)),
    lastActiveAt: now.subtract(ago),
    isCurrent: current,
    expiresAt: now.add(const Duration(days: 20)),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initLocalization);

  late _FakeSessions sessions;

  final threeSessions = [
    // The backend may list the current one anywhere: it must come first.
    _session('s2', name: 'Android', ip: '189.10.20.30'),
    _session('s3',
        type: SessionDeviceType.web,
        name: 'Chrome',
        ago: const Duration(days: 5)),
    _session('s1',
        type: SessionDeviceType.ios,
        name: 'iPhone',
        current: true,
        ago: const Duration(seconds: 5)),
  ];

  const teen = UserEntity(
    id: 'teen-1',
    name: 'Ana',
    postRegisterComplete: true,
    serverMode: AccountMode.teenSupervised,
  );

  Future<void> pump(
    WidgetTester tester, {
    UserEntity? user,
    bool acting = false,
    List<ActiveSession>? list,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    sessions = _FakeSessions(list ?? threeSessions);
    final session = ActingForSession();
    if (acting) {
      session.enter(const ActingDependent(userId: 'ana-1', firstName: 'Ana'));
    }
    await pumpFamilyApp(
      tester,
      overrides: [
        authNotifierProvider.overrideWith(
          () => user == null ? FakeAuthNotifier() : FakeAuthNotifier(user),
        ),
        actingForSessionProvider.overrideWithValue(session),
        sharedPreferencesProvider.overrideWithValue(prefs),
        biometricCapabilityProvider.overrideWith(
          (ref) async => const BiometricCapability(
            deviceSupportsBiometric: true,
            hasEnrolledBiometrics: true,
            availableTypes: [],
          ),
        ),
        activeSessionsProvider.overrideWith(() => sessions),
      ],
      routes: [GoRoute(path: '/', builder: (_, __) => const SecurityView())],
    );
    await tester.pumpAndSettle();
  }

  final password = 'settings.security.password'.tr;
  final biometric = 'biometric.tile_title'.tr;
  final eyebrow = 'settings.security.sessions_eyebrow'.tr;

  group('what each mode sees', () {
    testWidgets('adult: password, biometric unlock and open sessions',
        (tester) async {
      await pump(tester);

      expect(find.text(password()), findsOneWidget);
      expect(find.text(biometric()), findsOneWidget);
      expect(find.text(eyebrow().toUpperCase()), findsOneWidget);
      expect(find.text('Android'), findsOneWidget);
      expect(find.text('Panel web · Chrome'), findsOneWidget);
      expect(find.text('iPhone'), findsOneWidget);
    });

    testWidgets('teen: password and biometric unlock only', (tester) async {
      await pump(tester, user: teen);

      expect(find.text(password()), findsOneWidget);
      expect(find.text(biometric()), findsOneWidget);
      expect(find.text(eyebrow().toUpperCase()), findsNothing);
      expect(find.text('Android'), findsNothing);
    });

    testWidgets('acting for a minor: biometric unlock only', (tester) async {
      await pump(tester, acting: true);

      expect(find.text(biometric()), findsOneWidget);
      expect(find.text(password()), findsNothing);
      expect(find.text(eyebrow().toUpperCase()), findsNothing);
    });
  });

  testWidgets(
      'this device comes first with the "Actual" badge and no chevron; the '
      'others show place and time', (tester) async {
    await pump(tester);

    final iphone = tester.getTopLeft(find.text('iPhone')).dy;
    final android = tester.getTopLeft(find.text('Android')).dy;
    final web = tester.getTopLeft(find.text('Panel web · Chrome')).dy;
    expect(iphone, lessThan(android));
    expect(iphone, lessThan(web));

    expect(find.text('settings.security.current_badge'.tr()), findsOneWidget);
    expect(find.text('settings.security.this_device'.tr()), findsOneWidget);
    // IP masked + relative time.
    expect(find.text('189.10.20.xxx · hace 2 días'), findsOneWidget);
    // One chevron per other session (2) and one for the password row; none on
    // the current one.
    expect(
      find.byWidgetPredicate(
        (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedArrowRight01,
      ),
      findsNWidgets(3),
    );
    // There is no per-row trash button any more.
    expect(find.bySemanticsLabel('Cerrar sesiones'), findsNothing);
  });

  testWidgets('closing one session: sheet, revoke, row leaves, count rolls',
      (tester) async {
    await pump(tester);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('sessions-count')),
        matching: find.text('3'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Android'));
    await tester.pumpAndSettle();
    // The sheet shows the info and the destructive row.
    expect(
        find.text('settings.security.close_this_session'.tr()), findsOneWidget);
    expect(find.text('189.10.20.xxx'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('session-sheet-close')));
    await tester.pumpAndSettle();

    expect(sessions.revoked, ['s2']);
    expect(find.text('Android'), findsNothing);
    expect(find.text('Panel web · Chrome'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('sessions-count')),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    expect(find.text('settings.security.session_closed'.tr()), findsOneWidget);
  });

  testWidgets('closing the other sessions asks first, then shows the note',
      (tester) async {
    await pump(tester);

    final others = 'settings.security.close_others'.plural(2);
    expect(find.text(others), findsOneWidget);
    expect(find.text('settings.security.only_this_phone'.tr()), findsNothing);

    await tester.tap(find.text(others));
    await tester.pumpAndSettle();
    // Nothing is closed until the dialog is confirmed.
    expect(sessions.revokeAllCalls, 0);
    await tester.tap(
      find.text('profile.active_sessions.ui.action_close_sessions'.tr()),
    );
    await tester.pumpAndSettle();

    expect(sessions.revokeAllCalls, 1);
    expect(find.text('Android'), findsNothing);
    expect(find.text('Panel web · Chrome'), findsNothing);
    expect(find.text('iPhone'), findsOneWidget);
    expect(find.text(others), findsNothing);
    expect(find.text('settings.security.only_this_phone'.tr()), findsOneWidget);
    expect(
      find.text('settings.security.sessions_closed'.plural(2)),
      findsOneWidget,
    );
  });

  testWidgets('with only this device the note replaces the button',
      (tester) async {
    await pump(tester, list: [_session('s1', name: 'iPhone', current: true)]);

    expect(find.text('settings.security.only_this_phone'.tr()), findsOneWidget);
    expect(find.byType(SacButton), findsNothing);
  });

  testWidgets('the password row opens the change-password sheet',
      (tester) async {
    await pump(tester);

    await tester.tap(find.text(password()));
    await tester.pumpAndSettle();

    expect(find.text('profile.settings.field_current_password'.tr()),
        findsOneWidget);
    expect(
        find.text('profile.settings.field_new_password'.tr()), findsOneWidget);
  });
}
