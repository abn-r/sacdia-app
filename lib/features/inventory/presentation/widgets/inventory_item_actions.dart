import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../../../core/widgets/sac_dialog.dart';
import '../../../../core/widgets/sac_pressable.dart';
import '../../../../core/widgets/sac_sheet.dart';
import '../../../../core/widgets/sac_snack_bar.dart';
import '../../domain/entities/inventory_item.dart';
import '../providers/inventory_providers.dart';
import '../views/add_inventory_item_sheet.dart';
import 'condition_style.dart';

/// What the user can do with one item from its "more" sheet.
enum InventoryItemAction { view, edit, changeCondition, delete }

/// Options sheet of one item. Resolves to the chosen action (the caller runs
/// it once the sheet is closed) or null when dismissed.
///
/// [includeView] is false on the detail screen, where the item is already
/// open. [canManage] hides edit, state change and delete for read-only roles.
Future<InventoryItemAction?> showInventoryItemActionsSheet(
  BuildContext context, {
  required InventoryItem item,
  required bool canManage,
  bool includeView = true,
}) {
  return showSacSheet<InventoryItemAction>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SheetFrame(
      title: item.name,
      subtitle: item.category.name,
      children: [
        if (includeView)
          _SheetOption(
            icon: HugeIcons.strokeRoundedView,
            label: 'inventory.actions.view'.tr(),
            onTap: () => Navigator.pop(context, InventoryItemAction.view),
          ),
        if (canManage) ...[
          _SheetOption(
            icon: HugeIcons.strokeRoundedEdit02,
            label: 'common.edit'.tr(),
            onTap: () => Navigator.pop(context, InventoryItemAction.edit),
          ),
          _SheetOption(
            icon: HugeIcons.strokeRoundedRefresh,
            label: 'inventory.actions.change_condition'.tr(),
            onTap: () =>
                Navigator.pop(context, InventoryItemAction.changeCondition),
          ),
          // Destructive option last, apart and red.
          _SheetOption(
            icon: HugeIcons.strokeRoundedDelete02,
            label: 'common.delete'.tr(),
            destructive: true,
            onTap: () => Navigator.pop(context, InventoryItemAction.delete),
          ),
        ],
      ],
    ),
  );
}

/// Sub-sheet with the three conditions; the current one is checked.
Future<ItemCondition?> showInventoryConditionSheet(
  BuildContext context, {
  required ItemCondition current,
}) {
  return showSacSheet<ItemCondition>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SheetFrame(
      title: 'inventory.actions.condition_title'.tr(),
      children: [
        for (final condition in ItemCondition.values)
          _SheetOption(
            key: ValueKey('inventory-condition-${condition.name}'),
            icon: condition.icon,
            label: condition.label,
            selected: condition == current,
            onTap: () => Navigator.pop(context, condition),
          ),
      ],
    ),
  );
}

/// Runs [action] for [item]. Returns true when the item was deleted so a
/// detail screen can close itself. [onView] is only needed from the list.
Future<bool> runInventoryItemAction(
  BuildContext context,
  WidgetRef ref, {
  required InventoryItem item,
  required InventoryItemAction action,
  VoidCallback? onView,
}) async {
  switch (action) {
    case InventoryItemAction.view:
      onView?.call();
      return false;
    case InventoryItemAction.edit:
      await showInventoryItemForm(context, existing: item);
      return false;
    case InventoryItemAction.changeCondition:
      final picked =
          await showInventoryConditionSheet(context, current: item.condition);
      if (picked == null || picked == item.condition || !context.mounted) {
        return false;
      }
      final ok = await ref
          .read(inventoryConditionNotifierProvider.notifier)
          .change(item, picked);
      if (!context.mounted) return false;
      SacSnackBar.show(
        context,
        ok
            ? 'inventory.actions.condition_updated'.tr()
            : 'inventory.actions.condition_error'.tr(),
        isSuccess: ok,
        isError: !ok,
      );
      return false;
    case InventoryItemAction.delete:
      return confirmAndDeleteInventoryItem(context, ref, item);
  }
}

/// Destructive confirmation, then the delete request. True when deleted.
Future<bool> confirmAndDeleteInventoryItem(
  BuildContext context,
  WidgetRef ref,
  InventoryItem item,
) async {
  final confirmed = await SacDialog.show(
    context,
    title: 'inventory.detail.delete_title'.tr(),
    content:
        'inventory.detail.delete_confirm'.tr(namedArgs: {'name': item.name}),
    confirmLabel: 'common.delete'.tr(),
    confirmIsDestructive: true,
  );
  if (confirmed != true || !context.mounted) return false;

  final success = await ref
      .read(inventoryDeleteNotifierProvider.notifier)
      .deleteItem(item.id);
  if (!context.mounted) return success;
  SacSnackBar.show(
    context,
    success
        ? 'inventory.detail.deleted_success'.tr()
        : 'inventory.detail.delete_error'.tr(),
    isSuccess: success,
    isError: !success,
  );
  return success;
}

// ── Sheet chrome ────────────────────────────────────────────────────────────────

class _SheetFrame extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;

  const _SheetFrame({
    required this.title,
    this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
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
            SacSheetHeader(title: title, subtitle: subtitle),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                child: Column(children: children),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  final HugeIconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
  final bool selected;

  const _SheetOption({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context);
    final color = destructive ? c.error : c.text;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
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
                  HugeIcon(icon: icon, size: 22, color: color),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: SacFontSize.titleSmall,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: color,
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
