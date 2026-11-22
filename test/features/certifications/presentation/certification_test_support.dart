import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:hive/hive.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/usecases/cancellation_token.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/certifications/data/local/certification_draft_local_data_source.dart';
import 'package:sacdia_app/features/certifications/domain/entities/certification.dart';
import 'package:sacdia_app/features/certifications/domain/entities/certification_activity_option.dart';
import 'package:sacdia_app/features/certifications/domain/entities/certification_detail.dart';
import 'package:sacdia_app/features/certifications/domain/entities/certification_eligibility.dart';
import 'package:sacdia_app/features/certifications/domain/entities/certification_module.dart';
import 'package:sacdia_app/features/certifications/domain/entities/certification_progress.dart';
import 'package:sacdia_app/features/certifications/domain/entities/certification_requirement.dart';
import 'package:sacdia_app/features/certifications/domain/entities/certification_requirement_component.dart';
import 'package:sacdia_app/features/certifications/domain/entities/certification_section.dart';
import 'package:sacdia_app/features/certifications/domain/entities/certification_status.dart';
import 'package:sacdia_app/features/certifications/domain/entities/user_certification.dart';
import 'package:sacdia_app/features/certifications/domain/repositories/certifications_repository.dart';

/// A signed-in user, so providers that need a user id resolve.
class FakeCertificationAuth extends AuthNotifier {
  @override
  Future<UserEntity?> build() async =>
      const UserEntity(id: 'user-1', email: 'u@example.com');
}

/// Hive-free drafts: the real source reads a [Box], which needs the disk.
class FakeDraftSource extends CertificationDraftLocalDataSource {
  FakeDraftSource() : super(_NoBox());

  final Map<String, Map<int, CertificationComponentDraftInput>> saved = {};

  @override
  Map<int, CertificationComponentDraftInput>? getDraft(
    int enrollmentId,
    int sectionId,
  ) =>
      saved[CertificationDraftLocalDataSource.keyFor(enrollmentId, sectionId)];

  @override
  Future<void> saveDraft(
    int enrollmentId,
    int sectionId,
    Map<int, CertificationComponentDraftInput> values,
  ) async {
    saved[CertificationDraftLocalDataSource.keyFor(enrollmentId, sectionId)] =
        values;
  }

  @override
  Future<void> clearDraft(int enrollmentId, int sectionId) async {
    saved.remove(
      CertificationDraftLocalDataSource.keyFor(enrollmentId, sectionId),
    );
  }
}

class _NoBox implements Box<String> {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// Repository whose answers each test sets; everything else throws.
class FakeCertificationsRepository implements CertificationsRepository {
  List<Certification> catalog = const [];
  List<UserCertification> enrollments = const [];
  Map<int, Either<Failure, CertificationEligibility>> eligibility = {};
  CertificationRequirement? requirement;
  List<CertificationActivityOption> activityOptions = const [];

  /// Last `responses` sent to `saveRequirementDraft`.
  List<CertificationComponentDraftInput>? savedDraft;
  int submitCalls = 0;

  /// `lockVersion` received by the last `submitRequirement`.
  int? lastLockVersion;

  /// When set, `submitRequirement` throws it (a raw transport error).
  Object? submitError;

  @override
  Future<Either<Failure, List<Certification>>> getCertifications({
    RequestCancelToken? cancelToken,
  }) async =>
      Right(catalog);

  @override
  Future<Either<Failure, List<UserCertification>>> getUserCertifications(
    String userId, {
    RequestCancelToken? cancelToken,
  }) async =>
      Right(enrollments);

  @override
  Future<Either<Failure, CertificationEligibility>> getEligibility(
    String userId,
    int certificationId, {
    RequestCancelToken? cancelToken,
  }) async =>
      eligibility[certificationId] ??
      const Left(ServerFailure(message: 'no eligibility'));

  @override
  Future<Either<Failure, CertificationRequirement>> getRequirement(
    String userId,
    int enrollmentId,
    int requirementId, {
    RequestCancelToken? cancelToken,
  }) async =>
      Right(requirement!);

  @override
  Future<Either<Failure, List<CertificationActivityOption>>> getActivityOptions(
    String userId,
    int enrollmentId,
    int requirementId,
    int componentId, {
    RequestCancelToken? cancelToken,
  }) async =>
      Right(activityOptions);

  @override
  Future<Either<Failure, CertificationRequirement>> saveRequirementDraft(
    String userId,
    int enrollmentId,
    int requirementId,
    List<CertificationComponentDraftInput> responses,
  ) async {
    savedDraft = responses;
    return Right(requirement!);
  }

  @override
  Future<Either<Failure, CertificationRequirementSubmitResult>>
      submitRequirement(
    String userId,
    int enrollmentId,
    int requirementId, {
    required int lockVersion,
  }) async {
    submitCalls++;
    lastLockVersion = lockVersion;
    final error = submitError;
    if (error != null) throw error;
    requirement = CertificationRequirement(
      sectionId: requirement!.sectionId,
      moduleId: requirement!.moduleId,
      name: requirement!.name,
      required: requirement!.required,
      status: CertificationRequirementStatus.submitted,
      submittedAt: DateTime(2026, 3, 10),
      components: requirement!.components,
    );
    return Right(
      CertificationRequirementSubmitResult(
        requirement: requirement!,
        progressSummary: const CertificationProgressSummary(
          requiredTotal: 4,
          requiredApproved: 0,
          optionalTotal: 0,
          optionalApproved: 0,
          percentComplete: 0,
          allRequiredApproved: false,
        ),
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

// ── Sample data ────────────────────────────────────────────────────────────────

const kEnrollmentId = 70;
const kCertificationId = 7;

UserCertification sampleEnrollment({
  CertificationEnrollmentStatus status =
      CertificationEnrollmentStatus.inProgress,
  DateTime? certifiedAt,
}) =>
    UserCertification(
      enrollmentId: kEnrollmentId,
      certificationId: kCertificationId,
      certificationName: 'Instructor de Conquistadores',
      enrollmentDate: DateTime(2026, 2, 1),
      completionStatus: 'in_progress',
      progressPercentage: 25,
      modulesCompleted: 0,
      modulesTotal: 2,
      active: true,
      status: status,
      certifiedAt: certifiedAt,
    );

SectionProgress sampleSection(
  int id,
  String name,
  CertificationRequirementStatus status, {
  bool hasDraft = false,
  String? comment,
  DateTime? reviewedAt,
}) =>
    SectionProgress(
      sectionId: id,
      sectionName: name,
      completed: status == CertificationRequirementStatus.approved,
      status: status,
      hasDraft: hasDraft,
      lastReviewComment: comment,
      reviewedAt: reviewedAt,
    );

/// Two modules, four requirements: one validated, one sent, one sent back
/// and one with a saved draft.
CertificationProgress sampleProgress({
  CertificationEnrollmentStatus status =
      CertificationEnrollmentStatus.inProgress,
  DateTime? certifiedAt,
  String? certificateUrl,
}) =>
    CertificationProgress(
      enrollmentId: kEnrollmentId,
      certificationId: kCertificationId,
      certificationName: 'Instructor de Conquistadores',
      progressPercentage: 25,
      completionStatus: 'in_progress',
      enrollmentDate: DateTime(2026, 2, 1),
      status: status,
      certifiedAt: certifiedAt,
      certificateUrl: certificateUrl,
      modules: [
        ModuleProgress(
          moduleId: 1,
          moduleName: 'Fundamentos',
          sections: [
            sampleSection(
              11,
              'Historia del club',
              CertificationRequirementStatus.approved,
            ),
            sampleSection(
              12,
              'Plan de trabajo',
              CertificationRequirementStatus.submitted,
            ),
          ],
        ),
        ModuleProgress(
          moduleId: 2,
          moduleName: 'Práctica',
          sections: [
            sampleSection(
              21,
              'Informe de actividad',
              CertificationRequirementStatus.changesRequested,
              comment: 'Falta la firma del director',
              reviewedAt: DateTime(2026, 3, 2),
            ),
            sampleSection(
              22,
              'Reflexión final',
              CertificationRequirementStatus.draft,
              hasDraft: true,
            ),
          ],
        ),
      ],
    );

CertificationDetail sampleDetail() => const CertificationDetail(
      certificationId: kCertificationId,
      name: 'Instructor de Conquistadores',
      description: 'Prepara a quienes guían a los Conquistadores. '
          'Cubre la historia del club, la planificación de actividades, '
          'la formación de líderes y la práctica en campo durante un año '
          'completo de servicio supervisado por el Campo Local.',
      active: true,
      modulesCount: 2,
      modules: [
        CertificationModule(
          moduleId: 1,
          name: 'Fundamentos',
          sections: [
            CertificationSection(sectionId: 11, name: 'Historia del club'),
            CertificationSection(sectionId: 12, name: 'Plan de trabajo'),
          ],
        ),
        CertificationModule(
          moduleId: 2,
          name: 'Práctica',
          sections: [
            CertificationSection(sectionId: 21, name: 'Informe de actividad'),
          ],
        ),
      ],
    );

CertificationRequirement sampleRequirement({
  CertificationRequirementStatus status = CertificationRequirementStatus.draft,
  List<CertificationRequirementComponent> components = const [],
  String? comment,
  DateTime? submittedAt,
  DateTime? reviewedAt,
  int? lockVersion,
}) =>
    CertificationRequirement(
      sectionId: 22,
      moduleId: 2,
      name: 'Describe cómo planificas una reunión de club',
      required: true,
      status: status,
      lastReviewComment: comment,
      submittedAt: submittedAt,
      reviewedAt: reviewedAt,
      components: components,
      lockVersion: lockVersion,
    );
