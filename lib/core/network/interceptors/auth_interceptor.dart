import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../auth/acting_for_session.dart';
import '../../constants/app_constants.dart';
import '../../utils/app_logger.dart';
import 'acting_generation_interceptor.dart';

/// Interceptor responsable de:
/// 1. Adjuntar el Bearer token a cada petición autenticada.
/// 2. Detectar respuestas 401 y realizar un refresh reactivo de token.
/// 3. Reintentar la petición original exactamente una vez tras un refresh exitoso.
/// 4. Prevenir bucles infinitos de refresh/retry marcando la request con una
///    bandera en `extra`.
///
/// IMPORTANTE: los endpoints de autenticación pública (login, register, oauth,
/// refresh) están excluidos del ciclo de refresh. Un 401 en esos paths
/// significa credenciales incorrectas, no una sesión expirada, y debe
/// propagarse tal cual para que la UI muestre el mensaje del servidor.
class AuthInterceptor extends QueuedInterceptor {
  final FlutterSecureStorage _secureStorage;

  /// Instancia Dio separada para las llamadas de refresh, de modo que no
  /// pasen por este mismo interceptor y no generen bucles.
  final Dio _refreshDio;

  static const _tag = 'AuthInterceptor';

  /// Clave usada en `RequestOptions.extra` para marcar que la petición ya fue
  /// reintentada después de un refresh, evitando bucles infinitos.
  static const _retryAfterRefreshKey = 'auth_interceptor_retry_after_refresh';

  /// Lock para evitar race condition cuando múltiples 401 llegan en paralelo.
  /// El primer llamador inicia el refresh; los demás esperan su resultado.
  /// Es `static` para cubrir el caso de múltiples instancias del interceptor.
  static Completer<bool>? _refreshCompleter;

  /// Paths que NO deben pasar por el ciclo de refresh reactivo.
  ///
  /// Un 401 en estos endpoints significa credenciales incorrectas o flujo
  /// inválido — no una sesión expirada. Interceptarlos generaría un intento
  /// de refresh sin sentido y tragaría el mensaje de error del servidor.
  static const _publicAuthPaths = <String>[
    '/auth/login',
    '/auth/register',
    '/auth/refresh',
    '/auth/oauth',
    '/auth/device/pair',
    '/auth/password/reset-request',
    '/auth/reset-password',
  ];

  /// Called once when the refresh token is dead and the session cannot be
  /// recovered. Use this to invalidate the auth state without making API calls.
  final VoidCallback? onAuthExpired;

  /// Se llama cuando el servidor responde 401 `AUTH_SUPERVISED_ACCESS_REVOKED`:
  /// el tutor desactivó, restableció o cambió el acceso del menor. La sesión ya
  /// no existe en el servidor, así que NO se intenta refrescar; si es nulo se
  /// usa [onAuthExpired].
  final VoidCallback? onSupervisedAccessRevoked;

  /// `code` del 401 de un token de menor cuyo acceso se cortó (FP3-17).
  static const supervisedAccessRevokedCode = 'AUTH_SUPERVISED_ACCESS_REVOKED';

  /// Se llama cuando un teléfono vinculado pierde su sesión: 401
  /// `AUTH_DEVICE_REVOKED`, `AUTH_DEVICE_SESSION_EXPIRED` o un refresh muerto
  /// MIENTRAS esta instalación es un dispositivo (FP3-52). El argumento es
  /// `true` si la causa es el tope absoluto de la vinculación. Los tokens ya se
  /// borraron; si es nulo se usa [onAuthExpired].
  final void Function(bool sessionExpired)? onDeviceUnpaired;

  /// ¿Esta instalación es un teléfono vinculado? Un dispositivo NUNCA manda
  /// `X-Acting-For` y, si su refresh muere, vuelve a la pantalla de
  /// vinculación en lugar de al login.
  final bool Function()? isDeviceSession;

  /// `code` del 401 de un teléfono desvinculado (revocado, no elegible,
  /// función apagada).
  static const deviceRevokedCode = 'AUTH_DEVICE_REVOKED';

  /// `code` del 401 de un teléfono cuya vinculación llegó al tope absoluto.
  static const deviceSessionExpiredCode = 'AUTH_DEVICE_SESSION_EXPIRED';

  /// Perfil por el que se actúa (tutor -> dependiente). Nulo en tests o
  /// instancias de Dio que nunca actúan por otro usuario.
  final ActingForSession? _actingForSession;

  /// Rutas (relativas a la base de la API) que JAMÁS llevan `X-Acting-For`.
  ///
  /// Son cuenta/seguridad del tutor (`/auth/*` de sesión), la gestión de
  /// familia (`/guardianships`) y lo que pertenece al dispositivo o a la
  /// cuenta real (`/fcm-tokens`, preferencias de notificación, exportación).
  /// El backend las rechaza si llevan el encabezado.
  static const actingForSkipPrefixes = <String>[
    '/auth/refresh',
    '/auth/logout',
    '/auth/login',
    '/auth/register',
    '/guardianships',
    '/fcm-tokens',
    // La app registra y borra el token FCM en `/users/me/fcm-tokens` (W4): el
    // refresco de token del tutor mientras actúa no puede llevar el encabezado.
    '/users/me/fcm-tokens',
    '/notifications/preferences',
    '/users/me/notification-preferences',
    '/users/me/data-export',
  ];

  /// Nombre del encabezado que sustituye al principal en el backend.
  static const actingForHeader = 'X-Acting-For';

  /// Clave de `RequestOptions.extra` para que una petición concreta NO lleve
  /// `X-Acting-For` aunque se esté actuando (`extra['skipActingFor'] == true`).
  static const skipActingForKey = 'skipActingFor';

  AuthInterceptor({
    FlutterSecureStorage? secureStorage,

    /// La instancia principal de Dio (con interceptores). Se mantiene para
    /// reintentar la petición original después del refresh.
    Dio? dio,
    this.onAuthExpired,
    this.onSupervisedAccessRevoked,
    this.onDeviceUnpaired,
    this.isDeviceSession,
    ActingForSession? actingForSession,

    /// Solo para tests: adaptador HTTP de las llamadas de refresh y de
    /// reintento (que usan instancias de Dio propias, sin interceptores).
    @visibleForTesting HttpClientAdapter? refreshAdapter,
  })  : _actingForSession = actingForSession,
        _refreshAdapter = refreshAdapter,
        _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                  accessibility:
                      KeychainAccessibility.first_unlock_this_device),
            ),
        _refreshDio = _buildRefreshDio(refreshAdapter);

  final HttpClientAdapter? _refreshAdapter;

  static Dio _buildRefreshDio(HttpClientAdapter? adapter) {
    final dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: Duration(seconds: AppConstants.connectTimeout),
      receiveTimeout: Duration(seconds: AppConstants.receiveTimeout),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      // No lanzar excepción para 4xx/5xx — manejar manualmente.
      validateStatus: (status) => status != null,
    ));
    if (adapter != null) dio.httpClientAdapter = adapter;
    return dio;
  }

  // ─── onRequest ────────────────────────────────────────────────────────────

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _secureStorage.read(key: AppConstants.tokenKey);

    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    // ÚNICO punto donde se inyecta X-Acting-For. La sesión se lee DESPUÉS del
    // await y, en ESTE mismo tramo síncrono, se decide el encabezado Y se sella
    // la generación (W2). Dio encadena los interceptores de petición con un
    // salto al event loop, así que sellar en otro interceptor dejaría una
    // ventana en la que un cambio de perfil marcaría con la generación NUEVA una
    // petición que lleva el encabezado del perfil VIEJO. `putIfAbsent`: un
    // reintento conserva el sello original (ver ActingGenerationInterceptor).
    final acting = _actingForSession;
    if (acting != null) {
      final dependentId = acting.dependentUserId;
      if (dependentId != null && !_isDevice && _shouldSendActingFor(options)) {
        options.headers[actingForHeader] = dependentId;
      } else {
        // Un reintento o una petición reutilizada no debe arrastrar el
        // encabezado de un perfil anterior.
        options.headers.remove(actingForHeader);
      }
      options.extra.putIfAbsent(
        ActingGenerationInterceptor.generationKey,
        () => acting.generation,
      );
    }

    handler.next(options);
  }

  bool get _isDevice => isDeviceSession?.call() ?? false;

  /// `false` para las rutas exentas y para peticiones marcadas con
  /// `extra['skipActingFor'] == true`.
  static bool _shouldSendActingFor(RequestOptions options) {
    if (options.extra[skipActingForKey] == true) return false;
    final path = apiPathOf(options);
    return !actingForSkipPrefixes.any(path.startsWith);
  }

  /// Ruta de la petición relativa a la base de la API (`/users/...`).
  ///
  /// Los datasources de la app pasan tanto rutas relativas como URLs completas
  /// (`'$baseUrl/auth/me'`), así que se resuelve la URI final y se le quita el
  /// prefijo de la base (p. ej. `/api/v1`).
  @visibleForTesting
  static String apiPathOf(RequestOptions options) {
    var path = options.uri.path;
    final basePath = Uri.tryParse(options.baseUrl)?.path ?? '';
    final trimmedBase = basePath.endsWith('/')
        ? basePath.substring(0, basePath.length - 1)
        : basePath;
    if (trimmedBase.isNotEmpty && path.startsWith(trimmedBase)) {
      path = path.substring(trimmedBase.length);
    }
    return path.startsWith('/') ? path : '/$path';
  }

  // ─── onError ──────────────────────────────────────────────────────────────

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Solo procesar 401. Otros errores pasan al siguiente interceptor.
    if (err.response?.statusCode != 401) {
      return handler.next(err);
    }

    // Endpoints públicos de autenticación: un 401 aquí indica credenciales
    // inválidas o flujo incorrecto — NO una sesión expirada. Dejar pasar el
    // error intacto para que la capa de datos lea el mensaje del servidor.
    final requestPath = err.requestOptions.path;
    final isPublicAuthEndpoint = _publicAuthPaths.any(
      (p) => requestPath.contains(p),
    );
    if (isPublicAuthEndpoint) {
      AppLogger.d(
        '401 en endpoint público ($requestPath), omitiendo refresh reactivo',
        tag: _tag,
      );
      return handler.next(err);
    }

    // Reautenticación rechazada (p. ej. `DELETE /auth/me` con contraseña o
    // idToken inválido): es un fallo de dominio, la sesión sigue vigente.
    // Refrescar y reintentar gastaría otro intento del límite horario y, si el
    // refresh falla, cerraría la sesión desde dentro del diálogo.
    if (_isReauthRejection(err)) {
      AppLogger.d(
        '401 de reautenticación (${err.requestOptions.path}), omitiendo refresh',
        tag: _tag,
      );
      return handler.next(err);
    }

    // Acceso del menor cortado por su tutor: la sesión se borró en el servidor,
    // un refresh solo fallaría. Se limpia YA y se avisa para que el login
    // explique por qué (FP3-32). Solo se lee el `code`, nunca `details`.
    if (_isSupervisedAccessRevoked(err)) {
      AppLogger.w('Acceso supervisado revocado, cerrando sesión', tag: _tag);
      await _clearTokens();
      (onSupervisedAccessRevoked ?? onAuthExpired)?.call();
      return handler.next(err);
    }

    // Teléfono vinculado desvinculado por su tutor (o no elegible): la sesión
    // se borró en el servidor, un refresh solo fallaría. Vuelve a la pantalla
    // de vinculación con un aviso. Solo se lee el `code`, nunca `details`.
    final deviceCode = _deviceSessionCode(err);
    if (deviceCode != null) {
      AppLogger.w('Dispositivo desvinculado, cerrando sesión', tag: _tag);
      await _clearTokens();
      _endSession(
        device: true,
        sessionExpired: deviceCode == deviceSessionExpiredCode,
      );
      return handler.next(err);
    }

    // Si esta petición ya fue reintentada, no entrar en bucle.
    final isRetry = err.requestOptions.extra[_retryAfterRefreshKey] == true;
    if (isRetry) {
      AppLogger.w(
          'Refresh/retry fallido en segundo intento, descartando sesión',
          tag: _tag);
      await _clearTokens();
      _endSession();
      return handler.next(err);
    }

    AppLogger.w('401 detectado, intentando refresh reactivo', tag: _tag);

    final refreshed = await _tryRefreshToken();

    if (!refreshed) {
      AppLogger.w('Refresh reactivo fallido, limpiando tokens', tag: _tag);
      await _clearTokens();
      final refreshExpired = _lastRefreshCode == deviceSessionExpiredCode;
      _endSession(
        device: _isDevice || refreshExpired,
        sessionExpired: refreshExpired,
      );
      return handler.next(err);
    }

    // Refresh exitoso: reintentar la petición original UNA vez.
    //
    // El reintento sale por una instancia de Dio sin interceptores y se entrega
    // con `handler.resolve`, así que ni AuthInterceptor.onRequest ni
    // ActingGenerationInterceptor lo ven (W1). Por eso aquí se replica a mano:
    //  - si el perfil cambió durante el refresh, NO se reenvía (ni con el
    //    encabezado viejo) y se rechaza como cancelación obsoleta;
    //  - el encabezado se recalcula con la sesión vigente, nunca se copia;
    //  - si el perfil cambia mientras el reintento vuela, la respuesta se
    //    descarta igual que lo haría ActingGenerationInterceptor.
    final acting = _actingForSession;
    final stamped =
        ActingGenerationInterceptor.generationOf(err.requestOptions);
    bool isStale() =>
        acting != null && stamped != null && stamped != acting.generation;
    DioException staleError() => DioException.requestCancelled(
          requestOptions: err.requestOptions,
          reason: ActingGenerationInterceptor.staleReason,
        );

    if (isStale()) {
      AppLogger.d(
        'Perfil cambiado durante el refresh, reintento descartado: '
        '${err.requestOptions.path}',
        tag: _tag,
      );
      return handler.next(staleError());
    }

    try {
      final newToken = await _secureStorage.read(key: AppConstants.tokenKey);
      // La lectura del token es asíncrona: se vuelve a comprobar el perfil.
      if (isStale()) return handler.next(staleError());

      final retryHeaders = <String, dynamic>{
        for (final entry in err.requestOptions.headers.entries)
          if (entry.key.toLowerCase() != actingForHeader.toLowerCase())
            entry.key: entry.value,
        'Authorization': 'Bearer $newToken',
      };
      final dependentId = acting?.dependentUserId;
      if (dependentId != null &&
          !_isDevice &&
          _shouldSendActingFor(err.requestOptions)) {
        retryHeaders[actingForHeader] = dependentId;
      }

      final retryOptions = Options(
        method: err.requestOptions.method,
        headers: retryHeaders,
        extra: {
          ...err.requestOptions.extra,
          _retryAfterRefreshKey: true,
        },
        contentType: err.requestOptions.contentType,
        responseType: err.requestOptions.responseType,
      );

      AppLogger.i('Reintentando petición tras refresh exitoso', tag: _tag);

      // Usamos una instancia de Dio propia para que el reintento no pase por
      // QueuedInterceptor y no genere un segundo ciclo de refresh.
      final retryDio = Dio(BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: Duration(seconds: AppConstants.connectTimeout),
        sendTimeout: Duration(seconds: AppConstants.sendTimeout),
        receiveTimeout: Duration(seconds: AppConstants.receiveTimeout),
        // Only treat 2xx as success so that 4xx/5xx responses on the retry
        // are properly surfaced as DioExceptions instead of being silently
        // swallowed by handler.resolve(response).
        validateStatus: (s) => s != null && s >= 200 && s < 300,
      ));
      final adapter = _refreshAdapter;
      if (adapter != null) retryDio.httpClientAdapter = adapter;

      final response = await retryDio.request(
        err.requestOptions.path,
        data: err.requestOptions.data,
        queryParameters: err.requestOptions.queryParameters,
        options: retryOptions,
      );

      if (isStale()) {
        AppLogger.d(
          'Perfil cambiado durante el reintento, respuesta descartada: '
          '${err.requestOptions.path}',
          tag: _tag,
        );
        return handler.next(staleError());
      }

      return handler.resolve(response);
    } catch (e) {
      // Un 403 del reintento es la respuesta REAL del servidor (p. ej.
      // `ACTING_FOR_FORBIDDEN`): se reenvía tal cual para que
      // ActingErrorInterceptor saque al tutor del perfil. Reenviar el 401
      // original la tragaría. Se conservan las `requestOptions` originales (su
      // `X-Acting-For` es el del perfil vigente: el sello ya se comprobó) y se
      // descarta si el perfil cambió mientras volaba.
      if (e is DioException && e.response?.statusCode == 403) {
        if (isStale()) return handler.next(staleError());
        AppLogger.w(
          '403 en el reintento tras refresh: ${err.requestOptions.path}',
          tag: _tag,
        );
        return handler.next(
          DioException(
            requestOptions: err.requestOptions,
            response: e.response,
            type: e.type,
            error: e.error,
            stackTrace: e.stackTrace,
            message: e.message,
          ),
        );
      }
      AppLogger.e('Error al reintentar después de refresh',
          tag: _tag, error: e);
      return handler.next(err);
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  /// `code` del backend que indica una reautenticación fallida, no una sesión
  /// expirada.
  static const _reauthRejectionCodes = <String>{
    'AUTH_INVALID_PASSWORD',
    'AUTH_INVALID_TOKEN',
  };

  /// `code` del último refresh fallido, para distinguir «vinculación vencida»
  /// de «desvinculado» cuando el refresh de un dispositivo muere.
  String? _lastRefreshCode;

  static String? _deviceSessionCode(DioException err) {
    final data = err.response?.data;
    if (data is! Map) return null;
    final code = data['code'];
    return code == deviceRevokedCode || code == deviceSessionExpiredCode
        ? code as String
        : null;
  }

  /// Termina la sesión local: un dispositivo vuelve a la vinculación; una
  /// cuenta, al login.
  void _endSession({bool? device, bool sessionExpired = false}) {
    final unpaired = onDeviceUnpaired;
    if ((device ?? _isDevice) && unpaired != null) {
      unpaired(sessionExpired);
      return;
    }
    onAuthExpired?.call();
  }

  static bool _isSupervisedAccessRevoked(DioException err) {
    final data = err.response?.data;
    return data is Map && data['code'] == supervisedAccessRevokedCode;
  }

  static bool _isReauthRejection(DioException err) {
    final data = err.response?.data;
    if (data is! Map) return false;
    final code = data['code'];
    return code is String && _reauthRejectionCodes.contains(code);
  }

  /// Realiza el refresh usando el refresh token almacenado.
  /// Guarda los nuevos tokens si el servidor responde con éxito.
  ///
  /// Usa un [Completer] estático como lock: si un refresh ya está en curso,
  /// los llamadores posteriores esperan su resultado en lugar de disparar
  /// una segunda petición. Esto evita la race condition cuando múltiples
  /// peticiones reciben 401 simultáneamente.
  Future<bool> _tryRefreshToken() async {
    // Si ya hay un refresh en curso, esperar su resultado sin iniciar otro.
    if (_refreshCompleter != null) {
      AppLogger.d('Refresh ya en curso, esperando resultado…', tag: _tag);
      return _refreshCompleter!.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => false,
      );
    }

    _refreshCompleter = Completer<bool>();
    _lastRefreshCode = null;

    try {
      final refreshToken =
          await _secureStorage.read(key: AppConstants.refreshTokenKey);

      if (refreshToken == null || refreshToken.isEmpty) {
        AppLogger.w('Sin refresh token disponible', tag: _tag);
        _refreshCompleter!.complete(false);
        return false;
      }

      final response = await _refreshDio.post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data;
        final data = body is Map<String, dynamic>
            ? (body['data'] as Map<String, dynamic>? ?? body)
            : null;

        final newAccessToken = data?['accessToken'] as String?;
        final newRefreshToken = data?['refreshToken'] as String?;
        final newExpiresAt = data?['expiresAt'] as int?;
        final newTokenType = data?['tokenType'] as String?;

        if (newAccessToken != null) {
          await _secureStorage.write(
              key: AppConstants.tokenKey, value: newAccessToken);
          if (newRefreshToken != null) {
            await _secureStorage.write(
                key: AppConstants.refreshTokenKey, value: newRefreshToken);
          }
          if (newExpiresAt != null) {
            await _secureStorage.write(
                key: AppConstants.expiresAtKey, value: newExpiresAt.toString());
          }
          if (newTokenType != null) {
            await _secureStorage.write(
                key: AppConstants.tokenTypeKey, value: newTokenType);
          }
          AppLogger.i('Token refrescado exitosamente (interceptor)', tag: _tag);
          _refreshCompleter!.complete(true);
          return true;
        }
      }

      AppLogger.w('Refresh token falló: ${response.statusCode}', tag: _tag);
      final body = response.data;
      _lastRefreshCode =
          body is Map && body['code'] is String ? body['code'] as String : null;
      _refreshCompleter!.complete(false);
      return false;
    } catch (e) {
      AppLogger.e('Error en refresh token (interceptor)', tag: _tag, error: e);
      _refreshCompleter!.complete(false);
      return false;
    } finally {
      // Siempre liberar el lock para que el próximo ciclo de refresh pueda
      // iniciarse. Se ejecuta DESPUÉS de que complete() fue llamado.
      _refreshCompleter = null;
    }
  }

  Future<void> _clearTokens() async {
    await _secureStorage.delete(key: AppConstants.tokenKey);
    await _secureStorage.delete(key: AppConstants.refreshTokenKey);
    await _secureStorage.delete(key: AppConstants.expiresAtKey);
    await _secureStorage.delete(key: AppConstants.tokenTypeKey);
  }
}
