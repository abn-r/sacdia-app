import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../entities/investiture_request.dart';
import '../entities/investiture_resolution.dart';
import '../entities/own_investiture_entry.dart';
import '../entities/presentation_context.dart';
import '../entities/yearbook_entry.dart';

/// Contrato de la investidura por autorización.
abstract class InvestitureRequestsRepository {
  // ── Directiva de la sección ────────────────────────────────────────────────

  Future<Either<Failure, PresentationContext>> presentationContext(
    int sectionId,
    int yearId, {
    RequestCancelToken? cancelToken,
  });

  /// Solicitud con pendientes de la sección y el año, o `null` si no hay.
  Future<Either<Failure, InvestitureRequest?>> openRequestFor(
    int sectionId,
    int yearId, {
    RequestCancelToken? cancelToken,
  });

  Future<Either<Failure, InvestitureRequest>> present({
    required int sectionId,
    required int yearId,
    required DateTime investitureDate,
    required List<int> enrollmentIds,
  });

  Future<Either<Failure, InvestitureRequest>> addPeople({
    required String requestId,
    required DateTime investitureDate,
    required List<int> enrollmentIds,
  });

  Future<Either<Failure, RequestPerson>> removePerson({
    required String requestId,
    required String personId,
  });

  Future<Either<Failure, InvestitureRequest>> changeDates({
    required String requestId,
    required DateTime investitureDate,
    required List<String> personIds,
  });

  // ── Historial y anuario ────────────────────────────────────────────────────

  Future<Either<Failure, List<OwnInvestitureEntry>>> getOwnHistory({
    RequestCancelToken? cancelToken,
  });

  Future<Either<Failure, List<OwnInvestitureEntry>>> getSectionHistory(
    int sectionId, {
    RequestCancelToken? cancelToken,
  });

  Future<Either<Failure, List<YearbookEntry>>> getSectionYearbook(
    int sectionId, {
    RequestCancelToken? cancelToken,
  });

  // ── Autorizador (pastor, director-lf, assistant-lf) ────────────────────────

  Future<Either<Failure, List<InvestitureRequest>>> listForAuthorizer(
    int yearId, {
    RequestCancelToken? cancelToken,
  });

  Future<Either<Failure, InvestitureRequest>> readForAuthorizer(
    String requestId, {
    RequestCancelToken? cancelToken,
  });

  Future<Either<Failure, InvestitureResolution>> resolve({
    required String requestId,
    List<InvestDecision> invest,
    List<RejectDecision> reject,
  });
}
