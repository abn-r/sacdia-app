import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_text_field.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/profile/presentation/utils/change_password_flow.dart';
import 'package:sacdia_app/providers/storage_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../family/family_test_harness.dart';

/// Auth que contesta lo que el test decida al cambiar la contraseña.
class _PasswordAuth extends FakeAuthNotifier {
  _PasswordAuth(this.answer);

  /// `null` = éxito; si no, el mensaje de error del servidor.
  final String? answer;
  final calls = <({String current, String next})>[];

  @override
  Future<String?> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    calls.add((current: currentPassword, next: newPassword));
    return answer;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initLocalization);

  // Cumple las cuatro reglas: 12 caracteres, mayúscula y minúscula, número y
  // un carácter especial.
  const strong = 'Abcdefghij1@';

  Future<_PasswordAuth> pump(WidgetTester tester, {String? answer}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = _PasswordAuth(answer);
    await pumpFamilyApp(
      tester,
      overrides: [
        authNotifierProvider.overrideWith(() => auth),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => runChangePasswordFlow(context, ref),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ],
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return auth;
  }

  Finder checks() => find.byWidgetPredicate(
        (w) =>
            w is HugeIcon && w.icon == HugeIcons.strokeRoundedCheckmarkCircle02,
      );

  Future<void> type(WidgetTester tester, String key, String text) async {
    await tester.enterText(find.byKey(ValueKey(key)), text);
    await tester.pump();
  }

  testWidgets('has current and new password only: no confirm field',
      (tester) async {
    await pump(tester);

    expect(find.byType(SacTextField), findsNWidgets(2));
    expect(find.text('profile.settings.field_current_password'.tr()),
        findsOneWidget);
    expect(
        find.text('profile.settings.field_new_password'.tr()), findsOneWidget);
    // The title and the primary action read the same.
    expect(find.text('profile.settings.change_password_dialog_title'.tr()),
        findsNWidgets(2));
    expect(find.byType(SacButton), findsOneWidget);
  });

  testWidgets('the rules light up as the new password meets them',
      (tester) async {
    await pump(tester);
    expect(checks(), findsNothing);

    // Only the length and the letters.
    await type(tester, 'password-new', 'Abcdefghijkl');
    expect(checks(), findsNWidgets(2));

    // The number joins in.
    await type(tester, 'password-new', 'Abcdefghijk1');
    expect(checks(), findsNWidgets(3));

    await type(tester, 'password-new', strong);
    expect(checks(), findsNWidgets(4));

    // Too short: only the length goes back to pending.
    await type(tester, 'password-new', 'Ab1@');
    expect(checks(), findsNWidgets(3));

    await type(tester, 'password-new', '');
    expect(checks(), findsNothing);
  });

  testWidgets('a wrong current password shows inline and the sheet stays',
      (tester) async {
    const message = 'La contraseña actual no es correcta';
    final auth = await pump(tester, answer: message);

    await type(tester, 'password-current', 'mala');
    await type(tester, 'password-new', strong);
    await tester.tap(find.byType(SacButton));
    await tester.pumpAndSettle();

    expect(auth.calls, hasLength(1));
    expect(auth.calls.single.current, 'mala');
    expect(auth.calls.single.next, strong);
    expect(find.text(message), findsOneWidget);
    // Still open, and no success message.
    expect(find.byType(SacTextField), findsNWidgets(2));
    expect(find.text('profile.settings.password_updated'.tr()), findsNothing);
  });

  testWidgets('a weak new password is stopped before calling the server',
      (tester) async {
    final auth = await pump(tester);

    await type(tester, 'password-current', 'actual');
    await type(tester, 'password-new', 'corta');
    await tester.tap(find.byType(SacButton));
    await tester.pumpAndSettle();

    expect(auth.calls, isEmpty);
    expect(find.byKey(const ValueKey('password-error')), findsOneWidget);
  });

  testWidgets('success closes the sheet and shows the message', (tester) async {
    final auth = await pump(tester);

    await type(tester, 'password-current', 'actual');
    await type(tester, 'password-new', strong);
    await tester.tap(find.byType(SacButton));
    await tester.pumpAndSettle();

    expect(auth.calls, hasLength(1));
    expect(find.byType(SacTextField), findsNothing);
    expect(find.text('profile.settings.password_updated'.tr()), findsOneWidget);
  });
}
