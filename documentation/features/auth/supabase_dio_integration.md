# Guía de Integración: Supabase Auth con DIO para API REST

Este documento detalla el proceso paso a paso para integrar la autenticación de Supabase con un cliente HTTP (`DIO`) para realizar llamadas seguras a una API REST externa. La guía sigue los principios de la Arquitectura Limpia (Clean Architecture) + MVVM y utiliza Riverpod para la gestión de estado e inyección de dependencias.

## Flujo General de Autenticación y Llamadas a API

1.  **Inicio de la App**: La aplicación se inicia y verifica el estado de autenticación.
2.  **Redirección**: Un `AuthGate` decide qué pantalla mostrar (`Login` o `Home`) basándose en si el usuario está autenticado.
3.  **Login**: El usuario se autentica a través de Supabase. El estado de la sesión se actualiza automáticamente.
4.  **Llamada a API**: El usuario realiza una acción que requiere datos de la API REST.
5.  **Intercepción con DIO**: `AuthInterceptor` intercepta la llamada, obtiene el `accessToken` de la sesión activa de Supabase y lo inyecta en la cabecera `Authorization`.
6.  **Logout**: El usuario cierra sesión. El estado se actualiza y se le redirige a la pantalla de `Login`.

---

## Checklist de Implementación

### Fase 1: Configuración Inicial

*   **[✅] Paso 1: Añadir Dependencias**
    *   Asegúrate de tener `supabase_flutter`, `flutter_riverpod`, `dio` y `shared_preferences` en tu `pubspec.yaml`.

*   **[✅] Paso 2: Centralizar Constantes**
    *   `lib/core/constants/supabase_constants.dart`: Para URL y `anonKey` de Supabase.
    *   `lib/core/constants/app_constants.dart`: Para endpoints de API, timeouts de DIO, etc.

*   **[✅] Paso 3: Inicializar Servicios en `main.dart`**
    *   Llamar a `WidgetsFlutterBinding.ensureInitialized()`.
    *   Inicializar Supabase ANTES de `runApp`: `await SupabaseAuth.initialize();`.
    *   Envolver `MyApp` en un `ProviderScope`.

### Fase 2: Refactorizar el `AuthInterceptor` (Clave)

El cambio más importante es obtener el token directamente de la sesión de Supabase, no de `SharedPreferences`.

*   **[✅] Paso 4: Modificar `AuthInterceptor` para usar Supabase**
    *   **Archivo**: `lib/core/network/interceptors/auth_interceptor.dart`
    *   **Objetivo**: Usar `Supabase.instance.client.auth.currentSession` como la única fuente de verdad para el token.

    ```dart
    // lib/core/network/interceptors/auth_interceptor.dart
    import 'package:dio/dio.dart';
    import 'package:flutter/foundation.dart';
    import 'package:supabase_flutter/supabase_flutter.dart';

    class AuthInterceptor extends Interceptor {
      @override
      void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
        // Obtener la sesión actual directamente del cliente de Supabase
        final session = Supabase.instance.client.auth.currentSession;
        
        // Si hay una sesión activa y un token, lo añadimos a la cabecera
        if (session != null && session.accessToken.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer ${session.accessToken}';
        }
        
        handler.next(options);
      }

      @override
      Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
        if (err.response?.statusCode == 401) {
          debugPrint('⚠️ Token inválido o expirado');
          // Aquí se puede implementar lógica de refresh token o redirección al login.
        }
        handler.next(err);
      }
    }
    ```

### Fase 3: Gestión Reactiva del Estado de Autenticación

*   **[ ] Paso 5: Crear un `authStreamProvider`**
    *   **Archivo**: `lib/features/auth/presentation/providers/auth_providers.dart`
    *   **Objetivo**: Notificar a la UI instantáneamente sobre cambios de estado (login/logout).

    ```dart
    final authStateStreamProvider = StreamProvider.autoDispose<User?>((ref) {
      final supabaseClient = ref.watch(supabaseProvider);
      return supabaseClient.auth.onAuthStateChange.map((authState) => authState.session?.user);
    });
    ```

### Fase 4: Lógica de Autenticación (Dominio y Presentación)

*   **[ ] Paso 6: Implementar el `AuthRepository`**
    *   **Interfaz (Dominio)**: `lib/features/auth/domain/repositories/auth_repository.dart`
    *   **Implementación (Datos)**: `lib/features/auth/data/repositories/auth_repository_impl.dart`

*   **[ ] Paso 7: Crear el `AuthViewModel` (`StateNotifier` o `AsyncNotifier`)**
    *   **Archivo**: `lib/features/auth/presentation/providers/auth_providers.dart`
    *   **Objetivo**: Manejar el estado de la UI (loading, error, success) y llamar al repositorio.

### Fase 5: Flujo de Navegación (`AuthGate`)

*   **[ ] Paso 8: Implementar `AuthGate`**
    *   **Archivo**: `lib/features/auth/presentation/widgets/auth_gate.dart`
    *   **Objetivo**: Widget que redirige al usuario a `Login` o `Home` según el `authStateStreamProvider`.
    *   **Uso**: Establecer `home: const AuthGate()` en `MaterialApp`.

### Fase 6: Limpieza Final

*   **[ ] Paso 9: Eliminar Gestión Manual de Tokens**
    *   **Acción**: Eliminar cualquier código que guarde o borre manualmente el token de `SharedPreferences`. Confiar en que `Supabase.instance.client.auth.signOut()` gestiona la limpieza de la sesión.
