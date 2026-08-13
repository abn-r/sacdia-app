# Play Console — Data Safety (respuestas canónicas)

Fuente de verdad para el formulario **Play Console > App content > Data safety**.
Debe mantenerse alineado con `ios/Runner/PrivacyInfo.xcprivacy` (App Store) y con
la recolección real de la app. Última revisión: 2026-08-12.

## Respuestas generales

| Pregunta | Respuesta |
|---|---|
| ¿Recopila o comparte datos de usuario? | Sí, recopila. No comparte con terceros. |
| ¿Los datos se cifran en tránsito? | Sí (HTTPS obligatorio en release). |
| ¿Los usuarios pueden solicitar eliminación? | Sí — eliminación de cuenta dentro de la app (Ajustes) + `https://sacdia.com/privacy`. |
| ¿Datos tratados de forma efímera? | No. |
| ¿Dirigida a niños? | Revisar clasificación: la app gestiona menores (Aventureros/Conquistadores) pero las cuentas son de miembros/directivos. Definir target audience en consola. |

## Tipos de datos recopilados

Todos con propósito **App functionality**, vinculados a la identidad del
usuario, sin uso publicitario ni tracking.

| Categoría Play | Datos concretos | Origen en la app |
|---|---|---|
| Personal info → Name | Nombre y apellidos | Registro / perfil |
| Personal info → Email address | Email de cuenta | Better Auth |
| Personal info → User IDs | ID de usuario SACDIA | Backend |
| Personal info → Address | Dirección personal | Post-registro / perfil |
| Personal info → Phone number | Teléfonos de contactos de emergencia y representantes legales | Post-registro |
| Health info | Tipo de sangre, alergias, medicamentos | Post-registro |
| Location → Precise location | Ubicación para actividades y mapas | geolocator / Google Maps |
| Photos and videos → Photos | Foto de perfil, evidencias de clases/honores | image_picker / cámara |
| App info and performance → Crash logs | Reportes de crash (PII redactada) | Sentry |
| App info and performance → Diagnostics | Métricas de rendimiento | Sentry |

## No recopilado

Sin datos financieros, historial web, contactos del dispositivo, SMS/llamadas,
audio, ni identificadores publicitarios. `NSPrivacyTracking = false`; sin SDKs
de ads.

## Recordatorios de sincronización

- Cambia la recolección → actualizar este doc + `PrivacyInfo.xcprivacy` + formulario de Play + App Privacy en App Store Connect.
- Eliminación de cuenta implementada en `settings_view.dart` (requisito Play/Apple).
