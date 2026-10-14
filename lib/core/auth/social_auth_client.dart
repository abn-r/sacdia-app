import 'dart:io' show Platform;

import 'package:google_sign_in/google_sign_in.dart';
// El paquete exporta su propio generateNonce(); se usa el de social_credential.
import 'package:sign_in_with_apple/sign_in_with_apple.dart' hide generateNonce;

import '../utils/app_logger.dart';
import 'social_credential.dart';

/// Abre la hoja nativa del proveedor y devuelve el `idToken`.
///
/// Devuelve `null` cuando el usuario cancela. Cualquier otro fallo del SDK
/// se propaga como [SocialAuthException].
abstract class SocialAuthClient {
  Future<SocialCredential?> signIn(SocialProvider provider);

  /// Google en ambas plataformas; Apple solo en iOS (spec D5).
  bool supports(SocialProvider provider);
}

class SocialAuthException implements Exception {
  SocialAuthException(this.provider, this.message);

  final SocialProvider provider;
  final String message;

  @override
  String toString() => 'SocialAuthException(${provider.wireName}): $message';
}

class NativeSocialAuthClient implements SocialAuthClient {
  NativeSocialAuthClient({required String googleServerClientId})
      : _googleServerClientId = googleServerClientId;

  static const _tag = 'SocialAuth';

  final String _googleServerClientId;

  @override
  bool supports(SocialProvider provider) => switch (provider) {
        SocialProvider.google => _googleServerClientId.isNotEmpty,
        SocialProvider.apple => Platform.isIOS,
      };

  @override
  Future<SocialCredential?> signIn(SocialProvider provider) {
    if (!supports(provider)) {
      throw SocialAuthException(provider, 'not supported on this platform');
    }
    return switch (provider) {
      SocialProvider.google => _signInWithGoogle(),
      SocialProvider.apple => _signInWithApple(),
    };
  }

  Future<SocialCredential?> _signInWithGoogle() async {
    final nonce = generateNonce();
    try {
      // google_sign_in 7 fija el nonce en initialize(); se reinicializa por
      // intento para que cada idToken lleve un nonce nuevo. Google copia el
      // valor tal cual al claim `nonce` del idToken, y el backend lo compara
      // contra sha256Hex(nonce): por eso se entrega el hash al SDK y se
      // devuelve el nonce en claro en la credencial.
      await GoogleSignIn.instance.initialize(
        serverClientId: _googleServerClientId,
        nonce: sha256Hex(nonce),
      );
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw SocialAuthException(SocialProvider.google, 'no idToken returned');
      }
      return SocialCredential(
        provider: SocialProvider.google,
        idToken: idToken,
        nonce: nonce,
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        AppLogger.i('Google sign-in cancelado', tag: _tag);
        return null;
      }
      AppLogger.w(
        'Google sign-in falló: ${e.code} ${e.description}',
        tag: _tag,
      );
      throw SocialAuthException(
        SocialProvider.google,
        e.description ?? e.code.name,
      );
    }
  }

  Future<SocialCredential?> _signInWithApple() async {
    final nonce = generateNonce();
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        // Apple embebe este valor tal cual en el idToken; el backend compara
        // contra sha256Hex(nonce) y recibe el nonce en claro.
        nonce: sha256Hex(nonce),
      );
      final idToken = credential.identityToken;
      if (idToken == null || idToken.isEmpty) {
        throw SocialAuthException(
          SocialProvider.apple,
          'no identityToken returned',
        );
      }
      return SocialCredential(
        provider: SocialProvider.apple,
        idToken: idToken,
        nonce: nonce,
        authorizationCode: credential.authorizationCode,
        givenName: credential.givenName,
        familyName: credential.familyName,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        AppLogger.i('Apple sign-in cancelado', tag: _tag);
        return null;
      }
      AppLogger.w('Apple sign-in falló: ${e.code} ${e.message}', tag: _tag);
      throw SocialAuthException(SocialProvider.apple, e.message);
    }
  }
}
