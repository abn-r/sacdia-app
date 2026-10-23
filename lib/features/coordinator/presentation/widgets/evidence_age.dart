import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';

/// Fallback for the days a pending evidence can wait before it counts as
/// overdue ("Vencida").
///
/// The real threshold comes from the SLA dashboard
/// (`evidence.overdue_threshold_days`, see `evidenceOverdueDaysProvider`) so
/// the queue badges and the hub's "Vencidas" count use the same rule. This
/// value only applies until that response arrives, or with an older backend
/// that does not send it. Keep it equal to the backend default
/// (`EVIDENCE_REVIEW_OVERDUE_DAYS`).
const int kEvidenceOverdueDays = 7;

/// Days from which a pending evidence starts to need attention (warning tone).
/// Never reaches the overdue threshold: see [EvidenceAge.of].
const int kEvidenceWarningDays = 3;

enum EvidenceAgeLevel { fresh, warning, overdue }

/// How long an evidence has been waiting for review, bucketed for the UI.
class EvidenceAge {
  const EvidenceAge({required this.days, required this.level});

  /// Whole days since submission (never negative).
  final int days;
  final EvidenceAgeLevel level;

  /// [overdueDays] is the overdue threshold (from the backend when known).
  /// The warning band starts at [kEvidenceWarningDays], or earlier when the
  /// threshold is that low, so warning always comes before overdue.
  factory EvidenceAge.of(
    DateTime submittedAt, {
    DateTime? now,
    int overdueDays = kEvidenceOverdueDays,
  }) {
    final elapsed = (now ?? DateTime.now()).difference(submittedAt).inDays;
    final days = elapsed < 0 ? 0 : elapsed;
    final overdueAt = overdueDays < 1 ? kEvidenceOverdueDays : overdueDays;
    final warningAt = overdueAt > kEvidenceWarningDays
        ? kEvidenceWarningDays
        : (overdueAt - 1).clamp(1, overdueAt);
    final level = days >= overdueAt
        ? EvidenceAgeLevel.overdue
        : days >= warningAt
            ? EvidenceAgeLevel.warning
            : EvidenceAgeLevel.fresh;
    return EvidenceAge(days: days, level: level);
  }

  bool get isOverdue => level == EvidenceAgeLevel.overdue;

  /// "Hoy", "Hace 2 d" or "Vencida · 9 d".
  String get label {
    final args = {'days': '$days'};
    if (isOverdue) {
      return 'coordinator.evidence_review.card.age_overdue'.tr(namedArgs: args);
    }
    if (days == 0) return 'coordinator.evidence_review.card.age_today'.tr();
    return 'coordinator.evidence_review.card.age_days'.tr(namedArgs: args);
  }
}

/// [SacBadge] for an [EvidenceAge]: error when overdue, warning when it is
/// getting old, neutral otherwise.
class EvidenceAgeBadge extends StatelessWidget {
  const EvidenceAgeBadge({super.key, required this.age});

  final EvidenceAge age;

  @override
  Widget build(BuildContext context) {
    final label = age.label;
    switch (age.level) {
      case EvidenceAgeLevel.overdue:
        return SacBadge.error(
          icon: HugeIcons.strokeRoundedAlert02,
          label: label,
        );
      case EvidenceAgeLevel.warning:
        return SacBadge.warning(label: label);
      case EvidenceAgeLevel.fresh:
        return SacBadge(
          variant: SacBadgeVariant.neutral,
          icon: HugeIcons.strokeRoundedClock01,
          label: label,
        );
    }
  }
}
