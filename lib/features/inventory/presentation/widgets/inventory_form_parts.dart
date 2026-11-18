import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/errors/user_error_message.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_network_image.dart';
import '../../../../core/widgets/sac_pressable.dart';
import '../../../../core/widgets/sac_sheet.dart';
import '../../domain/entities/inventory_category.dart';
import '../../domain/entities/inventory_item.dart';
import 'condition_style.dart';

/// Max photos per item (the backend rejects more).
const int kInventoryMaxPhotos = 3;

/// Field caption used above the form controls.
class InventoryFieldLabel extends StatelessWidget {
  final String text;

  const InventoryFieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: SacFontSize.bodyMedium,
        fontWeight: FontWeight.w600,
        color: context.sac.text,
      ),
    );
  }
}

// ── Photos ──────────────────────────────────────────────────────────────────────

/// Photo slots: the add tile first, then the item's saved photos and the ones
/// picked in this session (only those can be removed).
class InventoryPhotoSlots extends StatelessWidget {
  final List<InventoryEvidence> existing;
  final List<XFile> picked;
  final String? errorText;
  final VoidCallback onAdd;
  final ValueChanged<XFile> onRemove;

  const InventoryPhotoSlots({
    super.key,
    required this.existing,
    required this.picked,
    required this.onAdd,
    required this.onRemove,
    this.errorText,
  });

  static const double slot = 84;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final total = existing.length + picked.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: InventoryFieldLabel('inventory.form.photos_label'.tr()),
            ),
            Text(
              'inventory.form.evidence_count'
                  .tr(namedArgs: {'count': '$total'}),
              style: TextStyle(
                fontSize: SacFontSize.bodySmall,
                color: c.textTertiary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (total < kInventoryMaxPhotos) _AddTile(onTap: onAdd),
            for (final evidence in existing)
              _Thumb(
                child: SacNetworkImage(
                  imageUrl: evidence.url,
                  width: slot,
                  height: slot,
                  memCacheWidth: 252,
                  memCacheHeight: 252,
                ),
              ),
            for (final file in picked)
              _Thumb(
                onRemove: () => onRemove(file),
                child: Image.file(
                  File(file.path),
                  width: slot,
                  height: slot,
                  fit: BoxFit.cover,
                  cacheWidth: 252,
                  cacheHeight: 252,
                  errorBuilder: (_, __, ___) => ColoredBox(
                    color: c.surfaceVariant,
                    child: Center(
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedImageNotFound01,
                        size: 22,
                        color: c.textTertiary,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          errorText ?? 'inventory.form.evidence_hint'.tr(),
          style: TextStyle(
            fontSize: SacFontSize.bodySmall,
            color: errorText != null ? c.error : c.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _AddTile extends StatelessWidget {
  final VoidCallback onTap;

  const _AddTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context);
    return Semantics(
      button: true,
      label: 'inventory.form.add_photo'.tr(),
      excludeSemantics: true,
      child: SacInkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        child: Container(
          key: const ValueKey('inventory-add-photo'),
          width: InventoryPhotoSlots.slot,
          height: InventoryPhotoSlots.slot,
          decoration: BoxDecoration(
            color: accent.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            border: Border.all(color: accent.color.withValues(alpha: 0.45)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedCamera01,
                size: 24,
                color: accent.dark,
              ),
              const SizedBox(height: 4),
              Text(
                'inventory.form.add_photo'.tr(),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: SacFontSize.labelSmall,
                  fontWeight: FontWeight.w600,
                  color: c.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final Widget child;
  final VoidCallback? onRemove;

  const _Thumb({required this.child, this.onRemove});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: InventoryPhotoSlots.slot,
      height: InventoryPhotoSlots.slot,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              child: child,
            ),
          ),
          if (onRemove != null)
            Positioned(
              top: -10,
              right: -10,
              child: Semantics(
                button: true,
                label: 'inventory.form.remove_photo'.tr(),
                excludeSemantics: true,
                child: SacInkWell(
                  onTap: onRemove,
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  // 44pt target around a 24pt dot.
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: context.sac.text,
                          shape: BoxShape.circle,
                        ),
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedCancel01,
                          size: 14,
                          color: context.sac.surface,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Condition ───────────────────────────────────────────────────────────────────

/// The three conditions as icon options; the selected one takes the
/// condition's container colors.
class InventoryConditionOptions extends StatelessWidget {
  final ItemCondition selected;
  final ValueChanged<ItemCondition> onChanged;

  const InventoryConditionOptions({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Row(
      children: [
        for (final condition in ItemCondition.values) ...[
          if (condition != ItemCondition.values.first) const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              button: true,
              selected: condition == selected,
              label: condition.label,
              excludeSemantics: true,
              child: SacInkWell(
                onTap: () => onChanged(condition),
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                child: AnimatedContainer(
                  key: ValueKey('inventory-form-condition-${condition.name}'),
                  duration: const Duration(milliseconds: 160),
                  constraints: const BoxConstraints(minHeight: 72),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: condition == selected
                        ? condition.container(c)
                        : c.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    border: Border.all(
                      color: condition == selected
                          ? condition.onContainer(c)
                          : c.border,
                      width: condition == selected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      HugeIcon(
                        icon: condition.icon,
                        size: 24,
                        color: condition == selected
                            ? condition.onContainer(c)
                            : c.textSecondary,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        condition.shortLabel,
                        style: TextStyle(
                          fontSize: SacFontSize.bodySmall,
                          fontWeight: FontWeight.w700,
                          color: condition == selected
                              ? condition.onContainer(c)
                              : c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Date ────────────────────────────────────────────────────────────────────────

/// Tappable date row with a clear button once a date is set.
class InventoryDateField extends StatelessWidget {
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const InventoryDateField({
    super.key,
    required this.value,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final date = value;
    final text = date != null
        ? DateFormat.yMMMd(context.locale.toString()).format(date)
        : 'inventory.form.select_date'.tr();

    return Row(
      children: [
        Expanded(
          child: SacInkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: c.surfaceVariant,
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                border: Border.all(color: c.border),
              ),
              child: Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedCalendar01,
                    size: 18,
                    color: c.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      text,
                      style: TextStyle(
                        fontSize: SacFontSize.titleSmall,
                        color: date != null ? c.text : c.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (date != null)
          SacPressable(
            listenOnly: true,
            child: IconButton(
              enableFeedback: false,
              tooltip: 'common.clear'.tr(),
              onPressed: onClear,
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedCancel01,
                size: 18,
                color: c.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}

// ── Category sheet ──────────────────────────────────────────────────────────────

Future<InventoryCategory?> showInventoryCategorySheet(
  BuildContext context, {
  required List<InventoryCategory> categories,
  InventoryCategory? selected,
}) {
  return showSacSheet<InventoryCategory>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final c = sheetContext.sac;
      return Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusLG),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SacSheetHeader(title: 'inventory.form.category_sheet_title'.tr()),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  children: [
                    for (final category in categories)
                      _CategoryRow(
                        category: category,
                        selected: category.id == selected?.id,
                        onTap: () => Navigator.pop(sheetContext, category),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _CategoryRow extends StatelessWidget {
  final InventoryCategory category;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryRow({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: category.name,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: SacInkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedTag01,
                    size: 20,
                    color: selected ? accent.color : c.textSecondary,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      category.name,
                      style: TextStyle(
                        fontSize: SacFontSize.titleSmall,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: c.text,
                      ),
                    ),
                  ),
                  if (selected)
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedTick02,
                      size: 20,
                      color: accent.color,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown in place of the category picker when the catalog failed to load.
class InventoryCategoriesError extends StatelessWidget {
  final VoidCallback onRetry;

  /// The failure, so the row can say why (no permission, no connection, ...)
  /// instead of only "could not load".
  final Object? error;

  const InventoryCategoriesError(
      {super.key, required this.onRetry, this.error});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'inventory.form.categories_error'.tr(),
                style: TextStyle(
                  color: c.error,
                  fontSize: SacFontSize.bodyMedium,
                ),
              ),
              if (error != null)
                Text(
                  userErrorMessage(error),
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: SacFontSize.bodySmall,
                  ),
                ),
            ],
          ),
        ),
        SacPressable(
          listenOnly: true,
          child: SacButton.text(
            text: 'common.retry'.tr(),
            onPressed: onRetry,
          ),
        ),
      ],
    );
  }
}
