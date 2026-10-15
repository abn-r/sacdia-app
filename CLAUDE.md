# SACDIA App - Aplicación Móvil

App móvil Flutter para iOS y Android, organizada por features con capas data/domain/presentation.

## Comandos

```bash
flutter pub get         # Instalar dependencias
flutter run             # Ejecutar en emulador/device
flutter build apk       # Build Android
flutter build ios       # Build iOS
flutter test            # Tests
flutter analyze         # Analyzer
dart format .           # Formato (CI lo exige con --set-exit-if-changed)
```

## Estructura

```
lib/
├── main.dart           - Bootstrap: Sentry, Firebase, Hive, EasyLocalization, PostHog
├── core/
│   ├── analytics/      - PostHog
│   ├── auth/           - AppAuthService (tokens en FlutterSecureStorage)
│   ├── authorization/  - Screen catalog (espejo del admin)
│   ├── config/         - router.dart (go_router), route_names.dart, cache_config.dart
│   ├── constants/      - app_constants.dart, maps_constants.dart
│   ├── network/, errors/, notifications/, realtime/, storage/, theme/, widgets/, …
├── features/<feature>/ - 41 features; cada una con data/, domain/ y presentation/
│                         (home solo tiene presentation/)
├── shared/             - data, models y widgets compartidos
└── providers/          - Providers globales (dio, storage, catálogos, caché JSON)
```

Ejemplos de features: `auth`, `biometric`, `dashboard`, `activities`, `classes`, `honors`, `master_honors`, `certifications`, `investiture`, `members`, `units`, `finances`, `camporees`, `qr`, `virtual_card`, `monthly_reports`, `rankings`, `post_registration`. La lista completa es `ls lib/features`.

## Stack

- **Framework**: Flutter 3.41 (CI fija `3.41.6`; SDK Dart `^3.6.1`)
- **Arquitectura**: features con capas data/domain/presentation (Clean Architecture por feature)
- **State / DI**: Riverpod (`flutter_riverpod`)
- **Navegación**: `go_router` (`lib/core/config/router.dart`, `routerProvider`)
- **HTTP**: Dio
- **Almacenamiento local**:
  - Tokens: `FlutterSecureStorage` (`lib/core/auth/app_auth_service.dart`, `lib/core/storage/secure_storage.dart`)
  - Caché de catálogos y resúmenes: `SharedPreferences` y caché JSON en archivo (`lib/core/storage/json_file_cache.dart`, `cache_first.dart`)
  - Hive: solo borradores de certificación (`main.dart`, `features/certifications/data/local/`)
- **Archivos**: Cloudflare R2 vía URLs firmadas del backend
- **Auth**: AppAuthService — JWT HS256 emitido por el backend (Better Auth). Login biométrico con `local_auth` (`features/biometric`)
- **i18n**: `easy_localization` (`assets/translations/`: es, en, fr, pt-BR)
- **Push**: Firebase Cloud Messaging (+ Firebase App Check)
- **Observabilidad**: Sentry (`sentry_flutter`) y PostHog (`posthog_flutter`)
- **Modelos**: `freezed` + `json_serializable` (build_runner)
- **UI**: Hugeicons, `fl_chart`, `showcaseview` (onboarding contextual)

## Migraciones y cambios recientes

### Google Maps (reemplaza flutter_map)
- **Paquetes**: `google_maps_flutter` + `geolocator` (flutter_map eliminado)
- **API Keys**: Configuradas en `ios/Runner/AppDelegate.swift` (`GMSServices.provideAPIKey`) y `android/app/src/main/AndroidManifest.xml` (`com.google.android.geo.API_KEY`)
- **iOS simulator**: Requiere `GMSServices.setMetalRendererEnabled(false)` para renderizar correctamente
- **`liteModeEnabled: true`**: Solo funciona en Android — causa mapa en blanco en iOS, no usar en iOS
- **Vistas afectadas**: `LocationPickerView` (selector de ubicacion), `ActivityHeroSection` (hero en detalle de actividad)
- **Geolocator**: Centra el mapa en la ubicacion del usuario al abrir el picker

### Realtime cache invalidation (FCM)
- **Módulo**: `lib/core/realtime/` — contiene `RealtimeResourceRegistry`, `RealtimeInvalidationHandler`, `RealtimeRef` adapter y `feature_flags.dart`.
- **Feature flag**: `RealtimeFeatureFlags.realtimeInvalidationEnabled` (`bool.fromEnvironment('REALTIME_INVALIDATION_ENABLED')`, default `false`) — bloquea ambos paths si está desactivado. Se activa con `--dart-define=REALTIME_INVALIDATION_ENABLED=true`.
- **Path foreground**: `PushNotificationService._handleForegroundMessage` intercepta `data['type'] == 'cache_invalidate'` ANTES del guard que descarta mensajes sin notificación visible.
- **Path background**: `firebaseMessagingBackgroundHandler` guarda el payload en `SharedPreferences` (`pending_realtime_invalidations`); se drena al volver al frente via observer `AppLifecycleState.resumed` en el root `MyApp`.
- **Section guard**: el registry ignora el payload si el `sectionId` no coincide con el `clubContextProvider.sectionId` activo.
- **Registry**: recursos `'activities'` (`clubActivitiesProvider(ClubActivitiesParams(clubId, null))`) y `'members'`.
- **Contrato backend**: ver `sacdia-backend/src/notifications/notifications.processor.ts` (`handleRealtimeInvalidate`).

### Actividades conjuntas
- **`CreateActivityView`**: Toggle "Actividad conjunta" (`_JointActivityToggle`) visible solo para directores. Al activarlo muestra un picker de secciones con `SacFilterChip` y exige al menos 2 secciones.
- **`EditActivityView`**: Soporta edicion de actividades conjuntas — carga secciones existentes y permite modificar.
- **Auto-deteccion de seccion**: Para no-directores, la app resuelve la seccion automaticamente desde `ClubContext` (enriquecido con `club_type_name` desde grants). No se muestra selector de tipo de club.
- **Entidades**: `ActivityInstance` (value object), `ClubSectionModel` (modelo de seccion con `clubSectionId`, `clubTypeId`, `clubTypeName`).

## Variables de entorno (`--dart-define`)

| Clave | Dónde | Uso |
| --- | --- | --- |
| `API_BASE_URL` | `lib/core/constants/app_constants.dart` | **Obligatoria en release** y debe ser HTTPS (`AppConstants.resolveBaseUrl` lanza `StateError`). En debug/profile cae a `http://localhost:3000/api/v1`. CI la toma del secret `API_BASE_URL`. |
| `GOOGLE_MAPS_API_KEY` | `lib/core/constants/maps_constants.dart` | Solo Static Maps REST. El SDK interactivo usa `-P GOOGLE_MAPS_API_KEY` (Android) y `AppDelegate.swift` (iOS). |
| `POSTHOG_PROJECT_TOKEN` | `lib/core/analytics/posthog_analytics.dart` | Opcional; si falta usa el token público incluido. |
| `REALTIME_INVALIDATION_ENABLED` | `lib/core/realtime/feature_flags.dart` | Opcional (default `false`). |
| `SAC_DEBUG_PROFILE_BUILDS`, `SAC_DEBUG_PROFILE_PAINTS`, `SAC_DEBUG_REPAINT_RAINBOW` | `lib/main.dart` | Flags de diagnóstico de rendimiento. |

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://<host>/api/v1 \
  --dart-define=GOOGLE_MAPS_API_KEY=<key> \
  -P GOOGLE_MAPS_API_KEY=<key>
```

Google Maps en Android también requiere `android/secrets.properties` (ver `android/secrets.properties.example`).

## Authorization (screen catalog)

Hermano Dart de `sacdia-admin/src/lib/auth/screen-catalog/`. Entrada: `lib/core/authorization/`. Quick access, tabs Clases/Actividades y el router usan `canViewScreen(screenId)`. Paridad: `test/fixtures/screen-catalog.snapshot.json` vs `dumpAppCatalog()` en admin (`screen-catalog.app.test.ts`). Regenerar el fixture cuando cambie un gate `app` en TS y copiar el registro Dart.

## CI y deployment

- GitHub Actions (`.github/workflows/ci.yml`) en push/PR a `development`, `preproduction` y `main`: `dart format`, `flutter analyze`, `flutter test` y build Android (APK; AAB firmado y ofuscado cuando existen los secrets del keystore, con símbolos subidos a Sentry).
- Firma Android: `android/KEYSTORE.md`.
- Publicación en tiendas: pendiente de cuentas (`docs/store-release-checklist.md`, `docs/store-data-safety.md`). No hay Fastlane en el repo.
- Flujo de ramas: `development` → `preproduction` (QA) → `main`.

## Documentación

- Adaptador para agentes: `AGENTS.md`
- Sistema de diseño: `DESIGN-SYSTEM.md`
- Docs del workspace: `../docs/` (API, base de datos, features)
