import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/legal_document.dart';
import '../entities/legal_status.dart';

/// Interfaz del repositorio legal (dominio).
abstract class LegalRepository {
  /// Documentos legales vigentes (endpoint público).
  ///
  /// GET /legal/current
  Future<Either<Failure, List<LegalDocument>>> getCurrentDocuments();

  /// Estado de aceptación del usuario autenticado.
  ///
  /// GET /users/me/legal-acceptance
  Future<Either<Failure, LegalStatus>> getMyStatus();

  /// Registra la aceptación de las versiones indicadas. Idempotente.
  ///
  /// POST /users/me/legal-acceptance
  /// Falla con `errorCode: LEGAL_VERSION_MISMATCH` si las versiones ya no son
  /// las vigentes.
  Future<Either<Failure, LegalStatus>> accept({
    required String termsVersion,
    required String privacyVersion,
  });
}
