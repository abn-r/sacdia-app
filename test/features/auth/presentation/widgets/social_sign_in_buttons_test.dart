import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/auth/social_auth_client.dart';
import 'package:sacdia_app/core/auth/social_auth_provider.dart';
import 'package:sacdia_app/core/auth/social_credential.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/auth/presentation/widgets/social_sign_in_buttons.dart';

class _FakeSocialAuthClient implements SocialAuthClient {
  _FakeSocialAuthClient(this.supported);

  final Set<SocialProvider> supported;

  @override
  Future<SocialCredential?> signIn(SocialProvider provider) async => null;

  @override
  bool supports(SocialProvider provider) => supported.contains(provider);
}

class _FakeAuthNotifier extends AuthNotifier {
  final googleGate = Completer<SocialSignInResult>();
  int googleCalls = 0;
  int appleCalls = 0;

  @override
  Future<UserEntity?> build() async => null;

  @override
  Future<SocialSignInResult> signInWithGoogle() {
    googleCalls++;
    return googleGate.future;
  }

  @override
  Future<SocialSignInResult> signInWithApple() async {
    appleCalls++;
    return SocialSignInResult.cancelled;
  }
}

Widget _host(
  Set<SocialProvider> supported,
  _FakeAuthNotifier notifier, {
  bool enabled = true,
}) {
  return ProviderScope(
    overrides: [
      socialAuthClientProvider.overrideWithValue(
        _FakeSocialAuthClient(supported),
      ),
      authNotifierProvider.overrideWith(() => notifier),
    ],
    child: MaterialApp(
      home: Scaffold(body: SocialSignInButtons(enabled: enabled)),
    ),
  );
}

void main() {
  testWidgets('shows only the supported providers', (tester) async {
    final notifier = _FakeAuthNotifier();
    await tester.pumpWidget(_host({SocialProvider.google}, notifier));

    expect(find.byType(SacButton), findsOneWidget);
    expect(find.text('auth.continue_with_google'), findsOneWidget);
    expect(find.text('auth.continue_with_apple'), findsNothing);
  });

  testWidgets('renders nothing when no provider is supported', (tester) async {
    final notifier = _FakeAuthNotifier();
    await tester.pumpWidget(_host({}, notifier));

    expect(find.byType(SacButton), findsNothing);
    expect(find.text('auth.or_continue_with'), findsNothing);
  });

  testWidgets('a second tap while the first is pending is ignored', (
    tester,
  ) async {
    final notifier = _FakeAuthNotifier();
    await tester.pumpWidget(
      _host({SocialProvider.google, SocialProvider.apple}, notifier),
    );

    await tester.tap(find.text('auth.continue_with_google'));
    await tester.pump();

    // Un segundo toque, aunque llegue al callback saltándose el estado
    // deshabilitado del botón, no debe abrir otra hoja.
    final buttons0 = tester.widgetList<SacButton>(find.byType(SacButton));
    for (final button in buttons0) {
      button.onPressed?.call();
    }
    await tester.pump();

    expect(notifier.googleCalls, 1);
    expect(notifier.appleCalls, 0);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SocialSignInButtons)),
    );
    expect(container.read(socialSignInInFlightProvider), isTrue);

    final buttons = tester.widgetList<SacButton>(find.byType(SacButton));
    expect(buttons.map((b) => b.isLoading), [true, false]);
    expect(buttons.map((b) => b.isEnabled), [false, false]);

    notifier.googleGate.complete(SocialSignInResult.cancelled);
    await tester.pump();
    expect(container.read(socialSignInInFlightProvider), isFalse);

    final after = tester.widgetList<SacButton>(find.byType(SacButton));
    expect(after.map((b) => b.isLoading), [false, false]);
    expect(after.map((b) => b.isEnabled), [true, true]);
  });
}
