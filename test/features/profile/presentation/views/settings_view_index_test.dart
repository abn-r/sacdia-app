import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/profile/domain/entities/notification_preferences.dart';
import 'package:sacdia_app/features/profile/presentation/providers/notification_preferences_providers.dart';
import 'package:sacdia_app/features/profile/presentation/views/settings_view.dart';
import 'package:sacdia_app/features/settings/presentation/views/about_view.dart';
import 'package:sacdia_app/features/settings/presentation/views/appearance_view.dart';
import 'package:sacdia_app/features/settings/presentation/views/notification_settings_view.dart';
import 'package:sacdia_app/providers/storage_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../family/family_test_harness.dart';

class _FakePrefs extends NotificationPreferencesNotifier {
  _FakePrefs(this.initial);

  final NotificationPreferences initial;

  @override
  Future<NotificationPreferences> build() async => initial;
}

/// Índice de Ajustes: grupos, valores de las filas y la puerta de la directiva.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initLocalization();
    PackageInfo.setMockInitialValues(
      appName: 'SACDIA',
      packageName: 'com.sacdia.app',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  Future<void> pump(
    WidgetTester tester, {
    UserEntity? user,
    NotificationPreferences prefs = const NotificationPreferences.defaults(),
  }) async {
    SharedPreferences.setMockInitialValues({});
    final sharedPrefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(800, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpFamilyApp(
      tester,
      overrides: [
        authNotifierProvider.overrideWith(
          () => user == null ? FakeAuthNotifier() : FakeAuthNotifier(user),
        ),
        notificationPreferencesProvider.overrideWith(() => _FakePrefs(prefs)),
        sharedPreferencesProvider.overrideWithValue(sharedPrefs),
      ],
      routes: [
        GoRoute(path: '/', builder: (_, __) => const SettingsView()),
      ],
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the topic groups, the identity row and no old rows',
      (tester) async {
    await pump(tester);

    expect(find.text('María'), findsOneWidget);
    expect(find.text('maria@example.com'), findsOneWidget);
    for (final key in [
      'settings.section_my_club',
      'settings.section_preferences',
      'settings.section_security_privacy',
      'settings.section_help',
    ]) {
      expect(find.text(key.tr().toUpperCase()), findsOneWidget, reason: key);
    }
    for (final key in [
      'settings.member_qr',
      'settings.appearance_title',
      'settings.notifications_title',
      'settings.language_picker_title',
      'settings.security_title',
      'settings.my_data_title',
      'support.settings_entry_title',
      'settings.about_title',
      'profile.settings.logout_tile',
    ]) {
      expect(find.text(key.tr()), findsOneWidget, reason: key);
    }
    // El tema actual es el valor de Apariencia y la versión, el de Acerca de.
    expect(find.text('profile.settings.theme_system'.tr()), findsOneWidget);
    expect(find.text('1.0.0'), findsOneWidget);
    // Lo que se movió a otras pantallas ya no está aquí.
    for (final key in [
      'profile.settings.delete_account_tile',
      'profile.settings.privacy_policy',
      'settings.clear_cache_tile',
    ]) {
      expect(find.text(key.tr()), findsNothing, reason: key);
    }
  });

  group('Directiva (escaneo de credencial)', () {
    testWidgets('hidden without the attendance permission or capability',
        (tester) async {
      await pump(tester);

      expect(find.text('settings.scan_qr'.tr()), findsNothing);
      expect(
        find.text('settings.section_directive'.tr().toUpperCase()),
        findsNothing,
      );
    });

    testWidgets('shown with attendance:manage', (tester) async {
      await pump(
        tester,
        user: const UserEntity(
          id: 'dir-1',
          email: 'dir@example.com',
          name: 'Dir',
          postRegisterComplete: true,
          authorization: AuthorizationSnapshot(
            effectivePermissions: ['attendance:manage'],
          ),
        ),
      );

      expect(find.text('settings.scan_qr'.tr()), findsOneWidget);
      expect(
        find.text('settings.section_directive'.tr().toUpperCase()),
        findsOneWidget,
      );
    });

    testWidgets('shown with the club.operational_staff capability',
        (tester) async {
      await pump(
        tester,
        user: const UserEntity(
          id: 'dir-2',
          email: 'dir@example.com',
          name: 'Dir',
          postRegisterComplete: true,
          authorization: AuthorizationSnapshot(
            capabilities: ['club.operational_staff'],
          ),
        ),
      );

      expect(find.text('settings.scan_qr'.tr()), findsOneWidget);
    });
  });

  group('Notificaciones value', () {
    testWidgets('Algunas when only some alerts are on', (tester) async {
      await pump(
        tester,
        prefs:
            const NotificationPreferences.defaults().copyWith(reminders: false),
      );
      expect(find.text('settings.notif_value_some'.tr()), findsOneWidget);
    });

    testWidgets('Apagadas when every alert is off', (tester) async {
      await pump(
        tester,
        prefs: const NotificationPreferences(
          master: false,
          activities: false,
          achievements: false,
          approvals: false,
          invitations: false,
          reminders: false,
        ),
      );
      expect(find.text('settings.notif_value_off'.tr()), findsOneWidget);
    });
  });

  testWidgets('each topic row opens its own screen', (tester) async {
    await pump(tester);

    Future<void> openAndBack(String key, Type page) async {
      await tester.tap(find.text(key.tr()));
      await tester.pumpAndSettle();
      expect(find.byType(page), findsOneWidget, reason: key);
      final back = tester.state<NavigatorState>(find.byType(Navigator).last);
      back.pop();
      await tester.pumpAndSettle();
    }

    await openAndBack('settings.appearance_title', AppearanceView);
    await openAndBack('settings.notifications_title', NotificationSettingsView);
    await openAndBack('settings.about_title', AboutView);
  });
}
