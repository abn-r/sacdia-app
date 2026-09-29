import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/club_type.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_filter_chip.dart';
import 'package:sacdia_app/features/materials/domain/entities/material_program.dart';

/// Club-type filter. Caption names the axis; chips are the clubs.
class MaterialsProgramField extends StatelessWidget {
  const MaterialsProgramField({
    super.key,
    required this.programs,
    required this.selectedId,
    required this.onSelected,
  });

  final List<MaterialProgram> programs;
  final int? selectedId;
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Semantics(
            header: true,
            child: Text(
              'materials.catalog.filter_program_label'.tr(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.textSecondary,
              ),
            ),
          ),
        ),
        SizedBox(
          height: SacFilterChip.barHeight,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 28, 0),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: SacFilterChip(
                  label: 'materials.catalog.filter_program_all'.tr(),
                  variant: SacFilterChipVariant.quiet,
                  selected: selectedId == null,
                  onTap: () => onSelected(null),
                ),
              ),
              ...programs.map(
                (program) {
                  final club = clubTypeFromName(program.label);
                  final badge = club == null
                      ? null
                      : clubBadgeColorsFromName(program.label);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: SacFilterChip(
                      label: program.label,
                      variant: SacFilterChipVariant.quiet,
                      selected: selectedId == program.id,
                      logoAsset: club?.logoAsset,
                      accentBackground: badge?.$1,
                      accentForeground: badge?.$2,
                      onTap: () => onSelected(program.id),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
