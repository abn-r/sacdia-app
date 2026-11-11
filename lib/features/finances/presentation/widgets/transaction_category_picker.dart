import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/sac_colors.dart';
import '../../domain/entities/finance_category.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';

/// Campo del formulario que abre el selector de categoría del movimiento.
class TransactionCategoryPickerField extends StatelessWidget {
  final FinanceCategory? value;
  final String hint;
  final String? errorText;
  final VoidCallback onTap;

  const TransactionCategoryPickerField({
    super.key,
    required this.value,
    required this.hint,
    required this.onTap,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    final borderColor = errorText != null
        ? context.sac.error
        : Theme.of(context).dividerColor.withValues(alpha: 0.4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          label: hasValue ? value!.name : hint,
          child: Material(
            color: Colors.transparent,
            child: SacInkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              child: Ink(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  border: Border.all(
                    color: borderColor,
                    width: errorText != null ? 1.4 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: SacAccent.of(context).surface,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                      ),
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedTag01,
                        size: 20,
                        color: SacAccent.of(context).color,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        hasValue ? value!.name : hint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight:
                                  hasValue ? FontWeight.w600 : FontWeight.w500,
                              color: hasValue
                                  ? context.sac.text
                                  : context.sac.textTertiary,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowDown01,
                      size: 20,
                      color: context.sac.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              errorText!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: context.sac.error),
            ),
          ),
        ],
      ],
    );
  }
}

/// Abre el selector de categoría y devuelve la elegida (o null si se cierra).
Future<FinanceCategory?> showTransactionCategoryPicker(
  BuildContext context, {
  required List<FinanceCategory> categories,
  FinanceCategory? selected,
}) {
  return showSacSheet<FinanceCategory>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _CategoryPickerSheet(categories: categories, selected: selected),
  );
}

class _CategoryPickerSheet extends StatelessWidget {
  final List<FinanceCategory> categories;
  final FinanceCategory? selected;

  const _CategoryPickerSheet({required this.categories, this.selected});

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.64;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Container(
        decoration: BoxDecoration(
          color: context.sac.surface,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppTheme.radiusXL)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.sac.border,
                borderRadius: BorderRadius.circular(AppTheme.radiusHairline),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: SacAccent.of(context).surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    ),
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedTag01,
                      size: 22,
                      color: SacAccent.of(context).color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'finances.add_transaction.category_label'.tr(),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(
                  12,
                  4,
                  12,
                  MediaQuery.of(context).padding.bottom + 12,
                ),
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (_, index) {
                  final category = categories[index];
                  final isSelected = category.id == selected?.id;

                  return _CategoryPickerOption(
                    category: category,
                    isSelected: isSelected,
                    onTap: () => Navigator.of(context).pop(category),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryPickerOption extends StatelessWidget {
  final FinanceCategory category;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryPickerOption({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground =
        isSelected ? SacAccent.of(context).color : context.sac.text;
    final background = isSelected
        ? SacAccent.of(context).color.withValues(alpha: 0.08)
        : Colors.transparent;

    return Semantics(
      button: true,
      selected: isSelected,
      label: category.name,
      child: Material(
        color: Colors.transparent,
        child: SacInkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              border: Border.all(
                color: isSelected
                    ? SacAccent.of(context).color.withValues(alpha: 0.24)
                    : context.sac.borderLight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? SacAccent.of(context).surface
                        : context.sac.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  ),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedTag01,
                    size: 20,
                    color: isSelected
                        ? SacAccent.of(context).color
                        : context.sac.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    category.name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: foreground,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                  ),
                ),
                if (isSelected)
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedTick02,
                    size: 20,
                    color: SacAccent.of(context).color,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
