import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/persona/nav_slot.dart';
import 'package:sacdia_app/core/persona/persona.dart';
import 'package:sacdia_app/core/persona/persona_nav_config.dart';
import 'package:sacdia_app/core/persona/persona_resolver.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';

/// Synchronously resolves the active [Persona] from the current auth state.
///
/// Watches [authNotifierProvider] narrowed to the user snapshot so a full
/// provider rebuild only happens when the user object itself changes (e.g.
/// after login or a context switch). Rebuilds reactively cover:
///   - Login completes → user goes from null to UserEntity
///   - Context switch → [AuthorizationSnapshot.activeAssignmentId] changes,
///     producing a new [UserEntity] value from [AuthNotifier.switchContext].
///
/// Returns [Persona.miembro] when the user is null or has no recognisable role.
final currentPersonaProvider = Provider<Persona>((ref) {
  final user = ref.watch(
    authNotifierProvider.select((v) => v.valueOrNull),
  );
  return resolvePersona(user?.authorization);
});

/// Returns the ordered list of [NavSlot]s for the current [Persona].
///
/// Rebuilds only when [currentPersonaProvider] emits a different [Persona].
/// Because [Persona] is an enum with value equality, unchanged personas
/// short-circuit via Riverpod's default equality check — no downstream
/// rebuild on unrelated auth changes (e.g. FCM token refresh).
///
/// Falls back to [Persona.miembro] config if the persona key is somehow
/// absent from [personaNavConfig] (should never happen in practice).
final personaNavSlotsProvider = Provider<List<NavSlot>>((ref) {
  final persona = ref.watch(currentPersonaProvider);
  return personaNavConfig[persona] ?? personaNavConfig[Persona.miembro]!;
});
