import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';

enum ActivityMoreAction { edit, delete }

/// Sheet behind the "⋯" of the activity detail. Edit first, delete last and
/// red; each one only when the user may. Resolves with the chosen action.
Future<ActivityMoreAction?> showActivityMoreSheet(
  BuildContext context, {
  required bool canEdit,
  required bool canDelete,
}) {
  return showSacSheet<ActivityMoreAction>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _ActivityMoreSheet(
      canEdit: canEdit,
      canDelete: canDelete,
    ),
  );
}

class _ActivityMoreSheet extends StatelessWidget {
  const _ActivityMoreSheet({required this.canEdit, required this.canDelete});

  final bool canEdit;
  final bool canDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(0, 0, 0, 16 + bottom),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXL),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SacSheetHeader(title: 'nav.more_options'.tr()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                if (canEdit)
                  _ActionRow(
                    key: const ValueKey('activity-edit-action'),
                    icon: HugeIcons.strokeRoundedEdit02,
                    label: 'activities.detail.action_edit'.tr(),
                    onTap: () =>
                        Navigator.of(context).pop(ActivityMoreAction.edit),
                  ),
                if (canDelete)
                  _ActionRow(
                    key: const ValueKey('activity-delete-action'),
                    icon: HugeIcons.strokeRoundedDelete02,
                    label: 'activities.detail.delete_button'.tr(),
                    destructive: true,
                    onTap: () =>
                        Navigator.of(context).pop(ActivityMoreAction.delete),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final HugeIconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final tile = destructive ? c.errorContainer : c.surfaceVariant;
    final ink = destructive ? c.onErrorContainer : c.textSecondary;
    return Material(
      color: Colors.transparent,
      child: SacInkWell(
        onTap: onTap,
        pressedScale: SacMotion.rowPressScale,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: tile, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: HugeIcon(icon: icon, size: 20, color: ink),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: SacFontSize.titleMedium,
                    fontWeight: FontWeight.w600,
                    color: destructive ? c.error : c.text,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
