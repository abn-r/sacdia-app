import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/active_session.dart';

/// Interfaz del repositorio de sesiones activas.
abstract class ActiveSessionsRepository {
  /// Obtiene la lista de sesiones activas del usuario autenticado.
  ///
  /// GET /auth/sessions
  Future<Either<Failure, List<ActiveSession>>> list();

  /// Revoca una sesión específica por su ID.
  ///
  /// DELETE /auth/sessions/:sessionId
  /// - Falla con [ServerFailure] (código 400) si se intenta revocar la sesión actual.
  /// - Falla con [ServerFailure] (código 403) si la sesión pertenece a otro usuario.
  /// - Falla con [ServerFailure] (código 404) si la sesión ya no existe.
  Future<Either<Failure, void>> revoke(String sessionId);

  /// Revoca todas las sesiones excepto la actual.
  ///
  /// DELETE /auth/sessions
  /// Retorna la cantidad de sesiones revocadas.
  Future<Either<Failure, int>> revokeAllOthers();
}
