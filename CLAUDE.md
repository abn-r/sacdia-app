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

## Perfiles familiares (tutor y menores)

Un tutor puede crear y gestionar perfiles de menores (sin cuenta propia) y "actuar por" ellos. Backend: guardas `acting-for` y módulo `guardianships` (ver `../sacdia-backend/src/common/guards/README.md`).

### Actuar por (acting-for)

- **Sesión solo en memoria**: `ActingForSession` (`lib/core/auth/acting_for_session.dart`, `actingForSessionProvider`). Nunca se escribe en disco: al matar la app siempre se arranca como el tutor. Lleva `generation`, que sube en cada `enter`/`exit`.
- **Encabezado**: `X-Acting-For: <user_id del menor>` se inyecta SOLO en `AuthInterceptor.onRequest` (único punto). No lo añadas a mano en datasources.
- **Exenciones**: `AuthInterceptor.actingForSkipPrefixes` (`/auth/refresh|logout|login|register`, `/guardianships`, `/fcm-tokens`, `/users/me/fcm-tokens`, `/notifications/preferences`, `/users/me/notification-preferences`, `/users/me/data-export`) nunca llevan el encabezado. Una llamada concreta lo omite con `Options(extra: {AuthInterceptor.skipActingForKey: true})`; `FamilyRemoteDataSourceImpl` lo hace en todas las llamadas a `/guardianships` (el tutor gestiona la familia como tutor).
- **Token de generación**: `ActingGenerationInterceptor` sella cada petición con la generación vigente y rechaza como cancelación (`stale-acting-profile`) cualquier respuesta o error que llegue tras un cambio de perfil. Así los datos de Ana no llegan a la vista de Luis. El sello se pone en `AuthInterceptor.onRequest` en el mismo tramo síncrono que decide el encabezado (Dio encadena los interceptores con saltos al event loop); el reintento tras refrescar el token comprueba la generación antes de enviar y antes de entregar, y recalcula el encabezado. Todo Dio propio de una feature se crea con `buildAppDio(ref)` (`lib/providers/dio_provider.dart`) para llevar `onAuthExpired` y `onActingForbidden`.
- **`ActingErrorInterceptor`** (después del de generación, antes de `ErrorInterceptor`): ante `403 ACTING_FOR_FORBIDDEN` con `X-Acting-For` igual al menor vigente llama a `AuthNotifier.onActingForbidden` -> sale de actuar, vuelve al tutor y `ActingNoticeListener` muestra el aviso (`errors.acting_for_forbidden`). `ACTING_FOR_SCOPE_DENIED` pasa sin tocar: es un error de esa acción, no se sale del modo.
- **Errores de negocio**: leer solo `code` (y `message`). NUNCA `details`: el backend lo omite en producción. Helper: `lib/core/errors/business_error.dart`.
- **Cambio de perfil**: `AuthNotifier.switchProfile(id, {firstName})` devuelve `SwitchProfileOutcome`. Orden: foto del tutor, bandera `acting_dirty`, un bloque síncrono (`session.enter` + `purgeProfileScopeProviders` + `AsyncLoading`), purga de disco, `/auth/me` con el encabezado. Cualquier fallo vuelve al tutor (nunca cierra sesión ni restaura datos del menor desde caché). `switchProfile(null)` = salir.
- **403 en `/auth/me` actuando**: el datasource NO borra tokens si la petición llevaba `X-Acting-For` (si no, un `ACTING_FOR_FORBIDDEN` cerraría la sesión del tutor).
- **Mientras se actúa** no se cachea el usuario (`_cacheUser` es no-op), no se registra FCM ni se identifica en PostHog, y se ocultan sesiones, exportación de datos, cambio de contraseña y borrar cuenta (`actingDependentProvider`). `/family/**` redirige a home (`lib/core/config/acting_route_policy.dart`).
- **Limpieza en arranque en frío**: la bandera `acting_dirty` (`kActingDirtyPrefsKey`, única huella en disco, no identifica a nadie) se pone a `true` al actuar y a `false` al volver con cachés purgados. Si al arrancar sigue en `true` (la app murió actuando) y hay sesión, `AuthNotifier.build` purga los cachés de disco del perfil antes de continuar. El logout también limpia sesión, aviso y bandera.
- **Banner**: `ActingForBannerHost` se monta en el `builder` de `main.dart` ("Viendo como Ana") y cubre también el post-registro.
- **Limitación de Riverpod 2.6**: `state = AsyncLoading()` conserva el valor previo, así que el aislamiento depende de `isLoading` + purga del registro + purga de disco, no de que `valueOrNull` sea null.

### Registro de providers por perfil (regla obligatoria)

Todo provider con `keepAlive()` bajo `lib/features/**/providers/*.dart` vive en `lib/core/providers/profile_scope_registry.dart`, en uno de dos sitios:

1. `profileScopedKeepAliveEntries`: se invalida en cada cambio de perfil. Clave = símbolo que llama a `keepAlive()` (variable del provider, o nombre de la clase si se llama dentro de un notifier).
2. `catalogKeepAliveAllowlist`: catálogos o estado transitorio que no dependen de quién pregunta.

`test/core/providers/profile_scope_registry_test.dart` escanea el código y FALLA si aparece un `keepAlive()` que no esté en ninguno. Lo mismo rige para cualquier provider de estado SIN `autoDispose` (`StateProvider`, `Notifier`, `AsyncNotifier`, `FutureProvider`..., también con tipo explícito o como miembro `static`/`late`) bajo todo `lib/**`: va en `profileScopedStateEntries` (se invalida al cambiar de perfil) o en `nonAutoDisposeAllowlist` con el motivo por el que no depende del perfil; el mismo test falla si falta. Los `Provider` simples son derivados, salvo los que son dueños de estado mutable (notifier, caché, controlador, `onDispose`): el test los marca y cada uno se revisa a mano en `statefulPlainProviderAllowlist` (o se registra). La lista final es `profileScopedProviders` (más `userSpecificProviders`); `logout_cleanup.dart` la invalida entera. Las credenciales virtuales guardadas (`virtual_card_cache_*`) se purgan en cada cambio de perfil, logout y arranque sucio, y la credencial del menor nunca se escribe ni se lee de disco (el guardado se re-comprueba justo antes de escribir: perfil y generación); el widget del sistema de próxima actividad no se escribe mientras se actúa. Las marcas de salud `post_registration.health_none.<userId>.*` de todo usuario que no sea el tutor se purgan al cambiar de perfil, al salir y en el arranque sucio, y todas al cerrar sesión (`clearHealthNoneFlags`). Los cachés de imágenes (`SacCacheManager`, `SacProfileCacheManager` y la caché decodificada) se vacían al salir de un dependiente, en el arranque sucio y al cerrar sesión (`imageCachePurgerProvider`). El descarte del aviso de cumpleaños no escribe en disco mientras se actúa, y los temporales de compartir la credencial se borran tras compartir (`credential_share_files.dart`). `familyPromptSuppressedProvider` se reinicia al cerrar sesión. Un 403 en el reintento tras refrescar el token llega a `ActingErrorInterceptor` igual que cualquier otro.

**Regla para todo provider nuevo que guarde datos de UN perfil**: regístralo en `lib/core/providers/profile_scope_registry.dart` (`profileScopedKeepAliveEntries` si usa `keepAlive()`, `profileScopedStateEntries` si es un provider de estado sin `autoDispose`). Es lo que lo vacía en cada cambio de perfil y en el logout (`logout_cleanup.dart` invalida la lista entera; pasar de cuenta a adolescente o a dispositivo siempre pasa por logout y login). Sin eso, los datos de un perfil se ven en el siguiente. Ejemplos de la Fase 3c: `createdMinorUserIdsProvider` y `uploadedFormMinorUserIdsProvider` (ids de menores que el director registró o cuya ficha subió en esta sesión, para el aviso de cuatro ojos) están en `profileScopedStateEntries`; el test `profile_scope_registry_test.dart` falla si se olvida uno. Cubierto de extremo a extremo por `router_cross_mode_test.dart` (las conmutaciones cuenta, adolescente, dispositivo y actuar por logout y login no dejan datos en caché).

### Modos de sesión (Fase 3)

La app puede estar en cuatro modos. El servidor decide cuál es: `GET /auth/me` devuelve `principal.kind` (`PrincipalKind.parse`, `lib/features/auth/domain/entities/principal_info.dart`) y `UserEntity.mode` (`AccountMode`) lo deriva. Nunca se deduce de un claim del JWT ni de la edad calculada en el cliente. Un `kind` desconocido es `AccountMode.restricted` (falla cerrado: solo «Cerrar sesión», analítica anónima, jamás adulto) y `age_unknown_user` es `profileIncomplete`.

| Modo | `principal.kind` | `AccountMode` | Quién es |
| --- | --- | --- | --- |
| Cuenta | `user` | `adult` | Adulto o tutor en su propio perfil. Un principal ausente (servidor anterior a la Fase 3) también cuenta como adulto |
| Adolescente supervisado | `supervised_user` | `teenPending` (sin tutor verificado, `supervision.status = pending_guardian`) o `teenSupervised` (`active`). Si el estado no se pudo leer, cuenta como pendiente | Menor de 13 a 17 con cuenta propia |
| Dispositivo vinculado | `linked_device` | `linkedDevice` | Teléfono de un menor de 13, sin cuenta, enlazado por QR. Cáscara propia (`RouteNames.device*`): sin perfil, sin Mi familia |
| Tutor actuando | `guardian_acting` | `adult` (el JWT es el del tutor) | Tutor con `X-Acting-For` sobre un menor (ver «Actuar por») |

- **`SessionMode` es otra cosa** (`lib/core/auth/session_mode.dart`): solo `account | device`. Es una bandeja de arranque, NO identidad ni permiso. Se guarda en el almacenamiento seguro bajo `session_mode` (`AppConstants.sessionModeKey`) y solo se escribe el valor `device` (el modo cuenta es la ausencia de la clave). Existe para elegir la cáscara en el arranque en frío antes de que `/auth/me` responda y para no inicializar la analítica. `AuthNotifier._reconcileSessionMode` la reescribe con lo que dice el servidor (`linked_device` la pone en `device`; cualquier otro principal la borra; bandera `device` sin principal = principal desconocido, restringido). `sessionModeProvider` es la copia en memoria; se reinicia al cerrar sesión.
- **Un teléfono vinculado nunca manda `X-Acting-For`** (`AuthInterceptor.isDeviceSession`) y, si su refresh muere (`AUTH_DEVICE_REVOKED` o `AUTH_DEVICE_SESSION_EXPIRED`), vuelve a la pantalla de vinculación en lugar del login.
- **`PRINCIPAL_SCOPE_DENIED`** (403 de un adolescente o de un dispositivo en una ruta fuera de su alcance) no es un error de esa acción: `PrincipalScopeInterceptor` refresca `/auth/me` porque casi siempre el modo cambió en el servidor. No sale de actuar.
- **Regla**: toda pantalla o ruta nueva decide qué hace en cada modo antes de existir. El router descarta lo que el modo no permite (y `acting_route_policy.dart` lo que no se permite al actuar); el servidor sigue siendo la autoridad (403).

### Política de analítica por modo

`AnalyticsPolicy.apply` (`lib/core/analytics/analytics_policy.dart`) se ejecuta con cada usuario cargado. Falla cerrado:

- **Adulto**: se identifica en PostHog solo si `/auth/me.analytics_anonymous == false` explícito (`UserEntity.canIdentifyInAnalytics`: además `principal.kind == user` y modo `adult`). Campo ausente o desconocido = anónimo.
- **Adolescente supervisado, cuenta sin fecha de nacimiento o restringida**: NUNCA se identifica; se permiten eventos anónimos. Si el teléfono ya había identificado a otra persona, se hace `reset()` para no atar los eventos del menor a la identidad anterior.
- **Teléfono vinculado**: PostHog se desactiva por completo (`disableForDevice`: ni identify, ni eventos, ni pantallas). En un arranque en frío con `session_mode = device`, `main()` llama `blockAnalyticsForDevice()` ANTES de `setupPosthog()`, así que PostHog ni se inicializa. FCM sí. Si el teléfono deja de ser dispositivo (login de cuenta tras desvincular) se reactiva (`enableAfterDevice`).
- **Tutor actuando**: la política no hace nada (`acting` → return): no se identifica al menor ni se toca la identidad del tutor.
- Un provider o servicio nuevo que envíe eventos a terceros (PostHog, Sentry con usuario) debe pasar por esta política; no identifiques a nadie con `UserEntity.id` por tu cuenta.

### Push tocado: ruta por modo (`lib/core/notifications/`)

`PushNotificationService._handleNotificationTap` decide por modo; el payload nunca elige la ruta ni el perfil.

- **Dispositivo vinculado** (`sessionModeProvider == device`): `deviceRouteForPush` (`device_push_route.dart`) ignora `dependent_user_id`; abre `/class/<id>` o `/activity/<id>` de la cáscara del dispositivo y cualquier otra cosa cae en la bandeja de avisos del dispositivo.
- **Push de familia** (`family_push_route.dart`): `familyPushKindOf` acepta DOS vocabularios porque el backend manda `data.type` = `dependent_security`, `dependent_evidence_uploaded`, `dependent_age_milestone`, `teen_guardian_reminder` y `teen_guardian_linked`, mientras que `family:security`, `family:evidence_uploaded`, `family:age_nudge` y `family:teen_reminder` son el `source` de la notificación (también se leen de `data.source`). `familyPushTarget` resuelve el destino por `principal.kind`:
  - Tutor (`user` o `guardian_acting`, modo adulto): el detalle del menor `/family/{uuid}` (donde está «Acceso»; el id solo se interpola en la ruta si es un UUID, si no `/family`); si se actúa por un menor se sale de actuar primero. El aviso al adolescente (`teen_guardian_*`) lleva a la bandeja.
  - Adolescente supervisado: `teenSupervised` abre la bandeja de avisos (jamás `/family`); `teenPending` abre su pantalla de estado (`teenPendingHome`).
  - Dispositivo, cuenta sin edad, principal desconocido o sin sesión: nada.
- **Cambio de perfil por un push de un menor** (`DependentPushTapHandler`): el diálogo «¿cambiar a su perfil?» solo se ofrece a quien puede actuar (`mayConfirmProfileSwitch`: `user` o `guardian_acting`). Adolescentes, dispositivos y cuentas restringidas ignoran `dependent_user_id`.
- **Arranque en frío**: si el router aún está en `splash`, el destino se guarda en `pendingNavigationProvider` y se entrega cuando la sesión está lista, solo si la política del modo lo permite.

### Mi familia (`lib/features/family/`)

Feature `data/domain/presentation` con 7 use cases (`list_dependents`, `get_dependent_detail`, `create_dependent`, `issue_link_code`, `redeem_link_code`, `revoke_guardianship`, `get_deletion_impact`). Los providers de la feature no usan `keepAlive`.

| Ruta | Vista |
| --- | --- |
| `/family` (`RouteNames.family`) | `FamilyView`: lista de menores, cupo (`canAddMore`) y accionables (`actable`) |
| `/family/add` | `AddDependentView` (paso 0) |
| `/family/link` | `RedeemLinkCodeView`: canjear código de segundo tutor |
| `/family/:dependentId` | `DependentDetailView`: tutores, consentimiento, código de invitación, salir/revocar |

Entrada desde el perfil (`FamilyProfileEntry`, oculta al actuar); `FamilyPromptHost` pregunta una sola vez al completar el post-registro. Selector de perfil: `ProfileSwitcherSheet` + `switchToDependent`.

### Alta de un menor

1. **Paso 0** (`AddDependentView`): nombre, fecha de nacimiento, parentesco, declaración bajo protesta y aceptación de Términos/Privacidad EN NOMBRE del menor, con las versiones de `GET /legal/current` que el tutor vio. Los errores del servidor se mapean por `code` (`familyErrorKey`).
2. Al crearlo, la app llama `switchToDependent` y el router lleva al post-registro (pasos 1-3) YA actuando por el menor. El tutor completa el post-registro del menor; no hay paso de representante legal (se eliminó `LegalRepresentativeView`; el backend solo expone GET).

### Salida solo como tutor (guardian-only)

`GuardianOnlyExit` (`lib/features/post_registration/presentation/widgets/`): un adulto sin club puede terminar el post-registro como "solo tutor" (`POST .../step-3/guardian-only`). Oculto si se actúa por un menor o si `user.actingFor != null`, y no se muestra en traslado de club. Éxito: marca el post-registro completo, va a home y abre `/family` (suprime una vez `FamilyPromptHost`). `422 POST_REG_GUARDIAN_ONLY_REQUIRES_ADULT` se traduce por `code`.

### Control de edad en el registro

`RegisterView` exige fecha de nacimiento (se envía `YYYY-MM-DD`). Compuerta local `< 13` (`registration_age_gate.dart`, `kDefaultMinSelfLoginAge`) muestra `_AgeGatePanel` sin llamar a la API; el mínimo por país solo lo aplica el servidor (`AUTH_REGISTRATION_AGE_BELOW_MINIMUM`, publicado como `RegistrationAgeBelowMinimum`). Usa `Localizations.localeOf(context)` (no `context.locale`, que lanza si EasyLocalization no está montado).

### Borrar cuenta con dependientes

`DeleteAccountFlow` consulta `deletionImpactProvider` y muestra `DeleteAccountDependentsDialog` ANTES de pedir la contraseña, con el destino de cada menor (transferido, custodia, congelado). El backend verifica la contraseña antes del `acknowledge_dependents`, así que `409 AUTH_DELETE_DEPENDENTS_ACK_REQUIRED` solo llega con contraseña válida: se vuelve a mostrar la advertencia con la lista fresca y se reintenta (máx. 2) con `acknowledge_dependents: true`. Si el impacto no carga no se bloquea: el servidor decide.

### Push de un menor

El servidor reenvía al tutor los push del menor (`data.dependent_user_id`, título "Ana · ..."). `DependentPushTapHandler` (`lib/core/notifications/`): espera la sesión del tutor, relee `GET /guardianships/me/dependents` (sin `X-Acting-For`) y exige que el menor esté en `actable`; si no, avisa (`family.push.unavailable`) y NO cambia de perfil. Si ya se actúa por ese menor solo navega. Si no, diálogo "Esta notificación es de Ana. ¿Cambiar a su perfil?" y, al aceptar, `switchProfile` con el id de la lista (el id del payload solo se compara, nunca se usa para actuar). En primer plano estos push no suman al contador ni invalidan el inbox del tutor (pertenecen al inbox del menor).

### i18n: paridad de traducciones

`test/core/l10n/translation_parity_test.dart` exige que en, fr y pt-BR tengan exactamente las llaves de es (solo 2 huecos históricos permitidos en `_knownGaps`: no añadir más), sin textos vacíos, mismos placeholders en `family.*`/`errors.*`, y una traducción `errors.<code en minúsculas>` por cada código de Fase 2 (`_phase2ErrorCodes`). Al añadir un código de error del backend, agrégalo a esa lista y a los 4 idiomas.

## CI y deployment

- GitHub Actions (`.github/workflows/ci.yml`) en push/PR a `development`, `preproduction` y `main`: `dart format`, `flutter analyze`, `flutter test` y build Android (APK; AAB firmado y ofuscado cuando existen los secrets del keystore, con símbolos subidos a Sentry).
- Firma Android: `android/KEYSTORE.md`.
- Publicación en tiendas: pendiente de cuentas (`docs/store-release-checklist.md`, `docs/store-data-safety.md`). No hay Fastlane en el repo.
- Flujo de ramas: `development` → `preproduction` (QA) → `main`.

## Documentación

- Adaptador para agentes: `AGENTS.md`
- Sistema de diseño: `DESIGN-SYSTEM.md`
- Docs del workspace: `../docs/` (API, base de datos, features)
