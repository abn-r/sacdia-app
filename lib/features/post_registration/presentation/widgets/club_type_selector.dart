import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/club_type.dart';
import '../../data/models/club_section_model.dart';

import '../providers/club_selection_providers.dart';
import 'bottom_sheet_picker.dart';

/// Selector de tipo de club.
///
/// La selección inicial se deriva automáticamente por edad en
/// [selectedClubSectionProvider]; este widget sólo presenta el valor resultante
/// y permite cambiarlo desde un bottom sheet, igual que los demás pickers.
class ClubTypeSelector extends ConsumerWidget {
  const ClubTypeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubSectionsAsync = ref.watch(clubSectionsProvider);
    final selectedSectionId = ref.watch(selectedClubSectionProvider);

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

        final selectedName = sections
            .where((section) => section.id == selectedSectionId)
            .map((section) => section.displayName)
            .firstOrNull;
        final selectedLogoAsset = sections
            .where((section) => section.id == selectedSectionId)
            .map(_clubTypeLogoAsset)
            .firstOrNull;
        final items = sections
            .map(
              (section) => PickerItem(
                id: section.id,
                name: section.displayName,
                logoAsset: _clubTypeLogoAsset(section),
              ),
            )
            .toList();
        final label = 'post_registration.club_type.label'.tr();

        return PickerField(
          label: label,
          hint: 'post_registration.dropdown.select_label'
              .tr(namedArgs: {'label': label.toLowerCase()}),
          icon: HugeIcons.strokeRoundedUserGroup,
          selectedLogoAsset: selectedLogoAsset,
          selectedName: selectedName,
          onTap: () async {
            final picked = await showPickerSheet(
              context: context,
              title: label,
              items: items,
              selectedId: selectedSectionId,
              icon: HugeIcons.strokeRoundedUserGroup,
            );

            if (picked != null && picked != selectedSectionId) {
              ref.read(selectedClubSectionProvider.notifier).state = picked;
              ref.read(selectedClassProvider.notifier).state = null;
            }
          },
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
}

String? _clubTypeLogoAsset(ClubSectionModel section) {
  switch (section.clubTypeSlug) {
    case 'adventurers':
      return ClubType.aventureros.logoAsset;
    case 'pathfinders':
      return ClubType.conquistadores.logoAsset;
    case 'master_guild':
    case 'master_guilds':
      return ClubType.guiasMayores.logoAsset;
  }

  return clubLogoAssetFromName(section.displayName);
}
