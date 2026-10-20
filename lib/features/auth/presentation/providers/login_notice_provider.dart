import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Avisos de una sola vez que la pantalla de login muestra tras perder la
/// sesión por una causa que la persona debe entender.
enum LoginNotice {
  /// 401 `AUTH_SUPERVISED_ACCESS_REVOKED`: el tutor desactivó, restableció o
  /// cambió el acceso del menor (FP3-32).
  supervisedAccessRevoked,
}

/// Aviso pendiente para el login. Vive en memoria; lo escribe el cierre de
/// sesión por acceso revocado y lo limpia el login al empezar un intento o la
/// propia vista al descartarlo. No es estado de perfil: se escribe JUSTO al
/// cerrar la sesión y debe sobrevivir a la purga de perfil.
final loginNoticeProvider = StateProvider<LoginNotice?>((ref) => null);
