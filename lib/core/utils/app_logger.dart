import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';

/// Logger centralizado para sacdia-app.
///
/// Solo imprime en modo debug. En producción todos los métodos
/// son no-ops para evitar fugas de información y overhead.
///
/// Uso:
///   AppLogger.i('Mensaje informativo');
///   AppLogger.w('Advertencia', tag: 'AuthInterceptor');
///   AppLogger.e('Error crítico', error: e);
///
/// Convención de tags: usa el nombre de la clase/módulo, sin corchetes.
/// El logger añade los corchetes automáticamente.
abstract class AppLogger {
  // ──────────────────────────────────────────────────────────────
  // Niveles
  // ──────────────────────────────────────────────────────────────

  /// Información general de flujo normal.
  static void i(String message, {String? tag}) {
    _log('INFO', message, tag: tag);
  }

  /// Advertencia: algo inesperado pero recuperable.
  static void w(String message, {String? tag, Object? error}) {
    _log('WARN', message, tag: tag, error: error);
  }

  /// Error: operación fallida que requiere atención.
  static void e(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log('ERR ', message, tag: tag, error: error, stackTrace: stackTrace);
  }

  /// Solo para depuración puntual. Evitar dejar en código permanente.
  static void d(String message, {String? tag}) {
    assert(() {
      _log('DBG ', message, tag: tag);
      return true;
    }());
  }

  // ──────────────────────────────────────────────────────────────
  // Implementación interna
  // ──────────────────────────────────────────────────────────────

  static void _log(
    String level,
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!kDebugMode) return;

    final prefix = tag != null ? '[$tag] ' : '';
    final errorSuffix = error != null ? ' | $error' : '';
    final output = '$level $prefix$message$errorSuffix';

    dev.log(output, name: 'SACDIA', error: error, stackTrace: stackTrace);
  }
}
