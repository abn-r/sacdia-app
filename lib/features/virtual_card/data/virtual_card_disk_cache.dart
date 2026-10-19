import '../../../core/storage/local_storage.dart';

/// Prefijo de las claves de SharedPreferences donde se guarda la credencial
/// virtual (`virtual_card_cache_<userId>`).
const String kVirtualCardCacheKeyPrefix = 'virtual_card_cache_';

/// Borra TODAS las credenciales virtuales guardadas en disco (la del tutor y
/// cualquier otra), sin importar de quién sean.
///
/// La credencial lleva PII (nombre, foto, club) y el token QR. Se purga en
/// cada cambio de perfil, al cerrar sesión y en el arranque tras morir
/// actuando (FP-49, FP-51, FP-53): el costo es que el tutor pierde su
/// credencial sin conexión hasta la siguiente descarga.
Future<void> clearVirtualCardDiskCache(LocalStorage storage) {
  final keys = storage
      .getKeys()
      .where((key) => key.startsWith(kVirtualCardCacheKeyPrefix))
      .toList(growable: false);
  return Future.wait(keys.map(storage.remove));
}
