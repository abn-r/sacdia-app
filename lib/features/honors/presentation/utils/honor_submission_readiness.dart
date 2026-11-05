import 'package:sacdia_app/core/constants/certificate_dates.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor_requirement.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor_requirement_progress.dart';

/// Where a top-level requirement stands.
enum RequirementStatus { todo, partial, done }

/// Readiness of one top-level requirement (and everything under it).
class RequirementReadiness {
  const RequirementReadiness({
    required this.requirement,
    required this.status,
    required this.isSatisfied,
    required this.childTotal,
    required this.childRequired,
    required this.childSatisfied,
    required this.ownCompleted,
    required this.ownEvidenceCount,
    required this.missingEvidenceIds,
    required this.fraction,
  });

  final HonorRequirement requirement;
  final RequirementStatus status;

  /// The backend's "satisfied" for this node (evidence not included).
  final bool isSatisfied;

  /// Direct children of the requirement (0 for a leaf).
  final int childTotal;

  /// How many direct children must be satisfied: `choice_min` for a choice
  /// group, all of them for a plain parent, 0 for a leaf.
  final int childRequired;

  /// Direct children that are satisfied right now.
  final int childSatisfied;

  /// The requirement's own progress row is ticked.
  final bool ownCompleted;

  /// Evidence files attached to the requirement itself.
  final int ownEvidenceCount;

  /// Requirements under this one that need evidence the backend would not
  /// find (only counted on the path the backend would validate).
  final List<int> missingEvidenceIds;

  /// 0..1 credit toward the honor: 1 only when [status] is done.
  final double fraction;

  bool get isChoiceGroup => requirement.isChoiceGroup;
  bool get isLeaf => childTotal == 0;
  bool get hasMissingEvidence => missingEvidenceIds.isNotEmpty;
}

/// Everything the screen needs to know before offering "Enviar a revisión".
class HonorSubmissionReadiness {
  const HonorSubmissionReadiness({
    required this.items,
    required this.hasCompletionDate,
    required this.isInApp,
    required this.missingEvidenceIds,
  });

  /// One entry per top-level requirement, in catalog order.
  final List<RequirementReadiness> items;

  /// The member picked a completion date inside the accepted range.
  final bool hasCompletionDate;

  /// The honor is worked inside the app (the only mode with a checklist).
  final bool isInApp;

  /// Evidence the backend would find missing, across the whole honor.
  final List<int> missingEvidenceIds;

  int get totalCount => items.length;

  /// Top-level requirements the backend counts as satisfied.
  int get satisfiedCount => items.where((i) => i.isSatisfied).length;

  /// Top-level requirements fully done: satisfied and with their evidence.
  int get doneCount =>
      items.where((i) => i.status == RequirementStatus.done).length;

  /// Top-level requirements still not satisfied.
  int get unsatisfiedCount => totalCount - satisfiedCount;

  int get missingEvidenceCount => missingEvidenceIds.length;

  bool get allRequirementsSatisfied => unsatisfiedCount == 0;

  /// 0..1 progress shown in the band. Reaches 1 only when every top-level
  /// requirement is done (partial credit never reaches a full unit).
  double get fraction {
    if (items.isEmpty) return 0;
    final sum = items.fold<double>(0, (acc, i) => acc + i.fraction);
    return (sum / items.length).clamp(0.0, 1.0);
  }

  /// Mirrors `submitForReview` for IN_APP honors (see the cited backend
  /// lines on [computeHonorSubmissionReadiness]).
  bool get canSubmit =>
      isInApp &&
      allRequirementsSatisfied &&
      missingEvidenceIds.isEmpty &&
      hasCompletionDate;
}

class _Eval {
  const _Eval({required this.satisfied, required this.evidenceIds});

  final bool satisfied;
  final List<int> evidenceIds;
}

/// Decides how ready an in-app honor is to be sent for review.
///
/// This is a Dart copy of the backend rules; keep both in sync.
///
/// Backend source: `sacdia-backend/src/honors/honor-validation-workflow.service.ts`
///  - `submitForReview` L75-L142, `assertSubmitEligibility` L286-L313:
///    the mode must be IN_APP, then the date is checked.
///  - `assertInAppSubmitEligibility` L333-L362: requirements must be
///    satisfied, then every evidence id of the selected path must have an
///    active evidence file.
///  - `evaluateInAppRequirementCompletion` L402-L476 (empty honor: L423): only progress rows
///    with `completed = true` count; a honor with no requirements is
///    satisfied; the top level is satisfied when every top-level node is.
///  - `evaluateRequirementNode` L501-L561: a choice group WITH sub-items goes
///    to `evaluateChoiceGroup` (one without them is a plain leaf); a parent is satisfied when ALL its children are
///    (its own tick is ignored); a leaf is satisfied when its own row is
///    ticked. A satisfied node with `requires_evidence` asks for evidence.
///  - `evaluateChoiceGroup` L563-L610: needs `max(choice_min ?? 1, 0)`
///    satisfied children (0 means satisfied with no children evaluated);
///    only the FIRST `min` satisfied children (by requirement number) ask
///    for evidence, plus the group itself when it `requires_evidence`.
///  - `assertCompletedAt` L320-L331: the date is required only while
///    `REQUIRE_HONOR_COMPLETED_AT_ON_SUBMIT` (L27) is true; today it is
///    false. The app already demands it, so [requireCompletionDate] defaults
///    to true (strictest reading). When present the date must be in range.
///
/// Not mirrored (the client lacks the data): a REJECTED honor cannot be
/// resent until it changes (`modified_at <= validated_at`, L303-L311); the
/// server answers `VALIDATION_HONOR_NO_CHANGES_AFTER_REJECTION`.
///
/// [now] is injectable for the date range rule.
HonorSubmissionReadiness computeHonorSubmissionReadiness({
  required List<HonorRequirement> requirements,
  required List<UserHonorRequirementProgress> progress,
  required DateTime? completedAt,
  required HonorCompletionMode mode,
  bool requireCompletionDate = true,
  DateTime? now,
}) {
  final progressById = {for (final p in progress) p.requirementId: p};
  final completedIds = <int>{
    for (final p in progress)
      if (p.completed) p.requirementId,
  };
  // Backend: completed rows that have at least one active evidence file.
  final withEvidenceIds = <int>{
    for (final p in progress)
      if (p.completed && p.evidences.isNotEmpty) p.requirementId,
  };

  List<HonorRequirement> ordered(List<HonorRequirement> list) {
    final copy = [...list];
    copy.sort((a, b) => a.requirementNumber.compareTo(b.requirementNumber));
    return copy;
  }

  _Eval evaluate(HonorRequirement node) {
    final children = ordered(node.children);

    // A "choose N" group with no sub-items is a catalog mistake: the
    // backend treats it as a plain requirement (`evaluateRequirementNode`),
    // completed by its own row.
    if (node.isChoiceGroup && children.isNotEmpty) {
      final minimum = _choiceMinimum(node);
      if (minimum == 0) {
        return _Eval(
          satisfied: true,
          evidenceIds: node.requiresEvidence ? [node.id] : const [],
        );
      }
      final satisfiedChildren =
          children.map(evaluate).where((e) => e.satisfied).toList();
      if (satisfiedChildren.length < minimum) {
        return const _Eval(satisfied: false, evidenceIds: []);
      }
      final selected = satisfiedChildren.take(minimum);
      return _Eval(
        satisfied: true,
        evidenceIds: [
          for (final e in selected) ...e.evidenceIds,
          if (node.requiresEvidence) node.id,
        ],
      );
    }

    if (children.isNotEmpty) {
      final evals = children.map(evaluate).toList();
      final satisfied = evals.every((e) => e.satisfied);
      return _Eval(
        satisfied: satisfied,
        evidenceIds: satisfied
            ? [
                for (final e in evals) ...e.evidenceIds,
                if (node.requiresEvidence) node.id,
              ]
            : const [],
      );
    }

    final satisfied = completedIds.contains(node.id);
    return _Eval(
      satisfied: satisfied,
      evidenceIds: satisfied && node.requiresEvidence ? [node.id] : const [],
    );
  }

  bool anyCompletedInSubtree(HonorRequirement node) {
    if (completedIds.contains(node.id)) return true;
    return node.children.any(anyCompletedInSubtree);
  }

  final items = <RequirementReadiness>[];
  final missingAll = <int>{};

  for (final node in ordered(requirements)) {
    final result = evaluate(node);
    final missing = result.satisfied
        ? [
            for (final id in result.evidenceIds.toSet())
              if (!withEvidenceIds.contains(id)) id,
          ]
        : const <int>[];
    missingAll.addAll(missing);

    final children = ordered(node.children);
    final childEvals = children.map(evaluate).toList();
    final childSatisfied = childEvals.where((e) => e.satisfied).length;
    final childRequired = children.isEmpty
        ? 0
        : node.isChoiceGroup
            ? _choiceMinimum(node)
            : children.length;

    final isDone = result.satisfied && missing.isEmpty;
    final status = isDone
        ? RequirementStatus.done
        : (result.satisfied ||
                childSatisfied > 0 ||
                anyCompletedInSubtree(node))
            ? RequirementStatus.partial
            : RequirementStatus.todo;

    items.add(
      RequirementReadiness(
        requirement: node,
        status: status,
        isSatisfied: result.satisfied,
        childTotal: children.length,
        childRequired: childRequired,
        childSatisfied: childSatisfied,
        ownCompleted: completedIds.contains(node.id),
        ownEvidenceCount: progressById[node.id]?.evidences.length ?? 0,
        missingEvidenceIds: missing,
        fraction: _fraction(
          isDone: isDone,
          isSatisfied: result.satisfied,
          childSatisfied: childSatisfied,
          childRequired: childRequired,
        ),
      ),
    );
  }

  final dateOk = completedAt != null &&
      CertificateDateRule.check(completedAt, now: now) == null;

  return HonorSubmissionReadiness(
    items: List.unmodifiable(items),
    hasCompletionDate:
        requireCompletionDate ? dateOk : (completedAt == null || dateOk),
    isInApp: mode == HonorCompletionMode.inApp,
    missingEvidenceIds: List.unmodifiable(missingAll.toList()..sort()),
  );
}

/// `max(choice_min ?? 1, 0)` — backend L569.
int _choiceMinimum(HonorRequirement node) {
  final min = node.choiceMin ?? 1;
  return min < 0 ? 0 : min;
}

double _fraction({
  required bool isDone,
  required bool isSatisfied,
  required int childSatisfied,
  required int childRequired,
}) {
  if (isDone) return 1;
  // Satisfied but short of evidence: half credit.
  if (isSatisfied) return 0.5;
  if (childRequired <= 0) return 0;
  return (childSatisfied / childRequired).clamp(0.0, 0.99);
}

/// What an EXTERNAL honor still needs before "Enviar a revisión".
///
/// Three checks, each worth a third of the band ring: the completed format,
/// at least one general evidence and the completion date.
class ExternalSubmissionReadiness {
  const ExternalSubmissionReadiness({
    required this.isExternal,
    required this.hasFormat,
    required this.hasGeneralEvidence,
    required this.hasCompletionDate,
  });

  /// The honor is worked outside the app (the only mode with this path).
  final bool isExternal;

  /// The completed format PDF is uploaded.
  final bool hasFormat;

  /// At least one general evidence file is uploaded.
  final bool hasGeneralEvidence;

  /// The member picked a completion date inside the accepted range.
  final bool hasCompletionDate;

  static const int totalCount = 3;

  int get doneCount => [hasFormat, hasGeneralEvidence, hasCompletionDate]
      .where((done) => done)
      .length;

  /// 0..1 progress shown in the band.
  double get fraction => doneCount / totalCount;

  /// Mirrors `submitForReview` for EXTERNAL honors (see the cited backend
  /// lines on [computeExternalSubmissionReadiness]).
  bool get canSubmit =>
      isExternal && hasFormat && hasGeneralEvidence && hasCompletionDate;
}

/// Decides how ready an external honor is to be sent for review.
///
/// This is a Dart copy of the backend rules; keep both in sync.
///
/// Backend source: `sacdia-backend/src/honors/honor-validation-workflow.service.ts`
///  - `assertSubmitEligibility` L286-L312: the mode must be EXTERNAL (L291),
///    then the date (L301) is checked.
///  - `assertExternalSubmitEligibility` L361-L379: the completed format
///    (L367) and at least one general evidence (L373) are both required;
///    either one missing answers `VALIDATION_HONOR_MISSING_EVIDENCE`.
///  - `hasCompletedExternalFormat` L381-L385: `document` is a non-empty
///    string.
///  - `hasExternalGeneralEvidence` L387-L400: `images` has an entry, or the
///    honor has an active `evidence_files` row. The client only sees
///    `images`, which is the same list.
///  - `assertCompletedAt` L320-L331: the date is required only while
///    `REQUIRE_HONOR_COMPLETED_AT_ON_SUBMIT` (L27) is true; today it is
///    false. The app already demands it, so [requireCompletionDate] defaults
///    to true (strictest reading). When present the date must be in range.
///
/// Not mirrored (the client lacks the data): a REJECTED honor cannot be
/// resent until it changes (`modified_at <= validated_at`, L303-L311); the
/// server answers `VALIDATION_HONOR_NO_CHANGES_AFTER_REJECTION`.
///
/// [now] is injectable for the date range rule.
ExternalSubmissionReadiness computeExternalSubmissionReadiness({
  required UserHonor userHonor,
  bool requireCompletionDate = true,
  DateTime? now,
}) {
  final completedAt = userHonor.completedAt;
  final dateOk = completedAt != null &&
      CertificateDateRule.check(completedAt, now: now) == null;

  return ExternalSubmissionReadiness(
    isExternal: userHonor.completionMode == HonorCompletionMode.external,
    hasFormat: userHonor.hasCompletedFormat,
    hasGeneralEvidence: userHonor.hasGeneralEvidence,
    hasCompletionDate:
        requireCompletionDate ? dateOk : (completedAt == null || dateOk),
  );
}

/// Progress updates that keep the evidence-carrying parents in step with
/// their children, under [roots].
///
/// The backend counts a requirement's evidence only on a completed row, and
/// a parent's own row is never ticked by hand any more: a parent that
/// `requires_evidence` is sent as completed exactly when its children satisfy
/// it (all of them, or `choice_min` of a choice group). Pass the progress as
/// it will be after the pending edits.
List<Map<String, dynamic>> evidenceParentUpdates({
  required List<HonorRequirement> roots,
  required List<UserHonorRequirementProgress> progress,
}) {
  final byId = {for (final p in progress) p.requirementId: p};
  final updates = <Map<String, dynamic>>[];

  void visit(HonorRequirement node) {
    if (node.children.isEmpty) return;
    node.children.forEach(visit);
    if (!node.requiresEvidence) return;
    final satisfied = computeHonorSubmissionReadiness(
      requirements: [node],
      progress: progress,
      completedAt: null,
      mode: HonorCompletionMode.inApp,
      requireCompletionDate: false,
    ).items.single.isSatisfied;
    final row = byId[node.id];
    if (satisfied == (row?.completed ?? false)) return;
    updates.add({
      'requirementId': node.id,
      'completed': satisfied,
      'notes': row?.notes ?? '',
      'textResponse': row?.textResponse ?? '',
    });
  }

  roots.forEach(visit);
  return updates;
}
