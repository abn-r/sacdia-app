# SACDIA App

Aplicación móvil del Sistema de Administración de Clubes JA (Conquistadores,
Aventureros y Guías Mayores). Flutter + Riverpod con Clean Architecture.

Parte del monorepo [sacdia](https://github.com/abn-r): backend NestJS
(`sacdia-backend`), panel admin Next.js (`sacdia-admin`) y esta app.

## Requisitos

- Flutter 3.41.x (stable) — ver `.github/workflows/ci.yml` para la versión pineada
- Backend corriendo localmente (`sacdia-backend`, puerto 3000) o una URL remota

## Desarrollo

```bash
flutter pub get

# Contra backend local (default: http://localhost:3000/api/v1)
flutter run

# Contra otro backend
flutter run --dart-define=API_BASE_URL=https://<host>/api/v1
```

Google Maps requiere `android/secrets.properties` (ver
`android/secrets.properties.example`).

## Builds de release

`API_BASE_URL` es **obligatoria** y debe ser HTTPS; el build lanza `StateError`
al arrancar si falta:

```bash
flutter build appbundle --release \
  --obfuscate --split-debug-info=build/app/outputs/symbols \
  --dart-define=API_BASE_URL=https://<host>/api/v1 \
  --dart-define=GOOGLE_MAPS_API_KEY=<key> \
  -P GOOGLE_MAPS_API_KEY=<key>
```

Firma Android: ver `android/KEYSTORE.md`. El CI produce el AAB firmado cuando
los secrets `ANDROID_KEYSTORE_*` están configurados.

## Calidad

```bash
dart format .
flutter analyze
flutter test
```

## Documentación

- Contexto para agentes: `CLAUDE.md` y `AI-CONTEXT.md`
- Sistema de diseño: `DESIGN-SYSTEM.md`
- Docs del monorepo: `../docs/` (API, base de datos, features)
