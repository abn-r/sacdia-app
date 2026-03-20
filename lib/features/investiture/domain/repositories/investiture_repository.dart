import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/investiture_pending.dart';
import '../entities/investiture_history_entry.dart';

/// Repositorio de investidura (interfaz del dominio).
abstract class InvestitureRepository {
  /// Envía un enrollment para validación de investidura.
  /// POST /api/v1/enrollments/:enrollmentId/submit-for-validation
  /// Rol requerido: director, counselor (ClubRolesGuard).
  Future<Either<Failure, void>> submitForValidation({
    required int enrollmentId,
    required int clubId,
    String? comments,
  });

  /// Aprueba o rechaza un enrollment enviado.
  /// POST /api/v1/enrollments/:enrollmentId/validate
  /// Rol requerido: admin, coordinator (GlobalRolesGuard).
  Future<Either<Failure, void>> validateEnrollment({
    required int enrollmentId,
    required String action, // 'APPROVED' | 'REJECTED'
    String? comments,
  });

  /// Marca un enrollment aprobado como INVESTIDO.
  /// POST /api/v1/enrollments/:enrollmentId/investiture
  /// Rol requerido: admin, coordinator (GlobalRolesGuard).
  Future<Either<Failure, void>> markAsInvestido({
    required int enrollmentId,
    String? comments,
  });

  /// Obtiene la lista paginada de enrollments pendientes de validación.
  /// GET /api/v1/investiture/pending
  /// Rol requerido: admin, coordinator (GlobalRolesGuard).
  Future<Either<Failure, List<InvestiturePending>>> getPendingInvestitures({
    int? localFieldId,
    int? ecclesiasticalYearId,
    int page = 1,
    int limit = 20,
  });

  /// Obtiene el historial de acciones de investidura de un enrollment.
  /// GET /api/v1/enrollments/:enrollmentId/investiture-history
  /// Rol requerido: JwtAuthGuard (cualquier usuario autenticado).
  Future<Either<Failure, List<InvestitureHistoryEntry>>> getInvestitureHistory({
    required int enrollmentId,
  });
}
