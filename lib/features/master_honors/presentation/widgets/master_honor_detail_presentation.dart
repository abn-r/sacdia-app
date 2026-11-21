import 'package:easy_localization/easy_localization.dart';
import 'package:sacdia_app/core/widgets/badge_grid/sac_badge_tint.dart';
import 'package:sacdia_app/features/master_honors/domain/entities/master_honor_roadmap.dart';

enum MasterHonorGridVisual { awarded, inactive, inProgress, locked }

MasterHonorGridVisual masterHonorGridVisual(MasterHonorRoadmap item) {
  final status = item.status?.toUpperCase();
  if (status == 'REVOKED' ||
      status == 'RETIRED' ||
      (item.isAwarded && !item.isCurrent)) {
    return MasterHonorGridVisual.inactive;
  }
  if (item.isAwarded) return MasterHonorGridVisual.awarded;
  if (item.progressPercent > 0 || item.completedGroups > 0) {
    return MasterHonorGridVisual.inProgress;
  }
  return MasterHonorGridVisual.locked;
}

/// How the patch is drawn: colour when obtained (also when it is no longer
/// valid, it was earned once), dimmed while in progress, grey without
/// progress.
SacBadgeTone masterHonorTone(MasterHonorGridVisual visual) {
  return switch (visual) {
    MasterHonorGridVisual.awarded => SacBadgeTone.color,
    MasterHonorGridVisual.inactive => SacBadgeTone.color,
    MasterHonorGridVisual.inProgress => SacBadgeTone.dimmed,
    MasterHonorGridVisual.locked => SacBadgeTone.muted,
  };
}

final RegExp _masterHonorPrefix = RegExp(
  r"^\s*(?:maestr[ií]a|maestria|mestria|mestrado|master(?:'s)?|mastery|ma[iî]trise)"
  r"\s+(?:(?:en|de|del|in|of|em|do|da|dos|das)\s+|d')",
  caseSensitive: false,
  unicode: true,
);

/// The name without the "Maestría en" / "Master in" / "Maîtrise de" prefix:
/// the title of the screen already says it. The API sends one name per
/// language, so the prefix is matched in every supported language. A name
/// that is only the prefix (or has none) is returned as is.
String masterHonorShortName(String name) {
  final trimmed = name.trim();
  final stripped = trimmed.replaceFirst(_masterHonorPrefix, '').trim();
  if (stripped.isEmpty || stripped == trimmed) return trimmed;
  return '${stripped[0].toUpperCase()}${stripped.substring(1)}';
}

String humanizeMasterHonorLabel(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return value;

  final hasLower = value.contains(RegExp(r'[a-záéíóúüñ]'));
  final hasUpper = value.contains(RegExp(r'[A-ZÁÉÍÓÚÜÑ]'));
  if (hasLower && hasUpper) return value;
  if (!hasLower &&
      hasUpper &&
      value.replaceAll(RegExp(r'\s+'), '').length <= 5) {
    return value;
  }

  return value.split(RegExp(r'\s+')).map((word) {
    if (word.isEmpty) return word;
    final lower = word.toLowerCase();
    return '${lower[0].toUpperCase()}${lower.substring(1)}';
  }).join(' ');
}

String masterHonorRequirementLabel(MasterHonorRoadmapGroup group) {
  final title = group.title?.trim();
  if (title != null && title.isNotEmpty) {
    return humanizeMasterHonorLabel(title);
  }

  final category = group.categoryName?.trim();
  if (category != null && category.isNotEmpty) {
    return humanizeMasterHonorLabel(category);
  }

  return 'master_honors.detail.requirement_fallback'.tr();
}

bool masterHonorShowsRequirementDescription(MasterHonorRoadmapGroup group) {
  final description = group.description?.trim();
  if (description == null || description.isEmpty) return false;

  final title = group.title?.trim();
  final category = group.categoryName?.trim();
  return description != title && description != category;
}

/// Specialties still missing in one requirement group.
int masterHonorGroupMissing(MasterHonorRoadmapGroup group) {
  if (group.passed) return 0;
  final missing = group.minimumRequired - group.currentCount;
  return missing > 0 ? missing : 0;
}

/// Specialties still missing across every requirement group.
int masterHonorMissingCount(MasterHonorRoadmap item) {
  return item.requirementGroups
      .fold<int>(0, (total, group) => total + masterHonorGroupMissing(group));
}

/// Requirement groups already met.
int masterHonorPassedGroups(MasterHonorRoadmap item) =>
    item.requirementGroups.where((group) => group.passed).length;

/// What the grid card counts: specialties done of specialties required
/// ("3 de 7"), over every requirement group. Without groups it falls back to
/// the group totals the API reports.
({int current, int total}) masterHonorProgressCount(MasterHonorRoadmap item) {
  if (item.requirementGroups.isEmpty) {
    return (current: item.completedGroups, total: item.totalGroups);
  }
  var current = 0;
  var total = 0;
  for (final group in item.requirementGroups) {
    final required = group.minimumRequired;
    total += required;
    current += group.currentCount > required ? required : group.currentCount;
  }
  return (current: current, total: total);
}

/// "3 de 7 especialidades": the count of one requirement group.
String masterHonorSpecialtiesCount(MasterHonorRoadmapGroup group) {
  final total = group.minimumRequired;
  return 'master_honors.detail.specialties_count'.plural(
    total,
    namedArgs: {'current': '${group.currentCount}'},
  );
}

/// Title and one line of context for the status panel of the detail sheet.
class MasterHonorStatusCopy {
  const MasterHonorStatusCopy({required this.title, this.message});

  final String title;
  final String? message;

  factory MasterHonorStatusCopy.of(MasterHonorRoadmap item) {
    final missing = masterHonorMissingCount(item);

    switch (masterHonorGridVisual(item)) {
      case MasterHonorGridVisual.awarded:
        return MasterHonorStatusCopy(
          title: 'master_honors.detail.status_obtained'.tr(),
          message: 'master_honors.detail.msg_obtained'.tr(),
        );
      case MasterHonorGridVisual.inactive:
        return MasterHonorStatusCopy(
          title: 'master_honors.detail.status_lapsed'.tr(),
          message: missing > 0
              ? 'master_honors.detail.msg_lapsed'.plural(missing)
              : 'master_honors.detail.msg_lapsed_plain'.tr(),
        );
      case MasterHonorGridVisual.inProgress:
        return MasterHonorStatusCopy(
          title: 'master_honors.detail.status_in_progress'.tr(),
          message: _inProgressMessage(item, missing),
        );
      case MasterHonorGridVisual.locked:
        final requirements = item.totalGroups > 0
            ? item.totalGroups
            : item.requirementGroups.length;
        return MasterHonorStatusCopy(
          title: 'master_honors.detail.status_none'.tr(),
          message: requirements > 0
              ? 'master_honors.detail.msg_none'.plural(requirements)
              : null,
        );
    }
  }

  static String? _inProgressMessage(MasterHonorRoadmap item, int missing) {
    if (missing <= 0) return null;

    final open = item.requirementGroups.where((g) => !g.passed).toList();
    final category = open.length == 1 ? open.first.categoryName?.trim() : null;
    if (category != null && category.isNotEmpty) {
      return 'master_honors.detail.msg_in_progress_category'.plural(
        missing,
        namedArgs: {'category': humanizeMasterHonorLabel(category)},
      );
    }
    return 'master_honors.detail.msg_in_progress'.plural(missing);
  }
}
