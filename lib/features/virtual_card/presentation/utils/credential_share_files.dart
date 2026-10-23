import 'dart:io';

import '../../../../core/utils/app_logger.dart';

/// Tiempo que se deja vivo el archivo tras volver del share sheet: algunas
/// apps destino (Android) leen el contenido DESPUÉS de que `shareXFiles`
/// regrese, y borrarlo al instante rompería el envío.
const Duration kCredentialShareCleanupGrace = Duration(seconds: 30);

const String _tag = 'CredentialShareFiles';

bool _isShareFile(String path) {
  final name = path.split(Platform.pathSeparator).last;
  return name.startsWith('credencial_') &&
      (name.endsWith('.png') || name.endsWith('.pdf'));
}

/// Borra los archivos temporales de la credencial compartida (llevan nombre,
/// foto y QR, y un dependiente no debe dejar rastro; FP-49). Nunca lanza.
Future<void> deleteCredentialShareFiles(
  Iterable<File> files, {
  Duration grace = Duration.zero,
}) async {
  if (grace > Duration.zero) await Future<void>.delayed(grace);
  for (final file in files) {
    try {
      if (await file.exists()) await file.delete();
    } catch (e) {
      AppLogger.w('No se pudo borrar ${file.path}', tag: _tag, error: e);
    }
  }
}

/// Borra los `credencial_*.png|pdf` que hayan quedado en [directory] de un
/// compartir anterior (p. ej. la app murió dentro del periodo de gracia).
Future<void> sweepCredentialShareFiles(Directory directory) async {
  try {
    if (!await directory.exists()) return;
    final stale = <File>[
      await for (final entity in directory.list())
        if (entity is File && _isShareFile(entity.path)) entity,
    ];
    await deleteCredentialShareFiles(stale);
  } catch (e) {
    AppLogger.w('No se pudo barrer ${directory.path}', tag: _tag, error: e);
  }
}
