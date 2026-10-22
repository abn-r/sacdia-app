import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';

/// Days a pending evidence can wait before it counts as overdue ("Vencida").
///
/// The backend has no evidence-level SLA: `analytics` only flags investiture
/// enrollments older than 30 days, and the retired investiture pipeline is not
/// part of the mobile coordination surface. The app therefore uses a one week
/// review target, which is also the default cadence of the weekly throughput
/// chart. Change it here only.
const int kEvidenceOverdueDays = 7;

/// Days from which a pending evidence starts to need attention (warning tone).
const int kEvidenceWarningDays = 3;

enum EvidenceAgeLevel { fresh, warning, overdue }

/// How long an evidence has been waiting for review, bucketed for the UI.
class EvidenceAge {
  const EvidenceAge({required this.days, required this.level});

  /// Whole days since submission (never negative).
  final int days;
  final EvidenceAgeLevel level;

  factory EvidenceAge.of(DateTime submittedAt, {DateTime? now}) {
    final elapsed = (now ?? DateTime.now()).difference(submittedAt).inDays;
    final days = elapsed < 0 ? 0 : elapsed;
    final level = days >= kEvidenceOverdueDays
        ? EvidenceAgeLevel.overdue
        : days >= kEvidenceWarningDays
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
