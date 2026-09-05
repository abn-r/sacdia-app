import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
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

class MasterHonorDetailStatus {
  const MasterHonorDetailStatus({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  factory MasterHonorDetailStatus.of(MasterHonorRoadmap item) {
    final visual = masterHonorGridVisual(item);
    switch (visual) {
      case MasterHonorGridVisual.awarded:
        return MasterHonorDetailStatus(
          label: item.displayStatusLabel?.trim().isNotEmpty == true
              ? item.displayStatusLabel!.trim()
              : 'Obtenida',
          background: AppColors.validatedBg,
          foreground: AppColors.validatedDark,
        );
      case MasterHonorGridVisual.inactive:
        return MasterHonorDetailStatus(
          label: item.displayStatusLabel?.trim().isNotEmpty == true
              ? item.displayStatusLabel!.trim()
              : 'No vigente',
          background: AppColors.pendingBg,
          foreground: AppColors.pendingDark,
        );
      case MasterHonorGridVisual.inProgress:
        return const MasterHonorDetailStatus(
          label: 'En progreso',
          background: AppColors.observedBg,
          foreground: AppColors.observedDark,
        );
      case MasterHonorGridVisual.locked:
        return const MasterHonorDetailStatus(
          label: 'Sin avance',
          background: AppColors.pendingBg,
          foreground: AppColors.pendingDark,
        );
    }
  }
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

  return 'Requisito de maestría';
}

bool masterHonorShowsRequirementDescription(MasterHonorRoadmapGroup group) {
  final description = group.description?.trim();
  if (description == null || description.isEmpty) return false;

  final title = group.title?.trim();
  final category = group.categoryName?.trim();
  return description != title && description != category;
}

double masterHonorGroupProgress(MasterHonorRoadmap item) {
  if (item.totalGroups <= 0) return 0;
  return (item.completedGroups / item.totalGroups).clamp(0.0, 1.0);
}

Color masterHonorDetailAccent(MasterHonorRoadmap item) {
  switch (masterHonorGridVisual(item)) {
    case MasterHonorGridVisual.awarded:
      return AppColors.secondary;
    case MasterHonorGridVisual.inProgress:
      return AppColors.accent;
    case MasterHonorGridVisual.inactive:
      return AppColors.pendingDark;
    case MasterHonorGridVisual.locked:
      // Gris neutro legible en ambos modos (misma familia que pendingDark).
      return AppColors.pendingDark.withValues(alpha: 0.7);
  }
}

bool masterHonorShowsPercentCaption(MasterHonorRoadmap item) {
  if (item.totalGroups <= 0) return false;
  if (masterHonorGridVisual(item) != MasterHonorGridVisual.inProgress) {
    return false;
  }

  final fromGroups = ((item.completedGroups / item.totalGroups) * 100).round();
  return item.progressPercent.clamp(0, 100) != fromGroups;
}

String masterHonorProgressCaption(MasterHonorRoadmap item) {
  if (item.totalGroups <= 0) {
    return 'Aún no hay requisitos configurados.';
  }
  return '${item.completedGroups} de ${item.totalGroups} requisitos';
}

String masterHonorPercentCaption(MasterHonorRoadmap item) {
  return '${item.progressPercent.clamp(0, 100)}% del total';
}

const int kMasterHonorCollapsedOptionThreshold = 3;

bool masterHonorCollapsesIncompleteOptions(MasterHonorRoadmapGroup group) {
  final incompleteCount =
      group.options.where((option) => !option.completed).length;
  return incompleteCount > kMasterHonorCollapsedOptionThreshold;
}
