import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/fixed_input_icon_slot.dart';
import '../../../../core/widgets/sac_pressable.dart';

/// Search field plus the filter button. The button carries a badge with the
/// number of filters active in the sheet ([activeCount]).
class InventoryFilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onFilterTap;
  final int activeCount;

  const InventoryFilterBar({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.onFilterTap,
    required this.activeCount,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'inventory.summary_header.search_hint'.tr(),
                hintStyle: TextStyle(
                  color: c.textTertiary,
                  fontSize: SacFontSize.titleSmall,
                ),
                prefixIconConstraints: FixedInputIconSlot.constraints,
                prefixIcon: FixedInputIconSlot(
                  icon: HugeIcons.strokeRoundedSearch01,
                  iconSize: 18,
                  color: c.textTertiary,
                ),
                suffixIcon: searchController.text.isNotEmpty
                    ? SacPressable(
                        listenOnly: true,
                        child: IconButton(
                          enableFeedback: false,
                          tooltip: 'common.clear'.tr(),
                          onPressed: () {
                            searchController.clear();
                            onSearchChanged('');
                          },
                          icon: HugeIcon(
                            icon: HugeIcons.strokeRoundedCancel01,
                            size: 16,
                            color: c.textTertiary,
                          ),
                        ),
                      )
                    : null,
                filled: true,
                fillColor: c.surfaceVariant,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  borderSide: BorderSide(color: c.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  borderSide: BorderSide(color: accent.color, width: 2),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _FilterButton(onTap: onFilterTap, activeCount: activeCount),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final VoidCallback onTap;
  final int activeCount;

  const _FilterButton({required this.onTap, required this.activeCount});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context);
    final isActive = activeCount > 0;
    final label = 'inventory.filter_sheet.title'.tr();

    return Semantics(
      button: true,
      label: isActive ? '$label, $activeCount' : label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: SacInkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusSM),
          child: Container(
            key: const ValueKey('inventory-filter-button'),
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: isActive ? accent.surface : c.surfaceVariant,
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              border: Border.all(color: isActive ? accent.color : c.border),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedFilter,
                    size: 20,
                    color: isActive ? accent.color : c.textSecondary,
                  ),
                ),
                if (isActive)
                  Positioned(
                    top: -6,
                    right: -6,
                    child: Container(
                      key: const ValueKey('inventory-filter-badge'),
                      constraints:
                          const BoxConstraints(minWidth: 20, minHeight: 20),
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accent.color,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusFull),
                      ),
                      child: Text(
                        '$activeCount',
                        style: TextStyle(
                          fontSize: SacFontSize.labelSmall,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                          color: accent.onColor,
                        ),
                      ),
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
