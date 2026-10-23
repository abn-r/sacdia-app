import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dependiente por el que el tutor está actuando.
///
/// Solo lleva lo necesario para el encabezado `X-Acting-For` y el banner. Todo
/// lo demás se lee de `/auth/me` con el encabezado ya puesto.
class ActingDependent extends Equatable {
  /// `user_id` del dependiente: es el valor de `X-Acting-For`.
  final String userId;

  /// Nombre de pila para el banner ("Viendo como Ana").
  final String? firstName;

  const ActingDependent({required this.userId, this.firstName});

  @override
  List<Object?> get props => [userId, firstName];
}

/// Estado de "actuar por un dependiente" (perfil activo).
///
/// **Solo en memoria.** Nunca se escribe en disco ni en SharedPreferences: al
/// matar la app siempre se arranca como el tutor (FP-46). El único rastro que
/// se deja en disco es la bandera `acting_dirty` (ver [kActingDirtyPrefsKey]),
/// que no identifica a nadie y solo avisa de que hay que purgar cachés.
///
/// [generation] sube en cada cambio de perfil (entrar, salir o cambiar de
/// dependiente). Cada petición se sella con la generación vigente al salir y
/// su respuesta se descarta si la generación cambió mientras volaba, para que
/// los datos de Ana nunca lleguen a la vista de Luis (FP-54).
class ActingForSession extends ValueNotifier<ActingDependent?> {
  ActingForSession() : super(null);

  int _generation = 0;

  /// Identifica el "perfil vigente". Cambia en cada [enter] y [exit].
  int get generation => _generation;

  bool get isActing => value != null;

  String? get dependentUserId => value?.userId;

  /// Empieza a actuar por [dependent] (o cambia de dependiente).
  void enter(ActingDependent dependent) {
    _generation++;
    final changed = value != dependent;
    value = dependent;
    // Si se entra al mismo dependiente `value` no cambia y ValueNotifier no
    // notifica; la generación sí cambió, así que se avisa igualmente.
    if (!changed) notifyListeners();
  }

  /// Vuelve al tutor. No hace nada si ya no se actuaba por nadie.
  void exit() {
    if (value == null) return;
    _generation++;
    value = null;
  }
}

/// Clave de SharedPreferences de la bandera `acting_dirty`.
///
/// Se pone a `true` al empezar a actuar y a `false` al volver al tutor con
/// los cachés ya purgados. Si está en `true` al arrancar, la app murió actuando
/// y hay que borrar los cachés de disco del usuario (FP-51).
const String kActingDirtyPrefsKey = 'acting_dirty';

/// Sesión de "actuar por" compartida por el cliente HTTP y el `AuthNotifier`.
///
/// `Provider` sin `autoDispose`: vive lo que vive la app. No pertenece al
/// registro de purga: es justamente el estado que la purga no debe tocar.
final actingForSessionProvider = Provider<ActingForSession>((ref) {
  final session = ActingForSession();
  ref.onDispose(session.dispose);
  return session;
});
