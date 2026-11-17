import '../../domain/entities/class_requirement.dart';
import '../../domain/entities/class_progress_summary.dart';

/// Where a requirement of a member goes in the coach's list.
enum MemberRequirementGroup { attention, review, validated }

extension MemberRequirementGroupX on RequirementStatus {
  MemberRequirementGroup get coachGroup {
    switch (this) {
      case RequirementStatus.rechazado:
      case RequirementStatus.observado:
      case RequirementStatus.pendiente:
        return MemberRequirementGroup.attention;
      case RequirementStatus.enviado:
        return MemberRequirementGroup.review;
      case RequirementStatus.validado:
        return MemberRequirementGroup.validated;
    }
  }
}

/// Requirements split in the three groups of the coach's list, in this
/// order: what needs attention (sent back first, then not sent), what waits
/// for the local field, and what is validated. Empty groups are left out.
List<(MemberRequirementGroup, List<ClassRequirement>)> groupRequirements(
  List<ClassRequirement> requirements,
) {
  bool isSentBack(ClassRequirement r) =>
      r.status == RequirementStatus.rechazado ||
      r.status == RequirementStatus.observado;

  final attention = [
    ...requirements.where(isSentBack),
    ...requirements.where((r) => r.status == RequirementStatus.pendiente),
  ];
  final review =
      requirements.where((r) => r.status == RequirementStatus.enviado).toList();
  final validated = requirements
      .where((r) => r.status == RequirementStatus.validado)
      .toList();

  return [
    if (attention.isNotEmpty) (MemberRequirementGroup.attention, attention),
    if (review.isNotEmpty) (MemberRequirementGroup.review, review),
    if (validated.isNotEmpty) (MemberRequirementGroup.validated, validated),
  ];
}

/// Counts of [requirements] by status. Sent back (rejected or observed)
/// counts as "to fix".
RequirementStatusCounts countRequirements(List<ClassRequirement> requirements) {
  int count(bool Function(RequirementStatus) test) =>
      requirements.where((r) => test(r.status)).length;
  return RequirementStatusCounts(
    validated: count((s) => s == RequirementStatus.validado),
    submitted: count((s) => s == RequirementStatus.enviado),
    rejected: count(
      (s) =>
          s == RequirementStatus.rechazado || s == RequirementStatus.observado,
    ),
    pending: count((s) => s == RequirementStatus.pendiente),
  );
}
