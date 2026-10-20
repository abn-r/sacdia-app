import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Por qué el teléfono volvió a la pantalla de vinculación (FP3-52).
enum DeviceNotice {
  /// 401 `AUTH_DEVICE_REVOKED` o refresh muerto: el tutor desvinculó el
  /// teléfono (o dejó de ser elegible).
  unpaired,

  /// 401 `AUTH_DEVICE_SESSION_EXPIRED`: la vinculación llegó a su tope absoluto
  /// y hay que vincular de nuevo.
  sessionExpired,
}

/// Aviso de una sola vez para la pantalla de vinculación. Vive en memoria; lo
/// escribe el cierre de la sesión del dispositivo y lo descarta la propia
/// pantalla. No es estado de perfil: se escribe JUSTO al cerrar la sesión y
/// debe sobrevivir a la purga de perfil.
final deviceNoticeProvider = StateProvider<DeviceNotice?>((ref) => null);
