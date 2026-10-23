import '../../../../core/auth/social_credential.dart';

/// Cómo se reautentica el usuario antes de borrar la cuenta
/// (`DELETE /auth/me`): contraseña actual o un idToken fresco del proveedor.
///
/// [acknowledgeDependents] es `true` cuando el tutor vio qué pasará con cada
/// menor a su cargo (`GET /guardianships/me/deletion-impact`) y lo acepta; el
/// backend lo exige si hay dependientes (`AUTH_DELETE_DEPENDENTS_ACK_REQUIRED`).
sealed class DeleteAccountReauth {
  const DeleteAccountReauth({this.acknowledgeDependents = false});

  final bool acknowledgeDependents;

  Map<String, dynamic> get _credentials;

  Map<String, dynamic> toBody() => {
        ..._credentials,
        if (acknowledgeDependents) 'acknowledge_dependents': true,
      };

  /// La misma reautenticación, con el aviso de dependientes aceptado.
  DeleteAccountReauth acknowledged();
}

class PasswordReauth extends DeleteAccountReauth {
  const PasswordReauth(this.password, {super.acknowledgeDependents});

  final String password;

  @override
  Map<String, dynamic> get _credentials => {'password': password};

  @override
  PasswordReauth acknowledged() =>
      PasswordReauth(password, acknowledgeDependents: true);
}

class SocialReauth extends DeleteAccountReauth {
  const SocialReauth(this.credential, {super.acknowledgeDependents});

  final SocialCredential credential;

  @override
  Map<String, dynamic> get _credentials => credential.toReauthBody();

  @override
  SocialReauth acknowledged() =>
      SocialReauth(credential, acknowledgeDependents: true);
}

/// Resultado de `AuthNotifier.deleteAccountWithResult`.
class DeleteAccountResult {
  const DeleteAccountResult({this.errorMessage, this.errorCode});

  const DeleteAccountResult.success()
      : errorMessage = null,
        errorCode = null;

  /// Mensaje listo para mostrar; `null` si se borró.
  final String? errorMessage;

  /// Código de negocio del backend, si el fallo lo trae.
  final String? errorCode;

  bool get isSuccess => errorMessage == null;

  /// El servidor pide que el tutor acepte primero el aviso de dependientes.
  bool get needsDependentsAck => errorCode == kDeleteDependentsAckRequiredCode;
}

const String kDeleteDependentsAckRequiredCode =
    'AUTH_DELETE_DEPENDENTS_ACK_REQUIRED';
