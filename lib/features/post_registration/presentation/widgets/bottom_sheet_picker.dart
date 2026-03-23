import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Generic item model
// ─────────────────────────────────────────────────────────────────────────────

/// Minimal representation of an item shown in the picker sheet.
class PickerItem {
  final int id;
  final String name;

  const PickerItem({required this.id, required this.name});
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper — open the sheet and return the selected id (or null if dismissed)
// ─────────────────────────────────────────────────────────────────────────────

/// Shows the [BottomSheetPickerSheet] modally and returns the id of the item
/// that was tapped, or `null` if the user dismissed the sheet without picking.
Future<int?> showPickerSheet({
  required BuildContext context,
  required String title,
  required List<PickerItem> items,
  int? selectedId,
  String searchHint = 'Buscar...',
  IconData icon = Icons.list_rounded,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BottomSheetPickerSheet(
      title: title,
      items: items,
      selectedId: selectedId,
      searchHint: searchHint,
      icon: icon,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Tappable field widget
// ─────────────────────────────────────────────────────────────────────────────

/// A tappable container that looks like a form field and opens a
/// [BottomSheetPickerSheet] when tapped.
///
/// Designed to replace `SacDropdownField` / `CascadingDropdown` with the
/// bottom-sheet pattern already used in the emergency contacts form.
class PickerField extends StatelessWidget {
  /// Field label shown above the tappable container.
  final String label;

  /// Placeholder shown inside the field when nothing is selected.
  final String hint;

  /// Currently selected item's display name. `null` means nothing selected.
  final String? selectedName;

  /// Icon shown on the left side of the field.
  final IconData icon;

  /// Called when the user taps the field (and enabled is true).
  final VoidCallback? onTap;

  /// Whether the field is interactive. When false it renders in a muted style.
  final bool enabled;

  /// Whether the field is in a loading state (shows a spinner).
  final bool isLoading;

  const PickerField({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    this.selectedName,
    this.onTap,
    this.enabled = true,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasValue = selectedName != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: (enabled && !isLoading) ? onTap : null,
          child: Container(
            decoration: BoxDecoration(
              color: enabled ? context.sac.surface : context.sac.surfaceVariant,
              boxShadow: [
                BoxShadow(
                  color: context.sac.shadow,
                  offset: const Offset(0, 3),
                  blurRadius: 20,
                ),
              ],
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              border: Border.all(
                color: context.sac.border,
                width: 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: hasValue
                      ? AppColors.primary
                      : context.sac.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: isLoading
                      ? SizedBox(
                          height: 20,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: SacLoadingSmall(),
                            ),
                          ),
                        )
                      : Text(
                          hasValue ? selectedName! : hint,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: hasValue
                                ? context.sac.text
                                : context.sac.textTertiary,
                          ),
                        ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: enabled
                      ? context.sac.textSecondary
                      : context.sac.textTertiary,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

/// A modal bottom sheet with:
/// - drag handle
/// - title
/// - search text field
/// - scrollable list with icon, name, and checkmark for the selected item
/// - empty-state when no results match
///
/// Pops with the [PickerItem.id] of the tapped item (int) or null on dismiss.
class BottomSheetPickerSheet extends StatefulWidget {
  final String title;
  final List<PickerItem> items;
  final int? selectedId;
  final String searchHint;
  final IconData icon;

  const BottomSheetPickerSheet({
    super.key,
    required this.title,
    required this.items,
    this.selectedId,
    this.searchHint = 'Buscar...',
    this.icon = Icons.list_rounded,
  });

  @override
  State<BottomSheetPickerSheet> createState() =>
      _BottomSheetPickerSheetState();
}

class _BottomSheetPickerSheetState extends State<BottomSheetPickerSheet> {
  final _searchController = TextEditingController();
  List<PickerItem> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.items;
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearch);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtered = query.isEmpty
          ? widget.items
          : widget.items
              .where((item) => item.name.toLowerCase().contains(query))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.70),
      decoration: BoxDecoration(
        color: context.sac.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLG),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.sac.border,
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusFull),
                ),
              ),
            ),
          ),

          // Title
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.title,
                style: theme.textTheme.headlineSmall,
              ),
            ),
          ),

          const Divider(height: 1),

          // Search field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              autofocus: false,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: widget.searchHint,
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                        },
                        splashRadius: 16,
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusSM),
                  borderSide: BorderSide(color: context.sac.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusSM),
                  borderSide: BorderSide(color: context.sac.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusSM),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 2),
                ),
                filled: true,
                fillColor: context.sac.surfaceVariant,
              ),
            ),
          ),

          // List or empty state
          Flexible(
            child: _filtered.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 48,
                          color: context.sac.textTertiary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No se encontraron resultados',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: context.sac.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    shrinkWrap: true,
                    itemCount: _filtered.length,
                    itemBuilder: (_, index) {
                      final item = _filtered[index];
                      final isSelected = item.id == widget.selectedId;

                      return ListTile(
                        minTileHeight: 48,
                        leading: Icon(
                          widget.icon,
                          size: 22,
                          color: isSelected
                              ? AppColors.primary
                              : context.sac.textSecondary,
                        ),
                        title: Text(
                          item.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isSelected
                                ? AppColors.primary
                                : context.sac.text,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(
                                Icons.check_rounded,
                                color: AppColors.primary,
                                size: 20,
                              )
                            : null,
                        onTap: () => Navigator.of(context).pop(item.id),
                      );
                    },
                  ),
          ),

          // Bottom safe-area padding
          SizedBox(
              height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}
