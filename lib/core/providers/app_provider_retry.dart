/// Política de reintento de los providers de la app (raíz `ProviderScope`).
///
/// Riverpod 3 reintenta por defecto los providers que fallan (hasta 10 veces,
/// ~38 s, dejando el estado en `AsyncLoading`) y los fallos de la app llegan
/// como `Exception` genérica, sin poder separar red de 4xx/403. Devolver `null`
/// desactiva el reintento: el error se muestra al instante y la recuperación es
/// manual (pull-to-refresh o `invalidate`), igual que en Riverpod 2.6.
///
/// Único punto de configuración del reintento de la app; `lib/main.dart` lo
/// pasa como `ProviderScope(retry: appProviderRetry)`.
Duration? appProviderRetry(int retryCount, Object error) => null;
