import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';

/// Género soportado por el backend (`gender` en `UpdateUserDto`).
///
/// - [display] es el label visible al usuario.
/// - [apiKey] es el valor que el backend espera en `PATCH /users/:id`
///   con campo `gender` (validado por `@IsIn(['M', 'F'])`).
enum Gender {
  male('M'),
  female('F');

  const Gender(this.apiKey);

  final String apiKey;

  String display(BuildContext context) {
    switch (this) {
      case Gender.male:
        return 'profile.edit.gender_male'.tr();
      case Gender.female:
        return 'profile.edit.gender_female'.tr();
    }
  }

  HugeIconData get icon {
    switch (this) {
      case Gender.male:
        return HugeIcons.strokeRoundedMale02;
      case Gender.female:
        return HugeIcons.strokeRoundedFemale02;
    }
  }

  static Gender? fromApiKey(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final g in Gender.values) {
      if (g.apiKey == value) return g;
    }
    return null;
  }
}

/// Bottomsheet para seleccionar género.
///
/// Devuelve el [Gender] seleccionado, o `null` si el usuario cancela.
Future<Gender?> showGenderSelector(
  BuildContext context, {
  Gender? current,
}) {
  return showModalBottomSheet<Gender>(
    context: context,
    isScrollControlled: false,
    showDragHandle: true,
    builder: (ctx) => _GenderSheet(current: current),
  );
}

class _GenderSheet extends StatelessWidget {
  const _GenderSheet({this.current});

  final Gender? current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'profile.edit.gender_select_title'.tr(),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'profile.edit.gender_select_subtitle'.tr(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: Gender.values
                  .map(
                    (g) => _GenderChip(
                      gender: g,
                      selected: current == g,
                      onTap: () => Navigator.of(context).pop(g),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenderChip extends StatelessWidget {
  const _GenderChip({
    required this.gender,
    required this.selected,
    required this.onTap,
  });

  final Gender gender;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: selected ? AppColors.primaryLight : context.sac.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppColors.primary : context.sac.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                HugeIcon(
                  icon: gender.icon,
                  size: 28,
                  color:
                      selected ? AppColors.primary : context.sac.textSecondary,
                ),
                const SizedBox(height: 8),
                Text(
                  gender.display(context),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected
                        ? AppColors.primary
                        : context.sac.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
