import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/role_assignment.dart';

/// Repositorio de asignaciones de rol (interfaz del dominio)
abstract class RoleAssignmentsRepository {
  /// Obtiene la lista de asignaciones del usuario autenticado.
  /// GET /api/v1/requests/assignments
  Future<Either<Failure, List<RoleAssignment>>> getAssignments();
}
