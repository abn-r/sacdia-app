import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/features/profile/domain/entities/notification_preferences.dart';
import 'package:sacdia_app/features/profile/presentation/providers/notification_preferences_providers.dart';
import 'package:sacdia_app/features/settings/presentation/providers/notification_permission_provider.dart';
import 'package:sacdia_app/features/settings/presentation/views/notification_settings_view.dart';

import '../../../family/family_test_harness.dart';

class _FakePrefs extends NotificationPreferencesNotifier {
  _FakePrefs(this.initial, this.deltas);

  final NotificationPreferences initial;
  final List<Map<String, bool>> deltas;

  @override
  Future<NotificationPreferences> build() async => initial;

  @override
  Future<String?> patch(Map<String, bool> delta) async {
    deltas.add(delta);
    state = AsyncData(state.value!.applyDelta(delta));
    return null;
  }
}

class _FakeGate implements NotificationPermissionGate {
  _FakeGate({this.denied = false});

  bool denied;
  int opened = 0;

  @override
  Future<bool> isDenied() async => denied;

  @override
  Future<void> openSettings() async => opened++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initLocalization);

  const kindTitles = [
    'profile.settings.notif_activities',
    'profile.settings.notif_achievements',
    'profile.settings.notif_approvals',
    'profile.settings.notif_invitations',
    'profile.settings.notif_reminders',
  ];

  Future<void> pump(
    WidgetTester tester, {
    NotificationPreferences prefs = const NotificationPreferences.defaults(),
    required _FakeGate gate,
    List<Map<String, bool>>? deltas,
  }) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpFamilyApp(
      tester,
      overrides: [
        notificationPreferencesProvider
            .overrideWith(() => _FakePrefs(prefs, deltas ?? [])),
        notificationPermissionGateProvider.overrideWithValue(gate),
      ],
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const NotificationSettingsView(),
        ),
      ],
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the master switch and the five kinds with a description',
      (tester) async {
    await pump(tester, gate: _FakeGate());

    expect(
        find.text('settings.notifications.allow_title'.tr()), findsOneWidget);
    expect(
      find.text('settings.notifications.allow_subtitle'.tr()),
      findsOneWidget,
    );
    for (final key in kindTitles) {
      expect(find.text(key.tr()), findsOneWidget, reason: key);
    }
    expect(
      find.text('settings.notifications.activities_desc'.tr()),
      findsOneWidget,
    );
    expect(find.text('settings.notifications.off_note'.tr()), findsNothing);
    expect(
      find.text('settings.notifications.denied_title'.tr()),
      findsNothing,
    );
  });

  testWidgets('turning a kind off saves only that kind', (tester) async {
    final deltas = <Map<String, bool>>[];
    await pump(tester, gate: _FakeGate(), deltas: deltas);

    await tester.tap(find.descendant(
      of: find.byKey(const ValueKey('notif-reminders')),
      matching: find.byType(Switch),
    ));
    await tester.pumpAndSettle();

    expect(deltas, [
      {'reminders': false},
    ]);
  });

  testWidgets('turning the master off folds the kinds and shows the note',
      (tester) async {
    final deltas = <Map<String, bool>>[];
    await pump(tester, gate: _FakeGate(), deltas: deltas);

    await tester.tap(find.descendant(
      of: find.byKey(const ValueKey('notif-master')),
      matching: find.byType(Switch),
    ));
    await tester.pumpAndSettle();

    expect(deltas, [
      {'master': false},
    ]);
    for (final key in kindTitles) {
      expect(find.text(key.tr()), findsNothing, reason: key);
    }
    expect(find.text('settings.notifications.off_note'.tr()), findsOneWidget);

    // Turning it back on brings the kinds back and drops the note.
    await tester.tap(find.descendant(
      of: find.byKey(const ValueKey('notif-master')),
      matching: find.byType(Switch),
    ));
    await tester.pumpAndSettle();
    for (final key in kindTitles) {
      expect(find.text(key.tr()), findsOneWidget, reason: key);
    }
    expect(find.text('settings.notifications.off_note'.tr()), findsNothing);
  });

  testWidgets('with the master off from the start the kinds are folded',
      (tester) async {
    await pump(
      tester,
      gate: _FakeGate(),
      prefs: const NotificationPreferences(
        master: false,
        activities: false,
        achievements: false,
        approvals: false,
        invitations: false,
        reminders: false,
      ),
    );

    expect(find.text(kindTitles.first.tr()), findsNothing);
    expect(find.text('settings.notifications.off_note'.tr()), findsOneWidget);
  });

  group('phone permission denied', () {
    testWidgets('shows the warning, disables the kinds and opens settings',
        (tester) async {
      final gate = _FakeGate(denied: true);
      final deltas = <Map<String, bool>>[];
      await pump(tester, gate: gate, deltas: deltas);

      expect(
        find.text('settings.notifications.denied_title'.tr()),
        findsOneWidget,
      );
      expect(
        find.text('settings.notifications.denied_body'.tr()),
        findsOneWidget,
      );
      // The kinds stay visible but cannot be toggled.
      for (final key in kindTitles) {
        expect(find.text(key.tr()), findsOneWidget, reason: key);
      }
      final reminders = tester.widget<Switch>(find.descendant(
        of: find.byKey(const ValueKey('notif-reminders')),
        matching: find.byType(Switch),
      ));
      expect(reminders.onChanged, isNull);

      await tester.tap(
        find.text('settings.notifications.open_phone_settings'.tr()),
      );
      await tester.pump();
      expect(gate.opened, 1);
      expect(deltas, isEmpty);
    });

    testWidgets('re-checks the permission when the app resumes',
        (tester) async {
      final gate = _FakeGate(denied: true);
      await pump(tester, gate: gate);
      expect(
        find.text('settings.notifications.denied_title'.tr()),
        findsOneWidget,
      );

      // The user allowed notifications in the phone settings and came back.
      gate.denied = false;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(
        find.text('settings.notifications.denied_title'.tr()),
        findsNothing,
      );
    });
  });
}
