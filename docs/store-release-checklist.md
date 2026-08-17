# Checklist de publicación en tiendas — PENDIENTE (esperando cuentas)

Estado: **BLOQUEADO** — sin cuentas de Apple Developer ni Play Console.
Se desbloquea cuando el MVP sea aprobado y se asigne el recurso.
Última revisión: 2026-08-12.

## Bloqueado por cuenta de Apple Developer (~99 USD/año)

- [ ] Crear cuenta / obtener membresía Apple Developer
- [ ] Registrar App ID `com.sacdia.app` con capability **Push Notifications**
      (el entitlement `aps-environment` ya está en el repo — PR #146)
- [ ] Generar certificados y provisioning profiles de distribución
- [ ] Subir APNs Auth Key a Firebase (para que FCM entregue push en iOS)
- [ ] App Store Connect: crear app, ficha, screenshots, App Privacy
      (usar `docs/store-data-safety.md` como fuente)
- [ ] TestFlight: build de prueba + verificar push de producción

## Bloqueado por cuenta de Play Console (25 USD única vez)

- [ ] Crear cuenta de Play Console
- [ ] Crear app + ficha de tienda, screenshots, clasificación de contenido
- [ ] Formulario **Data Safety** (usar `docs/store-data-safety.md`)
- [ ] Habilitar Play App Signing y registrar upload key
      (generar keystore según `android/KEYSTORE.md` §1 — puede hacerse antes)
- [ ] Definir target audience (la app gestiona menores; revisar políticas de familias)

## No bloqueado por cuentas (puede hacerse ya)

- [ ] Generar keystore Android + respaldo en gestor de contraseñas (`android/KEYSTORE.md`)
- [ ] Secrets en GitHub (sacdia-app): `API_BASE_URL`, `ANDROID_KEYSTORE_BASE64`,
      `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS`,
      `SENTRY_AUTH_TOKEN` (opcional)
- [ ] Decidir dominio de producción del API (`sacdia-backend.onrender.com` vs propio)
      → desbloquea PR-6 (deep links + assetlinks.json / apple-app-site-association)
- [ ] Render: Blueprint conectado, `ALLOWED_ORIGINS`, `SWAGGER_ENABLED=false` (PR #393)
- [ ] QA de build release firmado en dispositivo físico (validar R8 — PR #144)

## Referencias

- Plan completo de PRs: conversación de auditoría de producción (2026-08-12)
- PRs de preparación: sacdia-app #143 #144 #145 #146 · sacdia-backend #393
