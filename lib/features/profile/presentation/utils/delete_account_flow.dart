import '../../../auth/domain/entities/delete_account_reauth.dart';

/// Qué pasó con el aviso de dependientes.
enum DependentsAck {
  /// No hay menores a cargo (o no se pudieron consultar): no se mostró aviso.
  none,

  /// Se mostró el aviso y el tutor lo aceptó.
  acknowledged,

  /// Se mostró el aviso y el tutor canceló.
  cancelled,
}

/// Pasos de interfaz que necesita [DeleteAccountFlow]. Se inyectan para poder
/// probar el orden sin montar la pantalla de ajustes.
typedef ConfirmDependents = Future<DependentsAck> Function({
  required bool refresh,
});
typedef PromptReauth = Future<DeleteAccountReauth?> Function();
typedef DeleteWithReauth = Future<DeleteAccountResult> Function(
  DeleteAccountReauth reauth,
);

/// Orquesta el borrado de cuenta con menores a cargo (FP-66).
///
/// 1. Avisa de los dependientes ANTES de pedir la contraseña
///    (`deletion-impact`). Sin dependientes no hay paso extra.
/// 2. Pide la reautenticación y borra, enviando `acknowledge_dependents` solo
///    si el tutor aceptó el aviso.
/// 3. Si el servidor igualmente responde 409
///    `AUTH_DELETE_DEPENDENTS_ACK_REQUIRED` (llegó un menor entremedias),
///    vuelve a mostrar el aviso con la lista fresca y reintenta una vez
///    aceptado. El manejo es solo por código: no depende de `details`.
class DeleteAccountFlow {
  DeleteAccountFlow({
    required this.confirmDependents,
    required this.promptReauth,
    required this.delete,
    this.maxAckRetries = 2,
  });

  final ConfirmDependents confirmDependents;
  final PromptReauth promptReauth;
  final DeleteWithReauth delete;

  /// Cuántas veces se reintenta tras un 409 antes de rendirse (evita un bucle
  /// si el servidor insiste).
  final int maxAckRetries;

  /// Devuelve `null` si el usuario canceló en cualquier paso; si no, el
  /// resultado del último intento de borrado.
  Future<DeleteAccountResult?> run() async {
    final first = await confirmDependents(refresh: false);
    if (first == DependentsAck.cancelled) return null;
    var acknowledged = first == DependentsAck.acknowledged;

    var retries = 0;
    while (true) {
      final reauth = await promptReauth();
      if (reauth == null) return null;

      final result = await delete(
        acknowledged ? reauth.acknowledged() : reauth,
      );
      if (!result.needsDependentsAck || retries >= maxAckRetries) {
        return result;
      }
      retries++;

      final again = await confirmDependents(refresh: true);
      if (again == DependentsAck.cancelled) return null;
      // Sin lista que mostrar no se acepta nada a ciegas: el mensaje del 409
      // ("confirma qué pasará con los menores") llega al usuario.
      if (again == DependentsAck.none) return result;
      acknowledged = true;
    }
  }
}
