# SACDIA App — AGENTS.md

Adaptador GGA para `sacdia-app`.
La fuente de verdad operativa es `../AGENTS.md` cuando este repo se trabaja dentro del workspace `sacdia`.

## Orden obligatorio de lectura

1. `../AGENTS.md` si existe.
2. `./CLAUDE.md`.
3. `../docs/README.md`.
4. `../docs/steering/tech.md`.
5. `../docs/steering/coding-standards.md`.
6. `../docs/steering/data-guidelines.md`.
7. `../docs/api/FRONTEND-INTEGRATION-GUIDE.md`.
8. `../docs/api/ENDPOINTS-LIVE-REFERENCE.md`.
9. `../docs/features/` del dominio afectado.

Si el repo esta abierto aislado y `../AGENTS.md` no existe, usar este archivo como minimo operativo y pedir/recuperar el contexto del workspace antes de cambios transversales.

## Reglas app

- Flutter + Riverpod con capas `data` / `domain` / `presentation` por feature (`lib/features/<feature>/`).
- Navegación con `go_router` (`lib/core/config/router.dart`); gates de pantalla con `canViewScreen(screenId)`.
- Tokens solo en `FlutterSecureStorage` (`lib/core/auth/app_auth_service.dart`); no guardarlos en Hive ni en SharedPreferences.
- No modificar `sacdia-backend` desde este repo; si falta un endpoint, entregar handoff al usuario.
- Verificar endpoints, campos y permisos en `ENDPOINTS-LIVE-REFERENCE.md` y en el código backend efectivo; no asumir contratos.
- No ejecutar build salvo pedido explicito del usuario.
- Si cambia un flujo funcional o consumo API, actualizar docs de feature/API en el mismo trabajo.
- UI: seguir `DESIGN-SYSTEM.md`.
