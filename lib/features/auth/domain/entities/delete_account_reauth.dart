import '../../../../core/auth/social_credential.dart';

/// Cómo se reautentica el usuario antes de borrar la cuenta
/// (`DELETE /auth/me`): contraseña actual o un idToken fresco del proveedor.
sealed class DeleteAccountReauth {
  const DeleteAccountReauth();

  Map<String, dynamic> toBody();
}

class PasswordReauth extends DeleteAccountReauth {
  const PasswordReauth(this.password);

  final String password;

  @override
  Map<String, dynamic> toBody() => {'password': password};
}

class SocialReauth extends DeleteAccountReauth {
  const SocialReauth(this.credential);

  final SocialCredential credential;

  @override
  Map<String, dynamic> toBody() => credential.toReauthBody();
}
