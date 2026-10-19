import '../../../core/storage/local_storage.dart';

/// Prefijo de las claves de SharedPreferences donde el paso 2 del registro
/// recuerda "no tengo alergias / enfermedades / medicinas":
/// `post_registration.health_none.<userId>.<allergies|diseases|medicines>`.
const String kHealthNoneKeyPrefix = 'post_registration.health_none';

/// Clave de una categoría para un usuario.
String healthNoneKey(String userId, String category) =>
    '$kHealthNoneKeyPrefix.$userId.$category';

/// Borra las marcas de salud "ninguna" de todos los usuarios EXCEPTO
/// [keepUserId] (el tutor). Con [keepUserId] nulo borra todas.
///
/// Mientras se actúa por un menor el paso 2 escribe aquí con el id del menor
/// (se deja escribir para que el paso funcione durante la sesión), pero es un
/// dato de salud de un menor: se purga en cada cambio de perfil, al arrancar
/// tras morir actuando y, con [keepUserId] nulo, al cerrar sesión (FP-49).
Future<void> clearHealthNoneFlags(
  LocalStorage storage, {
  String? keepUserId,
}) {
  const scope = '$kHealthNoneKeyPrefix.';
  final keys = storage.getKeys().where((key) {
    if (!key.startsWith(scope)) return false;
    if (keepUserId == null) return true;
    // `<userId>.<categoría>`: el id es todo lo que va antes del último punto.
    final rest = key.substring(scope.length);
    final dot = rest.lastIndexOf('.');
    final owner = dot < 0 ? rest : rest.substring(0, dot);
    return owner != keepUserId;
  }).toList(growable: false);
  return Future.wait(keys.map(storage.remove));
}
