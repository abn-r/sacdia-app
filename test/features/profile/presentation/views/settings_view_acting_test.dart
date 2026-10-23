import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sacdia_app/core/auth/acting_for_session.dart';
import 'package:sacdia_app/features/auth/domain/entities/principal_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/profile/presentation/views/settings_view.dart';
import 'package:sacdia_app/providers/storage_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../family/family_test_harness.dart';

/// FP-56: mientras se actúa por un menor, Ajustes no ofrece sesiones activas,
/// exportación de datos, cambio de contraseña ni borrado de cuenta.
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
    required bool acting,
    UserEntity? user,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(800, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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
      ],
      routes: [
        GoRoute(path: '/', builder: (_, __) => const SettingsView()),
      ],
    );
    await tester.pumpAndSettle();
  }

  final guardianOnly = [
    'settings.active_sessions',
    'settings.download_my_data',
    'settings.change_password',
    'profile.settings.delete_account_tile',
  ];

  testWidgets('the guardian sees sessions, data export, password and delete',
      (tester) async {
    await pump(tester, acting: false);

    for (final key in guardianOnly) {
      expect(find.text(key.tr()), findsOneWidget, reason: key);
    }
  });

  testWidgets('while acting those four entries are gone', (tester) async {
    await pump(tester, acting: true);

    for (final key in guardianOnly) {
      expect(find.text(key.tr()), findsNothing, reason: key);
    }
    // El resto de Ajustes sigue disponible.
    expect(find.text('profile.settings.logout_tile'.tr()), findsOneWidget);
    expect(find.text('settings.member_qr'.tr()), findsOneWidget);
  });

  group('supervised teen (FP3-32)', () {
    const teen = UserEntity(
      id: 'teen-1',
      name: 'Ana',
      postRegisterComplete: true,
      serverMode: AccountMode.teenSupervised,
    );

    testWidgets(
        'no sessions, data export, delete account or club change; the '
        'password stays', (tester) async {
      await pump(tester, acting: false, user: teen);

      for (final key in [
        'settings.active_sessions',
        'settings.download_my_data',
        'profile.settings.delete_account_tile',
        'profile.settings.change_club_tile',
      ]) {
        expect(find.text(key.tr()), findsNothing, reason: key);
      }
      expect(find.text('settings.change_password'.tr()), findsOneWidget);
      expect(find.text('profile.settings.logout_tile'.tr()), findsOneWidget);
    });

    testWidgets('an adult still sees the club change', (tester) async {
      await pump(tester, acting: false);

      expect(
        find.text('profile.settings.change_club_tile'.tr()),
        findsOneWidget,
      );
    });
  });
}
