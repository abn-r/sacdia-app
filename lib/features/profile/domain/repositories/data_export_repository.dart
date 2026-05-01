import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/data_export.dart';

/// Interfaz del repositorio de exportaciones de datos (GDPR).
abstract class DataExportRepository {
  /// Solicita una nueva exportación de datos del usuario.
  ///
  /// POST /users/me/data-export
  /// - Devuelve [DataExport] con status pending en éxito (201 o 200 reutilizado).
  /// - Falla con [ServerFailure] (código 429) si ya hay una exportación
  ///   completada en las últimas 24h; el mensaje incluye el tiempo de espera.
  Future<Either<Failure, DataExport>> request();

  /// Obtiene el historial de exportaciones del usuario.
  ///
  /// GET /users/me/data-exports
  Future<Either<Failure, List<DataExport>>> list();

  /// Obtiene la URL de descarga presignada para una exportación lista.
  ///
  /// GET /users/me/data-exports/:exportId/download
  /// - Devuelve la URL (R2 presigned, TTL 15 min) en éxito.
  /// - Falla con [ServerFailure] en 404 / 409 / 410 / 422.
  Future<Either<Failure, String>> getDownloadUrl(String exportId);
}
