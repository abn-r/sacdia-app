import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_constants.dart';
import '../errors/exceptions.dart';
import '../utils/app_logger.dart';

/// Servicio de autenticación que reemplaza supabase_auth.dart.
///
/// Responsabilidades:
/// - Almacenar / leer / borrar tokens en [FlutterSecureStorage].
/// - Iniciar el flujo OAuth abriendo el URL devuelto por el backend.
/// - Exponer un stream de cambios de estado de autenticación.
///
/// Este servicio NO contacta directamente a Better Auth; toda la
/// comunicación HTTP se realiza a través de [AuthRemoteDataSourceImpl]
/// usando Dio.
class AppAuthService {
  static const _tag = 'AppAuthService';

  final FlutterSecureStorage _secureStorage;
  final StreamController<bool> _authStateController;

  AppAuthService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _authStateController = StreamController<bool>.broadcast();

  // ── Singleton ligero ────────────────────────────────────────────────────────

  static AppAuthService? _instance;

  /// Instancia global de conveniencia.  Usá el provider de Riverpod en vez de
  /// esta propiedad siempre que sea posible.
  static AppAuthService get instance {
    _instance ??= AppAuthService();
    return _instance!;
  }

  // ── Stream de estado ────────────────────────────────────────────────────────

  /// Emite `true` cuando hay un access token válido en almacenamiento,
  /// `false` en caso contrario.
  Stream<bool> get authStateChanges => _authStateController.stream;

  // ── Token storage ───────────────────────────────────────────────────────────

  /// Lee el JWT de acceso (HS256) desde secure storage.
  Future<String?> getStoredAccessToken() async {
    try {
      return await _secureStorage.read(key: AppConstants.tokenKey);
    } catch (e) {
      AppLogger.e('Error al leer access token', tag: _tag, error: e);
      return null;
    }
  }

  /// Lee el session token opaco de Better Auth desde secure storage.
  ///
  /// Antes se llamaba "refresh token". En Better Auth ≥ 1.5.6 es un token
  /// opaco (no JWT) que se usa para renovar la sesión mediante
  /// `POST /auth/refresh` con el header `x-session-token`.
  Future<String?> getStoredSessionToken() async {
    try {
      return await _secureStorage.read(key: AppConstants.refreshTokenKey);
    } catch (e) {
      AppLogger.e('Error al leer session token', tag: _tag, error: e);
      return null;
    }
  }

  /// Persiste el par (accessToken, sessionToken) en secure storage y emite
  /// `true` en el stream de estado de autenticación.
  Future<void> storeTokens({
    required String accessToken,
    String? sessionToken,
    int? expiresAt,
    String? tokenType,
  }) async {
    await _secureStorage.write(key: AppConstants.tokenKey, value: accessToken);
    if (sessionToken != null) {
      await _secureStorage.write(
          key: AppConstants.refreshTokenKey, value: sessionToken);
    }
    if (expiresAt != null) {
      await _secureStorage.write(
          key: AppConstants.expiresAtKey, value: expiresAt.toString());
    }
    if (tokenType != null) {
      await _secureStorage.write(
          key: AppConstants.tokenTypeKey, value: tokenType);
    }
    _authStateController.add(true);
    AppLogger.i('Tokens almacenados', tag: _tag);
  }

  /// Elimina todos los tokens de sesión y emite `false` en el stream.
  Future<void> clearTokens() async {
    await _secureStorage.delete(key: AppConstants.tokenKey);
    await _secureStorage.delete(key: AppConstants.refreshTokenKey);
    await _secureStorage.delete(key: AppConstants.expiresAtKey);
    await _secureStorage.delete(key: AppConstants.tokenTypeKey);
    _authStateController.add(false);
    AppLogger.i('Tokens eliminados', tag: _tag);
  }

  /// Devuelve `true` si el token de acceso ha expirado o no existe.
  ///
  /// La expiración se evalúa comparando la marca de tiempo Unix (segundos)
  /// almacenada en [AppConstants.expiresAtKey] con el tiempo actual.
  Future<bool> isTokenExpired() async {
    try {
      final expiresAtStr =
          await _secureStorage.read(key: AppConstants.expiresAtKey);
      if (expiresAtStr == null) return true;
      final expiresAt = int.tryParse(expiresAtStr) ?? 0;
      return DateTime.now().millisecondsSinceEpoch ~/ 1000 >= expiresAt;
    } catch (e) {
      AppLogger.e('Error al verificar expiración del token', tag: _tag, error: e);
      return true;
    }
  }

  /// Devuelve `true` si existe un access token almacenado Y no ha expirado.
  Future<bool> isLoggedIn() async {
    final token = await getStoredAccessToken();
    if (token == null || token.isEmpty) return false;
    final expired = await isTokenExpired();
    if (expired) {
      AppLogger.w('Token encontrado pero expirado', tag: _tag);
    }
    return !expired;
  }

  // ── OAuth ───────────────────────────────────────────────────────────────────

  /// Inicia el flujo OAuth abriendo la URL proporcionada en el navegador del
  /// sistema.
  ///
  /// El caller debe obtener primero la URL llamando a
  /// `GET /auth/oauth/{provider}` en el backend (que devuelve el redirect URL
  /// de Better Auth) y pasarla aquí.
  ///
  /// El resultado de la autenticación llega de forma asíncrona vía deep link:
  /// el backend redirige a `io.sacdia.app://auth/callback?session_token=...`
  /// y el router lo intercepta para llamar a [handleOAuthCallback].
  ///
  /// Lanza [OAuthFlowInitiatedException] para señalizar que el navegador fue
  /// abierto (no es un error real).
  Future<void> initiateOAuth(String oauthUrl) async {
    final uri = Uri.parse(oauthUrl);
    AppLogger.i('Abriendo OAuth URL: $oauthUrl', tag: _tag);

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.platformDefault,
    );

    if (!launched) {
      throw AuthException(
        message: 'No se pudo abrir el navegador para autenticación OAuth',
      );
    }
  }

  /// Procesa el callback OAuth recibido por deep link.
  ///
  /// Según el nuevo contrato del backend (Better Auth / Option C):
  /// - El deep link trae `session_token` (token opaco de BA) y `provider`.
  /// - El caller envía `POST /auth/oauth/callback` con `{ session_token, provider }`.
  /// - El backend responde con el JWT HS256 interno de SACDIA.
  ///
  /// Este método solo persiste los tokens; la llamada HTTP la realiza
  /// [AuthRemoteDataSourceImpl.handleOAuthCallback].
  Future<void> persistOAuthTokens({
    required String accessToken,
    String? sessionToken,
    int? expiresAt,
    String? tokenType,
  }) async {
    await storeTokens(
      accessToken: accessToken,
      sessionToken: sessionToken,
      expiresAt: expiresAt,
      tokenType: tokenType,
    );
    AppLogger.i('Tokens OAuth persistidos', tag: _tag);
  }

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  /// Libera el [StreamController]. Llamar desde `ref.onDispose` si se usa en
  /// un Provider de Riverpod.
  void dispose() {
    _authStateController.close();
  }
}
