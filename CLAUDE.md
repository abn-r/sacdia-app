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

## Configuración

```yaml
# pubspec.yaml - principales dependencias
flutter_riverpod    # State management
dio                 # HTTP client
hive                # Local storage
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
