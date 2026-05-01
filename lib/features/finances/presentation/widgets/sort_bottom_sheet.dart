import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';

/// Bottom sheet for choosing transaction sort order.
///
/// Manages its own local state before the user taps "Aplicar", so the main
/// list is not updated on every tap inside the sheet.
class SortBottomSheet extends StatefulWidget {
  final String currentSortBy;
  final String currentSortOrder;
  final void Function(String sortBy, String sortOrder) onApply;

  const SortBottomSheet({
    super.key,
    required this.currentSortBy,
    required this.currentSortOrder,
    required this.onApply,
  });

  @override
  State<SortBottomSheet> createState() => _SortBottomSheetState();
}

class _SortBottomSheetState extends State<SortBottomSheet> {
  late String _selectedSortBy;
  late String _sortOrder;

  @override
  void initState() {
    super.initState();
    _selectedSortBy = widget.currentSortBy;
    _sortOrder = widget.currentSortOrder;
  }

  void _toggleSortOrder() {
    setState(
        () => _sortOrder = _sortOrder == 'desc' ? 'asc' : 'desc');
  }

  void _onApply() {
    widget.onApply(_selectedSortBy, _sortOrder);
    Navigator.of(context).pop();
  }

  String _descriptionFor(String sortBy) {
    if (_selectedSortBy != sortBy) {
      return switch (sortBy) {
        'date' => 'finances.widgets.sort_date_desc'.tr(),
        'amount' => 'finances.widgets.sort_amount_desc'.tr(),
        'category' => 'finances.widgets.sort_category_asc'.tr(),
        _ => '',
      };
    }
    return switch (sortBy) {
      'date' => _sortOrder == 'desc'
          ? 'finances.widgets.sort_date_desc'.tr()
          : 'finances.widgets.sort_date_asc'.tr(),
      'amount' => _sortOrder == 'desc'
          ? 'finances.widgets.sort_amount_desc'.tr()
          : 'finances.widgets.sort_amount_asc'.tr(),
      'category' =>
        _sortOrder == 'desc'
            ? 'finances.widgets.sort_category_desc'.tr()
            : 'finances.widgets.sort_category_asc'.tr(),
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.sac.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DragHandle(),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'finances.widgets.sort_title'.tr(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.sac.text,
              ),
            ),
          ),
          const SizedBox(height: 16),
          RadioGroup<String>(
            groupValue: _selectedSortBy,
            onChanged: (value) {
              if (value != null) setState(() => _selectedSortBy = value);
            },
            child: Column(
              children: [
                _SortOption(
                  label: 'finances.widgets.sort_by_date'.tr(),
                  sortKey: 'date',
                  description: _descriptionFor('date'),
                  selectedSortBy: _selectedSortBy,
                  sortOrder: _sortOrder,
                  onToggleOrder: _toggleSortOrder,
                ),
                _SortOption(
                  label: 'finances.widgets.sort_by_amount'.tr(),
                  sortKey: 'amount',
                  description: _descriptionFor('amount'),
                  selectedSortBy: _selectedSortBy,
                  sortOrder: _sortOrder,
                  onToggleOrder: _toggleSortOrder,
                ),
                _SortOption(
                  label: 'finances.widgets.sort_by_category'.tr(),
                  sortKey: 'category',
                  description: _descriptionFor('category'),
                  selectedSortBy: _selectedSortBy,
                  sortOrder: _sortOrder,
                  onToggleOrder: _toggleSortOrder,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _BottomSheetApplyButton(onApply: _onApply),
        ],
      ),
    );
  }
}

// ── Sort option row ────────────────────────────────────────────────────────────

class _SortOption extends StatelessWidget {
  final String label;
  final String sortKey;
  final String description;
  final String selectedSortBy;
  final String sortOrder;
  final VoidCallback onToggleOrder;

  const _SortOption({
    required this.label,
    required this.sortKey,
    required this.description,
    required this.selectedSortBy,
    required this.sortOrder,
    required this.onToggleOrder,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = selectedSortBy == sortKey;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Radio<String>(
            value: sortKey,
            activeColor: AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: context.sac.text,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: context.sac.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (isActive)
            GestureDetector(
              onTap: onToggleOrder,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: HugeIcon(
                  icon: sortOrder == 'asc'
                      ? HugeIcons.strokeRoundedArrowUp01
                      : HugeIcons.strokeRoundedArrowDown01,
                  size: 20,
                  color: context.sac.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Shared bottom sheet chrome ─────────────────────────────────────────────────

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: context.sac.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _BottomSheetApplyButton extends StatelessWidget {
  final VoidCallback onApply;

  const _BottomSheetApplyButton({required this.onApply});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onApply,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          'finances.widgets.apply'.tr(),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
