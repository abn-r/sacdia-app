import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/fixed_input_icon_slot.dart';
import '../../data/models/relationship_type_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Tappable field that opens the RelationshipTypePickerSheet
// ─────────────────────────────────────────────────────────────────────────────

/// Searchable bottom-sheet picker for a relationship type.
///
/// Shared by the emergency-contact form (full catalog) and the family flows
/// (guardianship types, "Soy su…"). The caller decides WHICH types are listed;
/// [label], [placeholder] and [errorText] default to the contact-form copy.
class RelationshipTypePickerField extends StatelessWidget {
  final String? selectedId;
  final List<RelationshipTypeModel> relationshipTypes;
  final bool enabled;
  final bool hasError;
  final void Function(String id) onSelected;
  final String? label;
  final String? placeholder;
  final String? errorText;

  const RelationshipTypePickerField({
    super.key,
    required this.selectedId,
    required this.relationshipTypes,
    required this.onSelected,
    this.enabled = true,
    this.hasError = false,
    this.label,
    this.placeholder,
    this.errorText,
  });

  String? get _selectedName {
    if (selectedId == null) return null;
    final match = relationshipTypes.where((t) => t.id == selectedId);
    return match.isEmpty ? null : match.first.name;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = _selectedName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label ?? 'post_registration.contact_form.relationship_label'.tr(),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: enabled
              ? () async {
                  await showSacSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => RelationshipTypePickerSheet(
                      relationshipTypes: relationshipTypes,
                      selectedId: selectedId,
                      onSelected: (id) {
                        onSelected(id);
                        Navigator.of(context).pop();
                      },
                    ),
                  );
                }
              : null,
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
              border: hasError
                  ? Border.all(color: theme.colorScheme.error, width: 1.5)
                  : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedUserGroup,
                    size: 20,
                    color: context.sac.textSecondary,
                  ),
                ),
                Expanded(
                  child: Text(
                    selected ??
                        placeholder ??
                        'post_registration.contact_form.relationship_placeholder'
                            .tr(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: selected != null
                          ? context.sac.text
                          : context.sac.textTertiary,
                    ),
                  ),
                ),
                HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowDown01,
                  color: context.sac.textSecondary,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 6),
            child: Text(
              errorText ??
                  'post_registration.contact_form.relationship_required'.tr(),
              style: TextStyle(
                color: theme.colorScheme.error,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom sheet with search + list
// ─────────────────────────────────────────────────────────────────────────────

class RelationshipTypePickerSheet extends StatefulWidget {
  final List<RelationshipTypeModel> relationshipTypes;
  final String? selectedId;
  final void Function(String id) onSelected;

  const RelationshipTypePickerSheet({
    super.key,
    required this.relationshipTypes,
    required this.onSelected,
    this.selectedId,
  });

  @override
  State<RelationshipTypePickerSheet> createState() =>
      RelationshipTypePickerSheetState();
}

class RelationshipTypePickerSheetState
    extends State<RelationshipTypePickerSheet> {
  final _searchController = TextEditingController();
  List<RelationshipTypeModel> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.relationshipTypes;
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
          ? widget.relationshipTypes
          : widget.relationshipTypes
              .where((t) => t.name.toLowerCase().contains(query))
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
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
              ),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Text(
              'post_registration.contact_form.relationship_sheet_title'.tr(),
              style: theme.textTheme.headlineSmall,
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
                hintText:
                    'post_registration.contact_form.relationship_search_hint'
                        .tr(),
                prefixIconConstraints: FixedInputIconSlot.constraints,
                prefixIcon: FixedInputIconSlot(
                  icon: HugeIcons.strokeRoundedSearch01,
                  color: context.sac.textTertiary,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  borderSide: BorderSide(color: context.sac.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  borderSide: BorderSide(color: context.sac.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  borderSide:
                      BorderSide(color: SacAccent.of(context).color, width: 2),
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
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedSearchRemove,
                          size: 48,
                          color: context.sac.textTertiary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'post_registration.contact_form.relationship_no_results'
                              .tr(),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: context.sac.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: SacTopBar.paddingBelowBar(
                        context, const EdgeInsets.symmetric(vertical: 4)),
                    // shrinkWrap removed: parent Flexible provides a bounded
                    // height constraint — ListView can scroll normally.
                    itemCount: _filtered.length,
                    itemBuilder: (_, index) {
                      final type = _filtered[index];
                      final isSelected = type.id == widget.selectedId;

                      return SacPressable(
                        listenOnly: true,
                        child: ListTile(
                          enableFeedback: false,
                          minTileHeight: 48,
                          leading: HugeIcon(
                            icon: HugeIcons.strokeRoundedUserGroup,
                            size: 22,
                            color: isSelected
                                ? SacAccent.of(context).color
                                : context.sac.textSecondary,
                          ),
                          title: Text(
                            type.name,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isSelected
                                  ? SacAccent.of(context).color
                                  : context.sac.text,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                          trailing: isSelected
                              ? HugeIcon(
                                  icon: HugeIcons.strokeRoundedTick02,
                                  color: SacAccent.of(context).color,
                                  size: 20,
                                )
                              : null,
                          onTap: () => widget.onSelected(type.id),
                        ),
                      );
                    },
                  ),
          ),

          // Bottom safe-area padding
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}
