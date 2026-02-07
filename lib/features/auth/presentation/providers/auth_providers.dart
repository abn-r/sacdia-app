import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../data/datasources/auth_remote_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/get_current_user.dart';
import '../../domain/usecases/sign_in.dart';
import '../../domain/usecases/sign_out.dart';
import '../../domain/usecases/sign_up.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/constants/app_constants.dart';

/// Provider para el cliente Dio
final dioProvider = Provider((ref) {
  return Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    contentType: 'application/json',
    validateStatus: (_) => true,
  ));
});

/// Provider para la URL base de la API
final apiBaseUrlProvider = Provider((ref) {
  // Ajusta esta URL según tu entorno
  return AppConstants.baseUrl; // Cambia esto a la URL real de tu API
});

/// Provider para el repositorio de autenticación
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final networkInfo = ref.read(networkInfoProvider);
  final dio = ref.read(dioProvider);
  final baseUrl = ref.read(apiBaseUrlProvider);
  
  return AuthRepositoryImpl(
    remoteDataSource: AuthRemoteDataSourceImpl(
      dio: dio,
      baseUrl: baseUrl,
    ),
    networkInfo: networkInfo,
  );
});

/// Provider para el caso de uso de obtener el usuario actual
final getCurrentUserProvider = Provider<GetCurrentUser>((ref) {
  return GetCurrentUser(ref.read(authRepositoryProvider));
});

/// Provider para el caso de uso de iniciar sesión
final signInProvider = Provider<SignIn>((ref) {
  return SignIn(ref.read(authRepositoryProvider));
});

/// Provider para el caso de uso de registro
final signUpProvider = Provider<SignUp>((ref) {
  return SignUp(ref.read(authRepositoryProvider));
});

/// Provider para el caso de uso de cerrar sesión
final signOutProvider = Provider<SignOut>((ref) {
  return SignOut(ref.read(authRepositoryProvider));
});

/// Flag global para rastrear manualmente el estado de autenticación
final isUserLoggedOutProvider = StateProvider<bool>((ref) => false);

/// Provider para el stream de estado de autenticación con verificación manual adicional
final authStateProvider = StreamProvider<bool>((ref) {
  // Observamos el flag manual de cierre de sesión
  final manuallyLoggedOut = ref.watch(isUserLoggedOutProvider);
  
  // Si el usuario cerró sesión manualmente, forzamos el estado a false
  if (manuallyLoggedOut) {
    return Stream.value(false);
  }
  
  // Caso contrario, usamos el stream normal con nuestras mejoras
  return ref.read(authRepositoryProvider).authStateChanges;
});

/// Notifier para manejar la autenticación y sus estados
class AuthNotifier extends AsyncNotifier<UserEntity?> {
  @override
  Future<UserEntity?> build() async {
    final repository = ref.read(authRepositoryProvider);

    // Paso 1: Verificar si hay token guardado localmente
    log('🔄 [AuthNotifier] Paso 1: Verificando token local...');
    final hasToken = await repository.hasLocalToken();

    // Paso 3: NO hay token → ir directo a login (sin llamar al endpoint)
    if (!hasToken) {
      log('🔒 [AuthNotifier] No hay token local → redirigiendo a login');
      return null;
    }

    // Paso 2: SÍ hay token → llamar a /auth/me
    log('🔑 [AuthNotifier] Token encontrado → validando con /auth/me...');
    final result = await ref.read(getCurrentUserProvider)(NoParams());

    return result.fold(
      (failure) {
        // Token expirado o error → ir a login
        log('❌ [AuthNotifier] Error al validar token: ${failure.message} → redirigiendo a login');
        return null;
      },
      (user) {
        if (user != null) {
          log('✅ [AuthNotifier] Usuario autenticado: ${user.email}');
        } else {
          // /auth/me respondió pero no devolvió usuario → ir a login
          log('🔒 [AuthNotifier] Token inválido (401) → redirigiendo a login');
        }
        return user;
      },
    );
  }

  /// Iniciar sesión con email y contraseña
  Future<bool> signIn({required String email, required String password}) async {
    log('💬 [AuthNotifier] Inicio del proceso de login para: $email');
    state = const AsyncValue.loading();
    
    log('💬 [AuthNotifier] Llamando a signInProvider');
    final result = await ref.read(signInProvider)(
      SignInParams(email: email, password: password),
    );
    
    state = result.fold(
      (failure) {
        String errorMessage = failure is AuthFailure
            ? failure.message
            : 'Error al iniciar sesión';
        log('💬 [AuthNotifier] Error en login: $errorMessage');
        return AsyncValue.error(errorMessage, StackTrace.current);
      },
      (user) {
        log('💬 [AuthNotifier] Login exitoso para usuario: ${user.email}');
        // Reseteamos el flag de cierre de sesión para que el authStateProvider se actualice
        ref.read(isUserLoggedOutProvider.notifier).state = false;
        return AsyncValue.data(user);
      },
    );
    
    final result2 = !state.hasError;
    log('💬 [AuthNotifier] Resultado final del login: $result2');
    return result2;
  }

  /// Registrar un nuevo usuario
  Future<bool> signUp({
    required String email, 
    required String password,
    required String name,
    required String paternalSurname,
    required String maternalSurname,
  }) async {
    state = const AsyncValue.loading();
    
    final result = await ref.read(signUpProvider)(
      SignUpParams(
        email: email, 
        password: password,
        name: name,
        paternalSurname: paternalSurname,
        maternalSurname: maternalSurname,
      ),
    );
    
    state = result.fold(
      (failure) {
        String errorMessage = failure is AuthFailure
            ? failure.message
            : 'Error al registrar usuario';
        return AsyncValue.error(errorMessage, StackTrace.current);
      },
      (user) => AsyncValue.data(user),
    );
    
    return !state.hasError;
  }

  /// Cerrar sesión
  Future<bool> signOut() async {
    state = const AsyncValue.loading();
    
    // Establecer el flag de cierre de sesión manual ANTES de llamar al signOut
    // para evitar que el stream pueda emitir un valor incorrecto
    ref.read(isUserLoggedOutProvider.notifier).state = true;
    
    final result = await ref.read(signOutProvider)(NoParams());
    
    return result.fold(
      (failure) {
        String errorMessage = failure is AuthFailure
            ? failure.message
            : 'Error al cerrar sesión';
        state = AsyncValue.error(errorMessage, StackTrace.current);
        
        // Si hay un error, no podemos estar seguros del estado, pero mantenemos el flag activo
        // para evitar que el usuario quede con sesión abierta
        return false;
      },
      (_) {
        // Cierre exitoso, establecemos el estado a null (no autenticado)
        state = const AsyncValue.data(null);
        
        // Guardar el estado de cierre de sesión en SharedPreferences para persistencia
        SharedPreferences.getInstance().then((prefs) {
          prefs.setBool('user_manually_logged_out', true);
        });
        
        return true;
      },
    );
  }
}

/// Provider para NetworkInfo
final networkInfoProvider = Provider<NetworkInfo>((ref) {
  return NetworkInfoImpl();
});

/// Provider para AuthNotifier
final authNotifierProvider = AsyncNotifierProvider<AuthNotifier, UserEntity?>(() {
  return AuthNotifier();
});
