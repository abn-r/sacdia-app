import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/auth/social_auth_client.dart';
import 'package:sacdia_app/core/auth/social_auth_provider.dart';
import 'package:sacdia_app/core/auth/social_credential.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/features/auth/domain/entities/delete_account_reauth.dart';
import 'package:sacdia_app/features/profile/presentation/widgets/delete_account_confirm_dialog.dart';

class _FakeSocialAuthClient implements SocialAuthClient {
  _FakeSocialAuthClient(this.supported);

  final Set<SocialProvider> supported;

  /// Si se pasa, `signIn` queda pendiente hasta que se complete.
  Completer<SocialCredential?>? gate;
  SocialCredential? result;
  Object? error;
  final requested = <SocialProvider>[];

  @override
  Future<SocialCredential?> signIn(SocialProvider provider) async {
    requested.add(provider);
    if (error != null) throw error!;
    if (gate != null) return gate!.future;
    return result;
  }

  @override
  bool supports(SocialProvider provider) => supported.contains(provider);
}

const _word = 'ELIMINAR';
const _googleCredential = SocialCredential(
  provider: SocialProvider.google,
  idToken: 'g-token',
  nonce: 'n-1',
);

const _googleLabel = 'profile.settings.delete_account_confirm_google';
const _appleLabel = 'profile.settings.delete_account_confirm_apple';
const _deleteLabel = 'profile.settings.delete_account_tile';

/// Abre el diálogo desde un botón y deja el resultado en [result].
class _Result {
  bool popped = false;
  DeleteAccountReauth? value;
}

Future<_Result> _open(
  WidgetTester tester,
  _FakeSocialAuthClient client, {
  List<SocialProvider> connected = const [
    SocialProvider.google,
    SocialProvider.apple,
  ],
}) async {
  final result = _Result();
  // El diálogo scrollea en pantallas chicas; una superficie alta deja todos
  // los controles al alcance de los taps.
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [socialAuthClientProvider.overrideWithValue(client)],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result.value = await showDialog<DeleteAccountReauth>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => DeleteAccountConfirmDialog(
                      confirmationWord: _word,
                      connectedProviders: connected,
                    ),
                  );
                  result.popped = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

Future<void> _typeWord(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).first, _word);
  await tester.pump();
}

SacButton _button(WidgetTester tester, String label) =>
    tester.widget<SacButton>(
      find
          .ancestor(of: find.text(label), matching: find.byType(SacButton))
          .first,
    );

void main() {
  testWidgets('offers only the connected providers the device supports', (
    tester,
  ) async {
    await _open(tester, _FakeSocialAuthClient({SocialProvider.google}));

    expect(find.text(_googleLabel), findsOneWidget);
    expect(find.text(_appleLabel), findsNothing);
    expect(
      find.text('profile.settings.delete_account_or_confirm_with'),
      findsOneWidget,
    );
  });

  testWidgets('hides the provider section when none is usable', (tester) async {
    await _open(
      tester,
      _FakeSocialAuthClient({SocialProvider.apple}),
      connected: const [SocialProvider.google],
    );

    expect(find.text(_googleLabel), findsNothing);
    expect(find.text(_appleLabel), findsNothing);
    expect(
      find.text('profile.settings.delete_account_or_confirm_with'),
      findsNothing,
    );
  });

  testWidgets('requires the confirmation word before opening the native sheet',
      (tester) async {
    final client = _FakeSocialAuthClient({SocialProvider.google})
      ..result = _googleCredential;
    final result = await _open(tester, client);

    await tester.tap(find.text(_googleLabel));
    await tester.pumpAndSettle();

    expect(client.requested, isEmpty);
    expect(
      find.text('profile.settings.delete_account_error_type_wrong'),
      findsOneWidget,
    );
    expect(result.popped, isFalse);
  });

  testWidgets('a social confirmation pops SocialReauth with the credential', (
    tester,
  ) async {
    final client = _FakeSocialAuthClient({SocialProvider.google})
      ..result = _googleCredential;
    final result = await _open(tester, client);

    await _typeWord(tester);
    await tester.tap(find.text(_googleLabel));
    await tester.pumpAndSettle();

    expect(client.requested, [SocialProvider.google]);
    expect(result.popped, isTrue);
    expect(result.value, isA<SocialReauth>());
    expect((result.value as SocialReauth).credential, _googleCredential);
  });

  testWidgets('cancelling the native sheet stays in the dialog without error', (
    tester,
  ) async {
    final client = _FakeSocialAuthClient({SocialProvider.google})
      ..result = null;
    final result = await _open(tester, client);

    await _typeWord(tester);
    await tester.tap(find.text(_googleLabel));
    await tester.pumpAndSettle();

    expect(client.requested, [SocialProvider.google]);
    expect(result.popped, isFalse);
    expect(find.text(_deleteLabel), findsOneWidget);
    expect(find.text('errors.social_signin_failed'), findsNothing);
    // Los botones vuelven a estar disponibles.
    expect(_button(tester, _googleLabel).isEnabled, isTrue);
  });

  testWidgets('an SDK failure shows an error and keeps the dialog', (
    tester,
  ) async {
    final client = _FakeSocialAuthClient({SocialProvider.google})
      ..error = SocialAuthException(SocialProvider.google, 'boom');
    final result = await _open(tester, client);

    await _typeWord(tester);
    await tester.tap(find.text(_googleLabel));
    await tester.pumpAndSettle();

    expect(result.popped, isFalse);
    expect(find.text('errors.social_signin_failed'), findsOneWidget);
    expect(_button(tester, _googleLabel).isEnabled, isTrue);
  });

  testWidgets('blocks double taps and the destructive action while busy', (
    tester,
  ) async {
    final gate = Completer<SocialCredential?>();
    final client = _FakeSocialAuthClient({
      SocialProvider.google,
      SocialProvider.apple,
    })
      ..gate = gate;
    final result = await _open(tester, client);

    await _typeWord(tester);
    await tester.tap(find.text(_googleLabel));
    await tester.pump();

    // Hoja nativa abierta: todo bloqueado.
    expect(_button(tester, _googleLabel).isLoading, isTrue);
    expect(_button(tester, _appleLabel).isEnabled, isFalse);
    expect(_button(tester, _deleteLabel).onPressed, isNull);
    expect(_button(tester, 'common.cancel').onPressed, isNull);

    // El texto aparece dos veces mientras el botón hace el cross-fade a loading.
    await tester.tap(find.text(_googleLabel).first, warnIfMissed: false);
    await tester.tap(find.text(_appleLabel).first, warnIfMissed: false);
    await tester.pump();
    expect(client.requested, [SocialProvider.google]);

    gate.complete(_googleCredential);
    await tester.pumpAndSettle();

    expect(result.popped, isTrue);
    expect(result.value, isA<SocialReauth>());
  });

  testWidgets('the password path pops PasswordReauth', (tester) async {
    final client = _FakeSocialAuthClient({SocialProvider.google});
    final result = await _open(tester, client);

    await _typeWord(tester);
    await tester.enterText(find.byType(TextFormField).last, ' s3cret ');
    await tester.tap(find.text(_deleteLabel));
    await tester.pumpAndSettle();

    expect(result.value, isA<PasswordReauth>());
    expect((result.value as PasswordReauth).password, 's3cret');
    expect(client.requested, isEmpty);
  });

  testWidgets('an empty password asks for password or linked account', (
    tester,
  ) async {
    final client = _FakeSocialAuthClient({SocialProvider.google});
    final result = await _open(tester, client);

    await _typeWord(tester);
    await tester.tap(find.text(_deleteLabel));
    await tester.pumpAndSettle();

    expect(result.popped, isFalse);
    expect(
      find.text('profile.settings.delete_account_error_no_reauth'),
      findsOneWidget,
    );
  });

  testWidgets('an empty password asks only for the password without providers',
      (tester) async {
    final client = _FakeSocialAuthClient({});
    await _open(tester, client);

    await _typeWord(tester);
    await tester.tap(find.text(_deleteLabel));
    await tester.pumpAndSettle();

    expect(
      find.text('profile.settings.delete_account_error_no_password'),
      findsOneWidget,
    );
  });
}
