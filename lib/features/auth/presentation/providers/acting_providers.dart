import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/acting_for_session.dart';
import '../../domain/entities/user_entity.dart';

/// Identidad del tutor mientras se actúa por un dependiente.
///
/// `authNotifierProvider` pasa a ser el dependiente durante el modo "actuar
/// por", así que el selector de perfiles ("Tú · Ana · Luis") y el banner
/// necesitan una foto del tutor. Solo vive en memoria y se borra al volver al
/// tutor o al cerrar sesión. NO es un caché: nunca se escribe en disco.
final guardianUserProvider = StateProvider<UserEntity?>((ref) => null);

/// Avisos de una sola vez que la UI global muestra y descarta (p. ej. el acceso
/// a un perfil se revocó). Los lee `ActingNoticeListener`.
enum ActingNotice {
  /// 403 `ACTING_FOR_FORBIDDEN`: "ya no tienes acceso a este perfil".
  accessRevoked,
}

final actingNoticeProvider = StateProvider<ActingNotice?>((ref) => null);

/// Dependiente por el que se actúa ahora, o `null` si se ve el perfil propio.
///
/// Reactivo: se recalcula cada vez que [ActingForSession] cambia. Pensado para
/// el banner, el selector y los redirects de rutas bloqueadas.
final actingDependentProvider = Provider<ActingDependent?>((ref) {
  final session = ref.watch(actingForSessionProvider);
  void onChange() => ref.invalidateSelf();
  session.addListener(onChange);
  ref.onDispose(() => session.removeListener(onChange));
  return session.value;
});
