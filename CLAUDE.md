# SACDIA App - Aplicación Móvil

App móvil Flutter para iOS y Android con Clean Architecture.

## Comandos

```bash
flutter pub get         # Instalar dependencias
flutter run             # Ejecutar en emulador/device
flutter build apk       # Build Android
flutter build ios       # Build iOS
flutter test            # Tests
flutter analyze         # Analyzer
```

## Estructura

```
lib/
├── core/
│   ├── constants/      - Constantes globales
│   ├── theme/          - Tema de la app
│   └── utils/          - Utilidades
├── data/
│   ├── models/         - Modelos de datos
│   ├── repositories/   - Implementación de repos
│   └── datasources/    - API clients
├── domain/
│   ├── entities/       - Entidades del negocio
│   ├── repositories/   - Interfaces de repos
│   └── usecases/       - Casos de uso
└── presentation/
    ├── screens/        - Pantallas
    ├── widgets/        - Widgets reutilizables
    └── providers/      - State management
```

## Stack

- **Framework**: Flutter 3.x
- **Architecture**: Clean Architecture
- **State**: Riverpod
- **HTTP**: Dio
- **Storage**: Hive (local) + Cloudflare R2 (via backend signed URLs)
- **Auth**: AppAuthService — JWT HS256 via backend API (Better Auth, Wave 3)
- **Push**: Firebase Cloud Messaging

## Particularidades

- **Clean Architecture**: Separación estricta domain/data/presentation
- **Dependency Injection**: Riverpod providers
- **Offline First**: Hive para cache local
- **API**: Consumir backend en `http://localhost:3000` (dev)
- **Tokens**: JWT almacenado en Hive de forma segura

## Migraciones y cambios recientes

### Google Maps (reemplaza flutter_map)
- **Paquetes**: `google_maps_flutter` + `geolocator` (flutter_map eliminado)
- **API Keys**: Configuradas en `ios/Runner/AppDelegate.swift` (`GMSServices.provideAPIKey`) y `android/app/src/main/AndroidManifest.xml` (`com.google.android.geo.API_KEY`)
- **iOS simulator**: Requiere `GMSServices.setMetalRendererEnabled(false)` para renderizar correctamente
- **`liteModeEnabled: true`**: Solo funciona en Android — causa mapa en blanco en iOS, no usar en iOS
- **Vistas afectadas**: `LocationPickerView` (selector de ubicacion), `ActivityHeroSection` (hero en detalle de actividad)
- **Geolocator**: Centra el mapa en la ubicacion del usuario al abrir el picker

### Actividades conjuntas
- **`CreateActivityView`**: Toggle "Actividad conjunta" (`SwitchListTile`) visible para directores con 2+ secciones. Al activar, muestra `FilterChip` picker para seleccionar secciones.
- **`EditActivityView`**: Soporta edicion de actividades conjuntas — carga secciones existentes y permite modificar.
- **Auto-deteccion de seccion**: Para no-directores, la app resuelve la seccion automaticamente desde `ClubContext` (enriquecido con `club_type_name` desde grants). No se muestra selector de tipo de club.
- **Entidades nuevas**: `ActivityInstance` (value object), `ClubSectionModel` (modelo de seccion con `clubSectionId`, `clubTypeId`, `clubTypeName`).

## Configuración

```yaml
# pubspec.yaml - principales dependencias
flutter_riverpod    # State management
dio                 # HTTP client
hive                # Local storage
google_maps_flutter # Mapas nativos (reemplaza flutter_map)
geolocator          # Ubicacion del usuario
# supabase_flutter removed in Wave 3 — auth is now handled via backend API
```

## Variables de Entorno

Configurar en `lib/core/constants/env.dart`:

- `API_BASE_URL`
- `FCM_SENDER_ID`

## Deployment

- **Android**: Google Play Console
- **iOS**: App Store Connect
- **Build**: Usar Fastlane para automatización
