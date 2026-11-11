import 'dart:io';

import '../../../../core/utils/app_logger.dart';

/// Tiempo que se deja vivo el archivo tras volver del share sheet: algunas apps
/// destino (Android) leen el contenido DESPUÉS de que el share regrese.
const Duration kFinanceExportCleanupGrace = Duration(seconds: 30);

const String _tag = 'FinanceExportFiles';

bool _isExportFile(String path) {
  final name = path.split(Platform.pathSeparator).last;
  return name.startsWith('finanzas-') &&
      (name.endsWith('.xlsx') || name.endsWith('.pdf'));
}

/// Escribe [bytes] en [directory] como [fileName] y devuelve el archivo.
Future<File> writeFinanceExportFile(
  Directory directory,
  String fileName,
  List<int> bytes,
) async {
  await sweepFinanceExportFiles(directory);
  final file = File('${directory.path}${Platform.pathSeparator}$fileName');
  await file.writeAsBytes(bytes, flush: true);
  return file;
}

/// Borra los archivos temporales exportados (llevan los números del club).
/// Nunca lanza.
Future<void> deleteFinanceExportFiles(
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

/// Borra los `finanzas-*.xlsx|pdf` que hayan quedado de una exportación
/// anterior (p. ej. la app murió dentro del periodo de gracia).
Future<void> sweepFinanceExportFiles(Directory directory) async {
  try {
    if (!await directory.exists()) return;
    final stale = <File>[
      await for (final entity in directory.list())
        if (entity is File && _isExportFile(entity.path)) entity,
    ];
    await deleteFinanceExportFiles(stale);
  } catch (e) {
    AppLogger.w('No se pudo barrer ${directory.path}', tag: _tag, error: e);
  }
}
