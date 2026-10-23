import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/auth/presentation/views/login_view.dart';

class _CountingAuthNotifier extends AuthNotifier {
  int signInCalls = 0;

  @override
  Future<UserEntity?> build() async => null;

  @override
  Future<bool> signIn({
    required String identifier,
    required String password,
  }) async {
    signInCalls++;
    return true;
  }
}

void main() {
  Future<_CountingAuthNotifier> pumpLogin(
    WidgetTester tester, {
    required bool socialInFlight,
  }) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final notifier = _CountingAuthNotifier();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(() => notifier),
          socialInFlightOverride(socialInFlight),
        ],
        child: const MaterialApp(home: LoginView()),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'ana@example.com');
    await tester.enterText(fields.at(1), 'Password123');
    await tester.pump();
    return notifier;
  }

  SacButton primaryButton(WidgetTester tester) =>
      tester.widgetList<SacButton>(find.byType(SacButton)).first;

  testWidgets('email sign-in is blocked while a social sign-in is in flight', (
    tester,
  ) async {
    final notifier = await pumpLogin(tester, socialInFlight: true);

    expect(primaryButton(tester).isEnabled, isFalse);

    // Aunque el callback se invoque saltándose el estado deshabilitado
    // (enter del teclado), `_signIn` no debe lanzar un segundo login.
    primaryButton(tester).onPressed?.call();
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();

    expect(notifier.signInCalls, 0);
  });

  testWidgets('email sign-in works when no social sign-in is in flight', (
    tester,
  ) async {
    final notifier = await pumpLogin(tester, socialInFlight: false);

    expect(primaryButton(tester).isEnabled, isTrue);
    primaryButton(tester).onPressed?.call();
    await tester.pump();

    expect(notifier.signInCalls, 1);
  });
}

Override socialInFlightOverride(bool value) =>
    socialSignInInFlightProvider.overrideWith((ref) => value);
