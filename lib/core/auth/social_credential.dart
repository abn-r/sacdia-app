import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Proveedores de login social soportados por el backend
/// (`POST /auth/oauth/:provider/token`).
enum SocialProvider {
  google('google'),
  apple('apple');

  const SocialProvider(this.wireName);

  /// Segmento de ruta y valor de `providerId` en el backend.
  final String wireName;
}

/// Resultado del SDK nativo listo para enviar al backend.
///
/// - [nonce] es el valor en claro. A Google y a Apple se les entrega
///   `sha256Hex(nonce)`, que ambos copian tal cual al `idToken`; el backend
///   compara el claim `nonce` contra el hash del valor en claro que recibe.
/// - [authorizationCode] solo Apple: el backend lo canjea por el refresh
///   token que necesita para revocar al borrar la cuenta.
/// - [givenName]/[familyName] solo Apple y solo en el primer login.
class SocialCredential {
  const SocialCredential({
    required this.provider,
    required this.idToken,
    required this.nonce,
    this.authorizationCode,
    this.givenName,
    this.familyName,
  });

  final SocialProvider provider;
  final String idToken;
  final String nonce;
  final String? authorizationCode;
  final String? givenName;
  final String? familyName;

  /// Cuerpo de `POST /auth/oauth/:provider/token` (SocialTokenSignInDto).
  Map<String, dynamic> toSignInBody() {
    final fullName = <String, String>{
      if (givenName != null && givenName!.isNotEmpty) 'givenName': givenName!,
      if (familyName != null && familyName!.isNotEmpty)
        'familyName': familyName!,
    };
    return {
      'idToken': idToken,
      'nonce': nonce,
      if (authorizationCode != null) 'authorizationCode': authorizationCode,
      if (fullName.isNotEmpty) 'fullName': fullName,
    };
  }

  /// Cuerpo de re-autenticación para `DELETE /auth/me`.
  Map<String, dynamic> toReauthBody() => {
        'provider': provider.wireName,
        'idToken': idToken,
        'nonce': nonce,
      };
}

final _random = Random.secure();

/// 32 bytes aleatorios en base64url (43 chars). Uno por intento de login.
String generateNonce() {
  final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
  return base64UrlEncode(bytes).replaceAll('=', '');
}

/// SHA-256 en hex minúsculas — formato que espera Apple y el backend.
String sha256Hex(String value) => sha256.convert(utf8.encode(value)).toString();
