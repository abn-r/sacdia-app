import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';

import '../../data/models/club_section_model.dart';
import '../providers/club_selection_providers.dart';

/// Widget para mostrar el selector de tipo de club con recomendación por edad
class ClubTypeSelector extends ConsumerWidget {
  const ClubTypeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubSectionsAsync = ref.watch(clubSectionsProvider);
    final selectedSectionId = ref.watch(selectedClubSectionProvider);
    final userAge = ref.watch(userAgeProvider);

    return clubSectionsAsync.when(
      data: (sections) {
        if (sections.isEmpty) {
          // Caso edge: el club existe pero no tiene instancias activas
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.accentLight,
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedAlertCircle,
                  color: AppColors.accentDark,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'post_registration.club_type.no_instances'.tr(),
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.accentDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'post_registration.club_type.label'.tr(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),

            // Mensaje de recomendación por edad
            if (userAge != null) _buildAgeRecommendation(context, userAge),

            const SizedBox(height: 12),

            // Opciones de tipo de club
            ...sections.map((section) {
              final isSelected = selectedSectionId == section.id;
              final isRecommended = _isRecommendedForAge(section, userAge);

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () {
                    // Actualizar instancia seleccionada
                    // (selectedClubTypeSlugProvider se deriva automáticamente)
                    ref.read(selectedClubSectionProvider.notifier).state =
                        section.id;
                    // Limpiar clase al cambiar tipo de club
                    ref.read(selectedClassProvider.notifier).state = null;
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : context.sac.border,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: isSelected ? AppColors.primaryLight : null,
                    ),
                    child: Row(
                      children: [
                        HugeIcon(
                          icon: isSelected
                              ? HugeIcons.strokeRoundedCheckmarkCircle02
                              : HugeIcons.strokeRoundedRadioButton,
                          color: isSelected
                              ? AppColors.primary
                              : context.sac.textTertiary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            section.displayName,
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                          ),
                        ),
                        if (isRecommended)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.secondaryLight,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'post_registration.club_type.recommended'.tr(),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.secondaryDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
      loading: () => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: const SacLoading(),
        ),
      ),
      error: (error, stack) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'post_registration.club_type.error_loading'
              .tr(namedArgs: {'error': error.toString()}),
          style: TextStyle(color: AppColors.error),
        ),
      ),
    );
  }

  Widget _buildAgeRecommendation(BuildContext context, int age) {
    String recommendation = '';
    dynamic icon = HugeIcons.strokeRoundedInformationCircle;
    Color color = AppColors.primary;

    if (age >= 4 && age <= 9) {
      recommendation = 'post_registration.club_type.for_age_adventurers'
          .tr(namedArgs: {'age': age.toString()});
      icon = HugeIcons.strokeRoundedBaby01;
      color = AppColors.accent;
    } else if (age >= 10 && age <= 15) {
      recommendation = 'post_registration.club_type.for_age_pathfinders'
          .tr(namedArgs: {'age': age.toString()});
      icon = HugeIcons.strokeRoundedCompass01;
      color = AppColors.primary;
    } else if (age >= 16) {
      recommendation = 'post_registration.club_type.for_age_master_guild'
          .tr(namedArgs: {'age': age.toString()});
      icon = HugeIcons.strokeRoundedUserGroup;
      color = AppColors.secondary;
    }

    if (recommendation.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          buildIcon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              recommendation,
              style: TextStyle(
                fontSize: 13,
                color: color.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isRecommendedForAge(ClubSectionModel section, int? age) {
    if (age == null) return false;

    if (section.clubTypeSlug == 'adventurers' ||
        (section.clubTypeName?.toLowerCase().contains('aventurero') ??
            false)) {
      return age >= 4 && age <= 9;
    } else if (section.clubTypeSlug == 'pathfinders' ||
        (section.clubTypeName?.toLowerCase().contains('conquistador') ??
            false)) {
      return age >= 10 && age <= 15;
    } else if (section.clubTypeSlug == 'master_guild' ||
        (section.clubTypeName?.toLowerCase().contains('guía') ?? false)) {
      return age >= 16;
    }

    return false;
  }
}
