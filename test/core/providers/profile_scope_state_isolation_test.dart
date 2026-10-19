import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/providers/profile_scope_registry.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor.dart';
import 'package:sacdia_app/features/honors/presentation/providers/honors_providers.dart';
import 'package:sacdia_app/features/master_honors/presentation/providers/master_honor_modal_queue_provider.dart';
import 'package:sacdia_app/features/qr/domain/entities/qr_member_token.dart';
import 'package:sacdia_app/features/qr/presentation/providers/qr_member_token_provider.dart';

/// C2 / W3 (verify 2b): estado sin `autoDispose` que sobrevivía al cambio de
/// perfil. Usa el registro REAL (`profileScopedProviders`) y la misma
/// invalidación que ejecuta `AuthNotifier.switchProfile`, no centinelas.

class _TokenNotifier extends QrMemberTokenNotifier {
  _TokenNotifier(this.tokens);

  final List<String> tokens;

  @override
  Future<QrMemberToken> build() async => QrMemberToken(
        token: tokens.removeAt(0),
        expiresAt: DateTime.utc(2099, 1, 1),
        expiresIn: 300,
      );
}

/// Lo que hace `purgeProfileScopeProviders` con el registro real. Se invalida
/// desde el contenedor porque, dentro de un `Ref`, los asserts de debug de
/// Riverpod instancian cada provider del registro (decenas, con red).
void _purge(ProviderContainer container) {
  for (final provider in profileScopedProviders) {
    container.invalidate(provider);
  }
}

UserHonor _honor(String userId) => UserHonor(
      id: 1,
      honorId: 42,
      userId: userId,
      completionMode: HonorCompletionMode.external,
      date: DateTime.utc(2026, 1, 1),
    );

void main() {
  test(
      'the guardian completion-mode override is not rendered as the '
      "dependent's enrollment after a switch (C2)", () async {
    final container = ProviderContainer(
      overrides: [
        // Ana no tiene inscripción en la especialidad 42.
        sectionScopedUserHonorsProvider.overrideWithValue(
          const AsyncValue<List<UserHonor>>.data([]),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(userHonorForHonorProvider(42), (_, __) {});

    // La tutora cambia el modo de cumplimiento de la especialidad 42.
    container.read(honorCompletionModeOverrideProvider.notifier).state = {
      42: _honor('guardian-1'),
    };
    expect(container.read(userHonorForHonorProvider(42))?.userId, 'guardian-1');

    // Entra a Ana: la misma purga que corre en switchProfile.
    _purge(container);

    expect(
      container.read(userHonorForHonorProvider(42)),
      isNull,
      reason: "Ana must not see the guardian's UserHonor as her own",
    );
    expect(container.read(honorCompletionModeOverrideProvider), isEmpty);
  });

  test('the member QR token of the previous profile is dropped (W3)', () async {
    final tokens = ['guardian-token', 'ana-token'];
    final container = ProviderContainer(
      overrides: [
        qrMemberTokenProvider.overrideWith(() => _TokenNotifier(tokens)),
      ],
    );
    addTearDown(container.dispose);
    container.listen(qrMemberTokenProvider, (_, __) {});

    expect((await container.read(qrMemberTokenProvider.future)).token,
        'guardian-token');

    _purge(container);

    expect(
      (await container.read(qrMemberTokenProvider.future)).token,
      'ana-token',
      reason: "Ana's card must never fall back to the guardian's QR token",
    );
  });

  test('the master honor modal queue is emptied on a switch (W3)', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(masterHonorModalQueueProvider, (_, __) {});
    container.read(masterHonorModalQueueProvider.notifier).enqueue(
          const MasterHonorModalEvent(
            transition: MasterHonorChangeTransition.awarded,
            masterHonorIds: ['1'],
            masterHonorNames: ['Maestría'],
          ),
        );
    expect(container.read(masterHonorModalQueueProvider).queue, isNotEmpty);

    _purge(container);

    expect(container.read(masterHonorModalQueueProvider).queue, isEmpty);
  });
}
