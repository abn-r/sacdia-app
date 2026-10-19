import 'dart:async';
import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/auth/acting_for_session.dart';
import '../../../../core/auth/social_auth_client.dart';
import '../../../../core/auth/social_credential.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/interceptors/auth_interceptor.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/delete_account_reauth.dart';
import '../models/user_model.dart';

/// Interfaz para la fuente de datos remota de autenticación
abstract class AuthRemoteDataSource {
  /// Stream que emite el estado de autenticación del usuario
  Stream<bool> get authStateChanges;

  /// Obtiene el usuario actual
  Future<UserModel?> getCurrentUser();

  /// Inicia sesión con email y contraseña
  Future<UserModel> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  /// Registra un nuevo usuario con email y contraseña
  Future<UserModel> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String paternalSurname,
    required String maternalSurname,
    required String acceptedTermsVersion,
    required String acceptedPrivacyVersion,
    String? birthday,
  });

  /// Cierra la sesión del usuario
  Future<void> signOut();

  /// Envía un correo de recuperación de contraseña
  Future<void> resetPassword(String email);

  /// Actualiza la contraseña del usuario
  Future<UserModel> updatePassword(String currentPassword, String newPassword);

  /// Login nativo con Google: abre la hoja del SDK y envía el idToken al
  /// backend. Lanza [SocialSignInCancelledException] si el usuario cancela.
  Future<UserModel> signInWithGoogle();

  /// Login nativo con Apple: abre la hoja del SDK y envía el idToken al
  /// backend. Lanza [SocialSignInCancelledException] si el usuario cancela.
  Future<UserModel> signInWithApple();

  /// Obtiene el estado de completitud del post-registro
  Future<bool> getCompletionStatus();

  /// Verifica si hay un token guardado localmente (sin llamar al API)
  Future<bool> hasLocalToken();

  /// Cambia el contexto activo de autorización del usuario.
  /// Llama a PATCH /auth/me/context con el assignment_id indicado.
  Future<void> switchContext(String assignmentId);

  /// Elimina la cuenta del usuario autenticado.
  ///
  /// Llama a `DELETE /auth/me` con `{ password }`.
  /// El servidor revoca sesiones BA, borra PII, desregistra tokens FCM
  /// y archiva los datos en audit log.
  ///
  /// Lanza [AuthException] con código 401/403 si la contraseña es incorrecta,
  /// o 429 si se supera el rate limit.
  Future<void> deleteAccount(DeleteAccountReauth reauth);

  /// Proveedores sociales vinculados a la cuenta (`GET /auth/oauth/providers`).
  Future<List<SocialProvider>> getConnectedProviders();
}

/// Implementación de la fuente de datos remota con Dio para API personalizada
class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;
  final StreamController<bool> _authStateController;
  final SecureStorage _secureStorage;
  final SocialAuthClient _socialAuth;

  /// Perfil por el que se actúa. Mientras hay un dependiente en curso, `/auth/me`
  /// devuelve datos del dependiente y NADA de eso puede tocar los cachés del
  /// tutor (FP-49).
  final ActingForSession? _actingForSession;

  static const _tag = 'AuthDS';
  bool _attemptedContextAutoActivation = false;

  AuthRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
    required SecureStorage secureStorage,
    required SocialAuthClient socialAuth,
    ActingForSession? actingForSession,
  })  : _dio = dio,
        _baseUrl = baseUrl,
        _secureStorage = secureStorage,
        _socialAuth = socialAuth,
        _actingForSession = actingForSession,
        _authStateController = StreamController<bool>.broadcast() {
    _checkInitialAuthState();
  }

  /// Verifica el estado inicial de autenticación usando solo almacenamiento local.
  /// No realiza llamadas de red — AuthNotifier.build() ya valida el token
  /// contra la API mediante getCurrentUser(). Este método solo alimenta el
  /// stream authStateChanges con un valor inicial sin generar tráfico HTTP.
  Future<void> _checkInitialAuthState() async {
    try {
      final token = await _secureStorage.read(AppConstants.tokenKey);
      _authStateController.add(token != null);
    } catch (e) {
      AppLogger.w('Error al leer token local en estado inicial',
          tag: _tag, error: e);
      _authStateController.add(false);
    }
  }

  Future<void> _saveToken(
    String token, {
    String? refreshToken,
    int? expiresAt,
    String? tokenType,
  }) async {
    await _secureStorage.write(AppConstants.tokenKey, token);
    if (refreshToken != null) {
      await _secureStorage.write(AppConstants.refreshTokenKey, refreshToken);
    }
    if (expiresAt != null) {
      await _secureStorage.write(
          AppConstants.expiresAtKey, expiresAt.toString());
    }
    if (tokenType != null) {
      await _secureStorage.write(AppConstants.tokenTypeKey, tokenType);
    }
    _authStateController.add(true);
  }

  /// Persiste los tokens y arma el [UserModel] a partir de `data` de
  /// `/auth/login` y `/auth/oauth/:provider/token` (misma forma).
  Future<UserModel> _persistSessionAndBuildUser(
    Map<String, dynamic>? responseData, {
    String fallbackEmail = '',
  }) async {
    if (responseData == null) {
      throw AuthException(message: tr('errors.invalid_response'));
    }

    final token = responseData['accessToken'] as String?;
    if (token == null) {
      throw AuthException(message: tr('errors.missing_token'));
    }

    await _saveToken(
      token,
      refreshToken: responseData['refreshToken'] as String?,
      expiresAt: responseData['expiresAt'] as int?,
      tokenType: responseData['tokenType'] as String?,
    );

    final userData = responseData['user'] as Map<String, dynamic>?;
    final userId = userData?['id'] as String?;
    if (userId == null) {
      throw AuthException(message: tr('errors.missing_user_id'));
    }

    final needsPostRegistration =
        responseData['needsPostRegistration'] as bool? ?? true;

    return UserModel(
      id: userId,
      email: userData?['email'] as String? ?? fallbackEmail,
      name: userData?['name'] as String? ?? '',
      avatar: userData?['image'] as String? ?? userData?['avatar'] as String?,
      postRegisterComplete: !needsPostRegistration,
    );
  }

  Future<void> _clearToken() async {
    await _secureStorage.delete(AppConstants.tokenKey);
    await _secureStorage.delete(AppConstants.refreshTokenKey);
    await _secureStorage.delete(AppConstants.expiresAtKey);
    await _secureStorage.delete(AppConstants.tokenTypeKey);
    _authStateController.add(false);
  }

  bool? _parseBool(dynamic rawValue) {
    if (rawValue is bool) return rawValue;
    if (rawValue is num) return rawValue != 0;
    if (rawValue is String) {
      final value = rawValue.trim().toLowerCase();
      if (value == 'true' || value == '1' || value == 'yes') return true;
      if (value == 'false' || value == '0' || value == 'no') return false;
    }
    return null;
  }

  bool get _isActing => _actingForSession?.isActing ?? false;

  static bool _requestCarriedActingFor(RequestOptions options) =>
      options.headers[AuthInterceptor.actingForHeader] != null;

  Future<void> _persistCompletionCache(bool value) async {
    // El flag de post-registro cacheado es del tutor: el del dependiente no se
    // escribe nunca (FP-49).
    if (_isActing) return;
    await _secureStorage.write(
      'cached_post_register_complete',
      value.toString(),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('cached_post_register_complete', value);
  }

  Future<bool> _readCompletionCache() async {
    // El valor cacheado pertenece al tutor; para un dependiente sería ajeno.
    if (_isActing) return false;
    final prefs = await SharedPreferences.getInstance();
    final sharedValue = prefs.getBool('cached_post_register_complete');
    if (sharedValue != null) {
      return sharedValue;
    }
    final secureValue = await _secureStorage.read(
      'cached_post_register_complete',
    );
    return _parseBool(secureValue) ?? false;
  }

  Future<bool?> _fetchCompletionStatus(String token) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.auth}/profile/completion-status',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        return null;
      }

      if (response.data is! Map<String, dynamic>) {
        return null;
      }

      final body = response.data as Map<String, dynamic>;
      final nested = body['data'];
      final rawComplete = nested is Map<String, dynamic>
          ? nested['complete']
          : body['complete'];

      return _parseBool(rawComplete);
    } catch (e) {
      AppLogger.w(
        'No se pudo consultar /auth/profile/completion-status como fallback',
        tag: _tag,
        error: e,
      );
      return null;
    }
  }

  Future<bool> _activateAuthorizationContext(
    String token,
    String assignmentId,
  ) async {
    try {
      final response = await _dio.patch(
        '$_baseUrl${ApiEndpoints.auth}/me/context',
        data: {'assignment_id': assignmentId},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException catch (e) {
      AppLogger.w(
        'No se pudo activar contexto RBAC canonico',
        tag: _tag,
        error: e,
      );
      return false;
    }
  }

  @override
  Stream<bool> get authStateChanges => _authStateController.stream;

  @override
  Future<UserModel?> getCurrentUser() async {
    try {
      final token = await _secureStorage.read(AppConstants.tokenKey);
      if (token == null) return null;

      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.auth}/me',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> responseBody;
        if (response.data is Map<String, dynamic>) {
          responseBody = response.data as Map<String, dynamic>;
        } else {
          AppLogger.w(
              'Respuesta inesperada de /auth/me: ${response.data.runtimeType}',
              tag: _tag);
          return null;
        }

        // The nested user payload lives under 'data'; fall back to root level.
        final Map<String, dynamic> userData;
        final nestedData = responseBody['data'];
        if (nestedData is Map<String, dynamic>) {
          userData = nestedData;
        } else {
          userData = responseBody;
        }

        // 'post_register_complete' may sit at the root envelope OR inside 'data'.
        // Check both explicitly and cast safely so a missing field never silently
        // defaults to false when the user has actually completed post-registration.
        final dynamic rawFlag = responseBody['post_register_complete'] ??
            userData['post_register_complete'];
        final bool postRegisterComplete;
        final parsedFlag = _parseBool(rawFlag);
        if (parsedFlag != null) {
          postRegisterComplete = parsedFlag;
        } else {
          final completionFromApi = await _fetchCompletionStatus(token);
          if (completionFromApi != null) {
            postRegisterComplete = completionFromApi;
            AppLogger.i(
              'post_register_complete ausente en /auth/me; usando /auth/profile/completion-status: $postRegisterComplete',
              tag: _tag,
            );
          } else {
            // Last-resort fallback: cached value to avoid forcing user back to
            // post-registration when the API field is temporarily missing.
            postRegisterComplete = await _readCompletionCache();
            AppLogger.w(
              'post_register_complete ausente en /auth/me y completion-status no disponible; usando caché: $postRegisterComplete',
              tag: _tag,
            );
          }
        }

        await _persistCompletionCache(postRegisterComplete);

        final user = UserModel.fromCustomApi(
          userData,
          postRegisterComplete: postRegisterComplete,
        );

        final hasActiveAssignment =
            (user.authorization?.activeAssignmentId?.trim().isNotEmpty ??
                false);

        // Auto-activation: only run when the backend returns NO active assignment
        // AND we haven't attempted it yet in this datasource instance.
        //
        // IMPORTANT: we only auto-activate when `status == 'active'` explicitly.
        // Grants with `status == null` (legacy data) are intentionally excluded to
        // avoid activating an assignment the backend did not mark as usable.
        // This prevents the mismatch where the first legacy grant in the array
        // (e.g. Guías Mayores) gets silently activated even though the user last
        // chose Conquistadores in a previous session.
        String? fallbackAssignmentId;
        if (!hasActiveAssignment) {
          // Only consider grants with explicit 'active' status.
          for (final grant in user.authorization?.clubAssignments ?? const []) {
            final candidate = grant.assignmentId?.trim();
            if (candidate != null &&
                candidate.isNotEmpty &&
                grant.status == 'active') {
              fallbackAssignmentId = candidate;
              break;
            }
          }
        }

        if (!_attemptedContextAutoActivation &&
            !hasActiveAssignment &&
            fallbackAssignmentId != null) {
          _attemptedContextAutoActivation = true;
          AppLogger.i(
            'Auto-activating context: $fallbackAssignmentId',
            tag: _tag,
          );
          final contextActivated = await _activateAuthorizationContext(
            token,
            fallbackAssignmentId,
          );

          if (contextActivated) {
            final refreshedUser = await getCurrentUser();
            _attemptedContextAutoActivation = false;
            return refreshedUser;
          }

          _attemptedContextAutoActivation = false;
        }

        return user;
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        AppLogger.w('Token inválido (${response.statusCode}), limpiando sesión',
            tag: _tag);
        await _clearToken();
      }

      return null;
    } on DioException catch (e) {
      AppLogger.e('Error al obtener usuario actual', tag: _tag, error: e);

      final statusCode = e.response?.statusCode;

      // 403 de una petición que llevaba `X-Acting-For`: es el acceso al
      // DEPENDIENTE lo que se perdió (tutoría revocada, congelado...), no la
      // sesión del tutor. Borrar los tokens aquí cerraría la sesión del tutor
      // (FP-55). Se decide por el encabezado enviado y no por la sesión
      // actual: el interceptor ya pudo salir del modo antes de llegar aquí.
      // Solo se lee el `code`, nunca `details` (RULING #11528).
      if (statusCode == 403 && _requestCarriedActingFor(e.requestOptions)) {
        final data = e.response?.data;
        throw AuthException(
          message: data is Map && data['message'] is String
              ? data['message'] as String
              : tr('errors.acting_for_forbidden'),
          code: statusCode,
          errorCode: data is Map && data['code'] is String
              ? data['code'] as String
              : null,
          stackTrace: e.stackTrace,
        );
      }

      if (statusCode == 401 || statusCode == 403) {
        await _clearToken();
        return null;
      }

      final appError = e.error;
      if (appError is ConnectionException) {
        throw appError;
      }
      if (appError is AuthException) {
        throw appError;
      }
      if (appError is ServerException) {
        throw appError;
      }
      if (appError is ValidationException) {
        throw appError;
      }

      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        throw ConnectionException(
          message: e.message ?? tr('errors.connection_error'),
          stackTrace: e.stackTrace,
        );
      }

      final serverMessage = e.response?.data is Map
          ? e.response!.data['message'] as String?
          : null;
      throw ServerException(
        message: serverMessage ?? e.message ?? tr('errors.server_error'),
        code: statusCode,
        stackTrace: e.stackTrace,
      );
    } on AppException catch (e) {
      AppLogger.e('Error al obtener usuario actual', tag: _tag, error: e);
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.e('Error al obtener usuario actual', tag: _tag, error: e);
      throw ServerException(message: e.toString(), stackTrace: stackTrace);
    }
  }

  @override
  Future<UserModel> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      AppLogger.i('Login iniciado', tag: _tag);

      final response =
          await _dio.post('$_baseUrl${ApiEndpoints.auth}/login', data: {
        'email': email,
        'password': password,
      });

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw AuthException(
            message: response.data['message'] ?? tr('errors.auth_failed'));
      }

      final user = await _persistSessionAndBuildUser(
        response.data['data'] as Map<String, dynamic>?,
        fallbackEmail: email,
      );
      AppLogger.i('Login exitoso', tag: _tag);
      return user;
    } catch (e) {
      AppLogger.e('Error en login', tag: _tag, error: e);
      if (e is DioException) {
        // Leer el mensaje desde el body del servidor cuando está disponible.
        // e.message solo contiene metadatos HTTP ("Http status error [401]"),
        // no el payload — el API message vive en e.response.data['message'].
        final serverMessage = e.response?.data is Map
            ? e.response!.data['message'] as String?
            : null;
        throw AuthException(
            message: serverMessage ?? tr('common.error_network'));
      }
      if (e is AuthException) rethrow;
      throw AuthException(message: e.toString());
    }
  }

  @override
  Future<UserModel> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String paternalSurname,
    required String maternalSurname,
    required String acceptedTermsVersion,
    required String acceptedPrivacyVersion,
    String? birthday,
  }) async {
    try {
      AppLogger.i('Registro iniciado', tag: _tag);

      final response =
          await _dio.post('$_baseUrl${ApiEndpoints.auth}/register', data: {
        'email': email,
        'password': password,
        'name': name,
        'paternal_last_name': paternalSurname,
        'maternal_last_name': maternalSurname,
        'accepted_terms_version': acceptedTermsVersion,
        'accepted_privacy_version': acceptedPrivacyVersion,
        if (birthday != null) 'birthday': birthday,
      });

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw AuthException(
          message: response.data['message'] ?? tr('errors.register_failed'),
          errorCode: response.data['code']?.toString(),
        );
      }

      // Backend returns { success: true, userId: "uuid", message: "..." }
      // OR { data: { user: {...}, accessToken, refreshToken } } depending on endpoint version
      final responseBody = response.data as Map<String, dynamic>;
      final userData = responseBody['user'] as Map<String, dynamic>?;
      final userId = userData?['id'] as String? ??
          responseBody['userId'] as String? ??
          (responseBody['data'] as Map<String, dynamic>?)?['user']?['id']
              as String?;

      if (userId == null) {
        throw AuthException(message: tr('errors.missing_user_id'));
      }

      // If the response includes tokens (auto-login after register), persist them
      final data = responseBody['data'] as Map<String, dynamic>?;
      final accessToken = data?['accessToken'] as String?;
      final refreshToken = data?['refreshToken'] as String?;
      if (accessToken != null && accessToken.isNotEmpty) {
        await _saveToken(
          accessToken,
          refreshToken: refreshToken,
          expiresAt: data?['expiresAt'] as int?,
          tokenType: data?['tokenType'] as String?,
        );
      }

      AppLogger.i('Usuario registrado: $userId', tag: _tag);
      return UserModel(
        id: userId,
        email: userData?['email'] as String? ?? email,
        name: userData?['name'] as String? ?? name,
        postRegisterComplete: false,
      );
    } catch (e) {
      AppLogger.e('Error en registro', tag: _tag, error: e);
      if (e is DioException) {
        final message = e.response?.data?['message'] ??
            e.message ??
            tr('common.error_network');
        // Solo `code`: `details` no existe en producción (ruling #11528).
        final data = e.response?.data;
        throw AuthException(
          message: message,
          code: e.response?.statusCode,
          errorCode: data is Map ? data['code']?.toString() : null,
        );
      }
      if (e is AuthException) rethrow;
      throw AuthException(message: e.toString());
    }
  }

  @override
  Future<void> signOut() async {
    AppLogger.i('Cerrando sesión', tag: _tag);

    // Read tokens before clearing — needed to notify the server.
    final token = await _secureStorage.read(AppConstants.tokenKey);
    final refreshToken =
        await _secureStorage.read(AppConstants.refreshTokenKey);

    // Always clear local state first, regardless of network outcome.
    await _clearToken();
    await _clearAllPersistentData();

    // Best-effort server invalidation: send whatever tokens we have.
    // The backend responds 200 even with an expired access token (fail-safe).
    try {
      final headers = <String, dynamic>{};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final body = <String, dynamic>{};
      if (refreshToken != null && refreshToken.isNotEmpty) {
        body['refreshToken'] = refreshToken;
      }

      await _dio.post(
        '$_baseUrl${ApiEndpoints.auth}/logout',
        data: body.isNotEmpty ? body : null,
        options: Options(
          headers: headers.isNotEmpty ? headers : null,
          // Do not throw on non-2xx — any response means server acknowledged.
          validateStatus: (status) => status != null,
        ),
      );
      AppLogger.i('Logout notificado al servidor', tag: _tag);
    } catch (e) {
      // Network error is acceptable; local state is already cleared.
      AppLogger.w('Logout: no se pudo contactar el servidor',
          tag: _tag, error: e);
    }
  }

  @override
  Future<void> resetPassword(String email) async {
    try {
      AppLogger.i('Recuperación de contraseña solicitada', tag: _tag);

      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.auth}/password/reset-request',
        data: {'email': email},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        AppLogger.i('Correo de recuperación enviado', tag: _tag);
      }
    } catch (e) {
      AppLogger.e('Error en reset password', tag: _tag, error: e);
      if (e is DioException) {
        throw AuthException(
          message:
              e.response?.data?['message'] ?? tr('errors.password_reset_sent'),
        );
      }
      throw AuthException(message: e.toString());
    }
  }

  @override
  Future<UserModel> updatePassword(
      String currentPassword, String newPassword) async {
    try {
      final token = await _secureStorage.read(AppConstants.tokenKey);
      if (token == null) {
        throw AuthException(message: tr('errors.no_active_session'));
      }

      await _dio.post(
        '$_baseUrl${ApiEndpoints.auth}/update-password',
        data: {
          'currentPassword': currentPassword,
          'password': newPassword,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final user = await getCurrentUser();
      if (user == null) {
        throw AuthException(message: tr('errors.refresh_user_failed'));
      }
      return user;
    } catch (e) {
      if (e is DioException) {
        throw AuthException(message: e.message ?? tr('errors.update_password'));
      }
      if (e is AuthException) rethrow;
      throw AuthException(message: e.toString());
    }
  }

  Future<void> _clearAllPersistentData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Clear known auth keys from secure storage explicitly.
      const secureKeys = [
        AppConstants.tokenKey,
        AppConstants.refreshTokenKey,
        AppConstants.expiresAtKey,
        AppConstants.tokenTypeKey,
        'cached_post_register_complete',
        AppConstants.cachedUserId,
        AppConstants.cachedUserEmail,
        AppConstants.cachedUserName,
        AppConstants.cachedUserAvatar,
        AppConstants.cachedActiveAssignmentId,
        AppConstants.cachedActiveRoleName,
        AppConstants.cachedActiveClubName,
        AppConstants.cachedActiveClubType,
        AppConstants.cachedActivePermissions,
        AppConstants.cachedActiveClubId,
        AppConstants.cachedActiveSectionId,
        AppConstants.cachedActiveClubTypeId,
      ];
      for (final key in secureKeys) {
        await _secureStorage.delete(key);
      }

      // Clear known auth keys from SharedPreferences explicitly.
      const prefKeys = [
        'auth-token',
        'auth-refresh-token',
        'auth-type',
        'refresh_token',
        'cached_post_register_complete',
        AppConstants.biometricEnabledKey,
        AppConstants.biometricEnrolledAtKey,
      ];
      for (final key in prefKeys) {
        await prefs.remove(key);
      }
    } catch (e) {
      AppLogger.e('Error al limpiar datos persistentes', tag: _tag, error: e);
    }
  }

  // ── Login social nativo ──────────────────────────────────────────────────────
  //
  //   1. SocialAuthClient abre la hoja nativa y devuelve idToken + nonce.
  //   2. POST /auth/oauth/{provider}/token con SocialTokenSignInDto.
  //   3. El backend verifica el token, crea o vincula el usuario y devuelve
  //      la misma sesión que /auth/login.

  @override
  Future<UserModel> signInWithGoogle() =>
      _signInWithProvider(SocialProvider.google);

  @override
  Future<UserModel> signInWithApple() =>
      _signInWithProvider(SocialProvider.apple);

  Future<UserModel> _signInWithProvider(SocialProvider provider) async {
    AppLogger.i('Login social iniciado: ${provider.wireName}', tag: _tag);

    final SocialCredential? credential;
    try {
      credential = await _socialAuth.signIn(provider);
    } on SocialAuthException catch (e) {
      AppLogger.w('SDK de ${provider.wireName} falló: ${e.message}', tag: _tag);
      throw AuthException(
        message: tr('errors.social_signin_failed',
            namedArgs: {'provider': _providerLabel(provider)}),
      );
    }
    if (credential == null) {
      throw SocialSignInCancelledException();
    }

    try {
      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.auth}/oauth/${provider.wireName}/token',
        data: credential.toSignInBody(),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw AuthException(
          message: response.data?['message'] ??
              tr('errors.social_signin_failed',
                  namedArgs: {'provider': _providerLabel(provider)}),
        );
      }

      final user = await _persistSessionAndBuildUser(
        response.data['data'] as Map<String, dynamic>?,
      );
      AppLogger.i('Login social exitoso: ${provider.wireName}', tag: _tag);
      return user;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final data = e.response?.data;
      final errorCode =
          data is Map && data['code'] is String ? data['code'] as String : null;
      AppLogger.w(
          'Login social ${provider.wireName} rechazado: $status ($errorCode)',
          tag: _tag);
      throw AuthException(
        message: _socialErrorMessage(e, provider, status, errorCode),
        code: status,
      );
    }
  }

  /// Mensaje localizado para un fallo de `/auth/oauth/:provider/token`.
  /// Se decide por `code` del backend y por el status, nunca por su `message`
  /// (llega sin localizar, o enmascarado en 5xx).
  String _socialErrorMessage(
    DioException e,
    SocialProvider provider,
    int? status,
    String? errorCode,
  ) {
    final args = {'provider': _providerLabel(provider)};

    if (e.response == null) {
      // Timeout / sin conexión: el ErrorInterceptor ya dejó un mensaje
      // localizado en `e.error`.
      final inner = e.error;
      if (inner is AppException && inner.message.isNotEmpty) {
        return inner.message;
      }
      return tr('common.error_network');
    }

    if (status == 429) return tr('errors.too_many_attempts');

    switch (errorCode) {
      case 'AUTH_OAUTH_EMAIL_UNVERIFIED':
        return tr('errors.social_signin_unverified', namedArgs: args);
      case 'AUTH_OAUTH_PROVIDER_ALREADY_LINKED':
        return tr('errors.social_signin_already_linked', namedArgs: args);
      case 'AUTH_OAUTH_PROVIDER_UNAVAILABLE':
        return tr('errors.social_signin_provider_unavailable', namedArgs: args);
    }
    if (status != null && status >= 500) {
      return tr('errors.social_signin_provider_unavailable', namedArgs: args);
    }
    return tr('errors.social_signin_failed', namedArgs: args);
  }

  static String _providerLabel(SocialProvider provider) => switch (provider) {
        SocialProvider.google => 'Google',
        SocialProvider.apple => 'Apple',
      };

  @override
  Future<bool> hasLocalToken() async {
    try {
      final token = await _secureStorage.read(AppConstants.tokenKey);
      return token != null;
    } catch (e) {
      AppLogger.e('Error al verificar token local', tag: _tag, error: e);
      return false;
    }
  }

  @override
  Future<void> switchContext(String assignmentId) async {
    final token = await _secureStorage.read(AppConstants.tokenKey);
    if (token == null) {
      throw AuthException(message: tr('errors.no_active_session'));
    }

    final response = await _dio.patch(
      '$_baseUrl${ApiEndpoints.auth}/me/context',
      data: {'assignment_id': assignmentId},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw AuthException(
        message: response.data?['message'] ?? tr('errors.switch_context'),
      );
    }
  }

  @override
  Future<void> deleteAccount(DeleteAccountReauth reauth) async {
    try {
      final token = await _secureStorage.read(AppConstants.tokenKey);
      if (token == null) {
        throw AuthException(message: tr('errors.no_active_session'));
      }

      await _dio.delete(
        '$_baseUrl${ApiEndpoints.auth}/me',
        data: reauth.toBody(),
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          // Solo 200/204 son éxito. 4xx lanza DioException → catch maneja 401.
          validateStatus: (s) => s == 200 || s == 204,
        ),
      );

      // 204 = éxito. Cualquier 4xx llega como DioException por validateStatus.
      // Limpiar tokens localmente después de confirmación del server.
      await _clearToken();
      await _clearAllPersistentData();
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final data = e.response?.data;
      final errorCode =
          data is Map && data['code'] is String ? data['code'] as String : null;
      AppLogger.w('Borrado de cuenta rechazado: $status ($errorCode)',
          tag: _tag);
      throw AuthException(
        message: _deleteAccountErrorMessage(e, reauth, status, errorCode),
        code: status,
        errorCode: errorCode,
      );
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException(
        message: tr('errors.unexpected', namedArgs: {'details': '$e'}),
      );
    }
  }

  /// Mensaje localizado para un fallo de `DELETE /auth/me`. Se decide por
  /// `code` del backend y por el status, nunca por su `message` (solo en
  /// español, y enmascarado en 5xx).
  String _deleteAccountErrorMessage(
    DioException e,
    DeleteAccountReauth reauth,
    int? status,
    String? errorCode,
  ) {
    final provider = switch (reauth) {
      SocialReauth(:final credential) => credential.provider,
      PasswordReauth() => null,
    };
    final args = provider == null
        ? const <String, String>{}
        : {'provider': _providerLabel(provider)};

    if (e.response == null) {
      // Timeout / sin conexión: el ErrorInterceptor ya dejó un mensaje
      // localizado en `e.error`.
      final inner = e.error;
      if (inner is AppException && inner.message.isNotEmpty) {
        return inner.message;
      }
      return tr('common.error_network');
    }

    if (status == 429) return tr('errors.too_many_attempts');

    // Tutor con menores a cargo que aún no aceptó el aviso (409). La app lo
    // pide antes, así que solo llega si cambió algo entremedias.
    if (errorCode == kDeleteDependentsAckRequiredCode) {
      return tr('errors.auth_delete_dependents_ack_required');
    }

    // Reautenticación rechazada: contraseña incorrecta o idToken inválido /
    // identidad no vinculada a esta cuenta. Un 401/403 sin `code` se trata igual.
    final rejected = errorCode == 'AUTH_INVALID_PASSWORD' ||
        errorCode == 'AUTH_INVALID_TOKEN' ||
        (errorCode == null && (status == 401 || status == 403));
    if (rejected) {
      return provider == null
          ? tr('errors.wrong_password')
          : tr('errors.delete_account_social_reauth_failed', namedArgs: args);
    }

    final unavailable = errorCode == 'AUTH_OAUTH_PROVIDER_UNAVAILABLE' ||
        (status != null && status >= 500);
    if (unavailable && provider != null) {
      return tr('errors.social_signin_provider_unavailable', namedArgs: args);
    }
    return tr('errors.delete_account');
  }

  @override
  Future<List<SocialProvider>> getConnectedProviders() async {
    final token = await _secureStorage.read(AppConstants.tokenKey);
    if (token == null) {
      throw AuthException(message: tr('errors.no_active_session'));
    }
    final response = await _dio.get(
      '$_baseUrl${ApiEndpoints.auth}/oauth/providers',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    // El endpoint devuelve el arreglo sin envoltorio (`["google","apple"]`);
    // se acepta también `{ data: [...] }` por si el backend lo envuelve.
    final raw = response.data;
    final list = raw is List ? raw : (raw is Map ? raw['data'] : null);
    final names = list is List ? list.whereType<String>().toSet() : <String>{};
    return [
      for (final p in SocialProvider.values)
        if (names.contains(p.wireName)) p,
    ];
  }

  @override
  Future<bool> getCompletionStatus() async {
    try {
      final token = await _secureStorage.read(AppConstants.tokenKey);
      if (token == null) {
        throw AuthException(message: tr('errors.no_active_session'));
      }

      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.auth}/profile/completion-status',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      if (response.statusCode == 200) {
        final data = response.data['data'] as Map<String, dynamic>?;
        return data?['complete'] as bool? ?? false;
      }

      return false;
    } catch (e) {
      if (e is DioException) {
        throw AuthException(
          message: e.message ?? tr('errors.check_completion_status'),
        );
      }
      if (e is AuthException) rethrow;
      throw AuthException(message: e.toString());
    }
  }
}
