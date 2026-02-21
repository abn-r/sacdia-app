import 'package:flutter/material.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';

import '../../data/models/club_instance_model.dart';
import '../providers/club_selection_providers.dart';

/// Widget para mostrar el selector de tipo de club con recomendación por edad
class ClubTypeSelector extends ConsumerWidget {
  const ClubTypeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubInstancesAsync = ref.watch(clubInstancesProvider);
    final selectedInstanceId = ref.watch(selectedClubInstanceProvider);
    final userAge = ref.watch(userAgeProvider);

    return clubInstancesAsync.when(
      data: (instances) {
        if (instances.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tipo de Club',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),

            // Mensaje de recomendación por edad
            if (userAge != null) _buildAgeRecommendation(context, userAge),

            const SizedBox(height: 12),

            // Opciones de tipo de club
            ...instances.map((instance) {
              final isSelected = selectedInstanceId == instance.id;
              final isRecommended = _isRecommendedForAge(instance, userAge);

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () {
                    ref.read(selectedClubInstanceProvider.notifier).state = instance.id;
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.lightBorder,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: isSelected
                          ? AppColors.primaryLight
                          : null,
                    ),
                    child: Row(
                      children: [
                        HugeIcon(
                          icon: isSelected
                              ? HugeIcons.strokeRoundedCheckmarkCircle02
                              : HugeIcons.strokeRoundedRadioButton,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.lightTextTertiary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            instance.clubTypeName ?? instance.clubTypeSlug,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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
                              'Recomendado',
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
          'Error al cargar tipos de club: $error',
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
      recommendation = 'Para tu edad ($age años), recomendamos el club de Aventureros.';
      icon = HugeIcons.strokeRoundedBaby01;
      color = AppColors.accent;
    } else if (age >= 10 && age <= 15) {
      recommendation = 'Para tu edad ($age años), recomendamos el club de Conquistadores.';
      icon = HugeIcons.strokeRoundedCompass01;
      color = AppColors.primary;
    } else if (age >= 16) {
      recommendation = 'Para tu edad ($age años), recomendamos el club de Guías Mayores.';
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

  bool _isRecommendedForAge(ClubInstanceModel instance, int? age) {
    if (age == null) return false;

    if (instance.clubTypeSlug == 'adventurers' ||
        (instance.clubTypeName?.toLowerCase().contains('aventurero') ?? false)) {
      return age >= 4 && age <= 9;
    } else if (instance.clubTypeSlug == 'pathfinders' ||
        (instance.clubTypeName?.toLowerCase().contains('conquistador') ??
            false)) {
      return age >= 10 && age <= 15;
    } else if (instance.clubTypeSlug == 'master_guild' ||
        (instance.clubTypeName?.toLowerCase().contains('guía') ?? false)) {
      return age >= 16;
    }

    return false;
  }
}
