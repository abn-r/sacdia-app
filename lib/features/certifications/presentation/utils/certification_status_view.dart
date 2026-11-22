import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/utils/icon_helper.dart';
import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../domain/entities/certification_progress.dart';
import '../../domain/entities/certification_requirement.dart';
import '../../domain/entities/certification_status.dart';
import '../../domain/entities/user_certification.dart';

/// Icon tile of a certification (Mis clases, catalog, header).
const HugeIconData kCertificationIcon = HugeIcons.strokeRoundedCertificate01;

/// The status grammar shared with classes: a requirement of a certification
/// is not sent, sent, validated or sent back.
SacStatusKind certificationRequirementKind(
  CertificationRequirementStatus status,
) {
  switch (status) {
    case CertificationRequirementStatus.draft:
      return SacStatusKind.pending;
    case CertificationRequirementStatus.submitted:
      return SacStatusKind.review;
    case CertificationRequirementStatus.approved:
      return SacStatusKind.validated;
    case CertificationRequirementStatus.changesRequested:
      return SacStatusKind.rejected;
  }
}

String certificationKindLabel(SacStatusKind kind) {
  switch (kind) {
    case SacStatusKind.pending:
      return 'certifications.status.pending'.tr();
    case SacStatusKind.review:
      return 'certifications.status.review'.tr();
    case SacStatusKind.validated:
      return 'certifications.status.validated'.tr();
    case SacStatusKind.rejected:
      return 'certifications.status.rejected'.tr();
  }
}

/// Colors, icon and label of a requirement status: the same as a class
/// requirement (folder, plane, check, alert).
SacStatusStyle certificationRequirementStyle(
  BuildContext context,
  CertificationRequirementStatus status,
) {
  final kind = certificationRequirementKind(status);
  return SacStatusStyle.of(
    context,
    kind,
    label: certificationKindLabel(kind),
  );
}

/// Legend text of the composition bar.
SacStatusCountLabels certificationCountLabels(StatusCounts counts) =>
    SacStatusCountLabels(
      validated: 'certifications.status.legend_validated'.plural(
        counts.validated,
      ),
      review: 'certifications.status.legend_review'.plural(counts.review),
      rejected: 'certifications.status.legend_rejected'.plural(
        counts.rejected,
      ),
      pending: 'certifications.status.legend_pending'.plural(counts.pending),
    );

/// Counts of a list of sections by status.
StatusCounts countSections(Iterable<SectionProgress> sections) {
  var validated = 0, review = 0, rejected = 0, pending = 0;
  for (final s in sections) {
    switch (s.status) {
      case CertificationRequirementStatus.approved:
        validated++;
      case CertificationRequirementStatus.submitted:
        review++;
      case CertificationRequirementStatus.changesRequested:
        rejected++;
      case CertificationRequirementStatus.draft:
        pending++;
    }
  }
  return StatusCounts(
    validated: validated,
    review: review,
    rejected: rejected,
    pending: pending,
  );
}

/// Counts of the whole certification: the server's `summary` when it sends
/// one, otherwise counted from the sections.
StatusCounts countsOfProgress(CertificationProgress progress) {
  final summary = progress.summary;
  if (summary != null && summary.total > 0) {
    return StatusCounts(
      validated: summary.approved,
      review: summary.submitted,
      rejected: summary.changesRequested,
      pending: summary.notStartedOrDraft,
    );
  }
  return countSections([for (final m in progress.modules) ...m.sections]);
}

/// Percentage (0-100) of the certification: what the server says, else
/// validated of total.
int progressPercent(CertificationProgress progress) {
  final counts = countsOfProgress(progress);
  if (progress.progressPercentage > 0) {
    return progress.progressPercentage.round().clamp(0, 100);
  }
  if (counts.total == 0) return 0;
  return (counts.validated * 100 / counts.total).round();
}

/// Group a requirement belongs to on the module screen, in display order.
enum CertificationRequirementGroup { toFix, unsent, sent, validated }

/// The sections of a module split in groups: to fix, not sent, sent,
/// validated. Empty groups are left out.
List<(CertificationRequirementGroup, List<SectionProgress>)>
    groupCertificationSections(List<SectionProgress> sections) {
  List<SectionProgress> where(CertificationRequirementStatus status) => [
        for (final s in sections)
          if (s.status == status) s
      ];
  final groups = <CertificationRequirementGroup, List<SectionProgress>>{
    CertificationRequirementGroup.toFix:
        where(CertificationRequirementStatus.changesRequested),
    CertificationRequirementGroup.unsent:
        where(CertificationRequirementStatus.draft),
    CertificationRequirementGroup.sent:
        where(CertificationRequirementStatus.submitted),
    CertificationRequirementGroup.validated:
        where(CertificationRequirementStatus.approved),
  };
  return [
    for (final e in groups.entries)
      if (e.value.isNotEmpty) (e.key, e.value),
  ];
}

/// A section with the module it belongs to.
typedef SectionInModule = (ModuleProgress, SectionProgress);

/// What «Por atender» lists: first what was sent back, then what was started
/// (a draft) but not sent. Modules keep their order.
List<SectionInModule> attentionSections(List<ModuleProgress> modules) {
  final all = <SectionInModule>[
    for (final m in modules)
      for (final s in m.sections) (m, s),
  ];
  return [
    ...all.where(
      (e) => e.$2.status == CertificationRequirementStatus.changesRequested,
    ),
    ...all.where(
      (e) =>
          e.$2.status == CertificationRequirementStatus.draft && e.$2.hasDraft,
    ),
  ];
}

/// Chip text of an enrollment: «En curso · 2026», «Certificada · 2025»,
/// «Por corregir».
String certificationEnrollmentLabel(UserCertification enrollment) {
  return certificationStatusLabel(
    enrollment.status,
    year: enrollment.status.isCertified
        ? (enrollment.certifiedAt ?? enrollment.enrollmentDate).year
        : enrollment.enrollmentDate.year,
  );
}

String certificationStatusLabel(
  CertificationEnrollmentStatus status, {
  int? year,
}) {
  String withYear(String key) => year == null
      ? '$key.base'.tr()
      : '$key.with_year'.tr(namedArgs: {'year': '$year'});
  switch (status) {
    case CertificationEnrollmentStatus.enrolled:
    case CertificationEnrollmentStatus.inProgress:
      return withYear('certifications.enrollment.in_progress');
    case CertificationEnrollmentStatus.readyForCloseout:
      return 'certifications.enrollment.ready_for_closeout'.tr();
    case CertificationEnrollmentStatus.submittedForFinalReview:
      return 'certifications.enrollment.under_review'.tr();
    case CertificationEnrollmentStatus.approved:
    case CertificationEnrollmentStatus.certified:
      return withYear('certifications.enrollment.certified');
    case CertificationEnrollmentStatus.changesRequested:
      return 'certifications.enrollment.changes_requested'.tr();
    case CertificationEnrollmentStatus.withdrawn:
      return 'certifications.enrollment.withdrawn'.tr();
    case CertificationEnrollmentStatus.expired:
      return 'certifications.enrollment.expired'.tr();
  }
}

/// «8 módulos · 19 requisitos»; the requirements part is left out when the
/// server did not send a total.
String certificationMetaLine({required int modules, int? requirements}) {
  final parts = [
    'certifications.common.modules'.plural(modules),
    if (requirements != null)
      'certifications.common.requirements'.plural(requirements),
  ];
  return parts.join(' · ');
}

/// The enrollment of a certification the person is currently in, if any.
UserCertification? activeEnrollmentFor(
  List<UserCertification> enrollments,
  int certificationId,
) {
  UserCertification? found;
  for (final e in enrollments) {
    if (e.certificationId != certificationId || !e.isEnrolled) continue;
    // A newer or certified enrollment wins over an old one.
    if (found == null || e.status.isCertified && !found.status.isCertified) {
      found = e;
    }
  }
  return found;
}
