import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/role_utils.dart';
import 'package:sacdia_app/core/widgets/fixed_input_icon_slot.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_member_avatar.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';
import 'package:sacdia_app/features/members/domain/entities/club_member.dart';

/// Opens a searchable bottom sheet to pick one [ClubMember].
///
/// [excludeIds] prevents already-assigned members from appearing (optional).
Future<ClubMember?> showUnitMemberPickerSheet({
  required BuildContext context,
  required List<ClubMember> members,
  required String title,
  String? currentUserId,
  Set<String> excludeIds = const {},
}) {
  return showSacSheet<ClubMember>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _MemberPickerSheet(
      title: title,
      members: members,
      currentUserId: currentUserId,
      excludeIds: excludeIds,
    ),
  );
}

/// Opens a searchable bottom sheet to multi-select [ClubMember]s.
///
/// [excludeIds] hides reserved members (captain, secretary, advisor…).
/// [selectedIds] are pre-checked.
Future<List<ClubMember>?> showUnitMultiMemberPickerSheet({
  required BuildContext context,
  required List<ClubMember> members,
  required Set<String> selectedIds,
  Set<String> excludeIds = const {},
}) {
  return showSacSheet<List<ClubMember>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _MultiMemberPickerSheet(
      members: members,
      selectedIds: selectedIds,
      excludeIds: excludeIds,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Single-select member picker sheet
// ─────────────────────────────────────────────────────────────────────────────

class _MemberPickerSheet extends StatefulWidget {
  final String title;
  final List<ClubMember> members;
  final String? currentUserId;
  final Set<String> excludeIds;

  const _MemberPickerSheet({
    required this.title,
    required this.members,
    this.currentUserId,
    this.excludeIds = const {},
  });

  @override
  State<_MemberPickerSheet> createState() => _MemberPickerSheetState();
}

class _MemberPickerSheetState extends State<_MemberPickerSheet> {
  final _searchController = TextEditingController();
  late List<ClubMember> _filtered;

  List<ClubMember> get _eligible => widget.members
      .where((m) => !widget.excludeIds.contains(m.userId))
      .toList();

  @override
  void initState() {
    super.initState();
    _filtered = _eligible;
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
          ? _eligible
          : _eligible
              .where((m) => m.fullName.toLowerCase().contains(query))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.72),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLG),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SacSheetHeader(title: widget.title),

          const Divider(height: 1),

          // Search field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              autofocus: false,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'units.form.search_hint'.tr(),
                prefixIconConstraints: FixedInputIconSlot.constraints,
                prefixIcon: FixedInputIconSlot(
                  icon: HugeIcons.strokeRoundedSearch01,
                  color: c.textTertiary,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? SacPressable(
                        listenOnly: true,
                        child: IconButton(
                          enableFeedback: false,
                          icon: const HugeIcon(
                              icon: HugeIcons.strokeRoundedCancel01, size: 18),
                          onPressed: _searchController.clear,
                          splashRadius: 16,
                        ),
                      )
                    : null,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  borderSide: BorderSide(color: c.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  borderSide: BorderSide(color: c.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  borderSide:
                      BorderSide(color: SacAccent.of(context).color, width: 2),
                ),
                filled: true,
                fillColor: c.surfaceVariant,
              ),
            ),
          ),

          // List
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
                            color: c.textTertiary),
                        const SizedBox(height: 12),
                        Text(
                          'common.no_results'.tr(),
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: c.textSecondary),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final m = _filtered[i];
                      final isSelected = m.userId == widget.currentUserId;
                      return SacPressable(
                        listenOnly: true,
                        child: Material(
                            type: MaterialType.transparency,
                            child: ListTile(
                              enableFeedback: false,
                              minTileHeight: 52,
                              leading: SacMemberAvatar(
                                imageUrl: m.avatar,
                                name: m.fullName,
                                size: 36,
                              ),
                              title: Text(
                                m.fullName,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: isSelected
                                      ? SacAccent.of(context).color
                                      : c.text,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                              subtitle: m.clubRole != null
                                  ? Text(
                                      RoleUtils.translate(
                                        m.clubRole,
                                        gender: m.gender,
                                      ),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(color: c.textSecondary),
                                    )
                                  : null,
                              trailing: isSelected
                                  ? HugeIcon(
                                      icon: HugeIcons.strokeRoundedTick02,
                                      color: SacAccent.of(context).color,
                                      size: 20,
                                    )
                                  : null,
                              onTap: () => Navigator.of(context).pop(m),
                            )),
                      );
                    },
                  ),
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Multi-select member picker sheet
// ─────────────────────────────────────────────────────────────────────────────

class _MultiMemberPickerSheet extends StatefulWidget {
  final List<ClubMember> members;
  final Set<String> selectedIds;
  final Set<String> excludeIds;

  const _MultiMemberPickerSheet({
    required this.members,
    required this.selectedIds,
    this.excludeIds = const {},
  });

  @override
  State<_MultiMemberPickerSheet> createState() =>
      _MultiMemberPickerSheetState();
}

class _MultiMemberPickerSheetState extends State<_MultiMemberPickerSheet> {
  final _searchController = TextEditingController();
  late Set<String> _selected;
  late List<ClubMember> _filtered;

  List<ClubMember> get _eligible => widget.members
      .where((m) => !widget.excludeIds.contains(m.userId))
      .toList();

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.selectedIds);
    _filtered = _eligible;
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
          ? _eligible
          : _eligible
              .where((m) => m.fullName.toLowerCase().contains(query))
              .toList();
    });
  }

  void _toggle(ClubMember m) {
    setState(() {
      if (_selected.contains(m.userId)) {
        _selected.remove(m.userId);
      } else {
        _selected.add(m.userId);
      }
    });
  }

  void _confirm() {
    final result =
        widget.members.where((m) => _selected.contains(m.userId)).toList();
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.80),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLG),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SacSheetHeader(
            title: 'units.form.add_member_button'.tr(),
            subtitle: _selected.isEmpty
                ? null
                : _selected.length == 1
                    ? tr('units.form.selected_count_one',
                        namedArgs: {'count': '${_selected.length}'})
                    : tr('units.form.selected_count_other',
                        namedArgs: {'count': '${_selected.length}'}),
            actions: [
              SacButton(
                text: 'units.form.done'.tr(),
                variant: SacButtonVariant.primary,
                size: SacButtonSize.small,
                fullWidth: false,
                onPressed: _confirm,
              ),
            ],
          ),

          const Divider(height: 1),

          // Search field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'units.form.search_hint'.tr(),
                prefixIconConstraints: FixedInputIconSlot.constraints,
                prefixIcon: FixedInputIconSlot(
                  icon: HugeIcons.strokeRoundedSearch01,
                  color: c.textTertiary,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? SacPressable(
                        listenOnly: true,
                        child: IconButton(
                          enableFeedback: false,
                          icon: const HugeIcon(
                              icon: HugeIcons.strokeRoundedCancel01, size: 18),
                          onPressed: _searchController.clear,
                          splashRadius: 16,
                        ),
                      )
                    : null,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  borderSide: BorderSide(color: c.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  borderSide: BorderSide(color: c.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  borderSide:
                      BorderSide(color: SacAccent.of(context).color, width: 2),
                ),
                filled: true,
                fillColor: c.surfaceVariant,
              ),
            ),
          ),

          // List
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
                            color: c.textTertiary),
                        const SizedBox(height: 12),
                        Text(
                          'common.no_results'.tr(),
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: c.textSecondary),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final m = _filtered[i];
                      final isSelected = _selected.contains(m.userId);
                      return SacPressable(
                        listenOnly: true,
                        child: Material(
                            type: MaterialType.transparency,
                            child: CheckboxListTile(
                              enableFeedback: false,
                              value: isSelected,
                              onChanged: (_) => _toggle(m),
                              activeColor: SacAccent.of(context).color,
                              secondary: SacMemberAvatar(
                                imageUrl: m.avatar,
                                name: m.fullName,
                                size: 36,
                              ),
                              title: Text(
                                m.fullName,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: isSelected
                                      ? SacAccent.of(context).color
                                      : c.text,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                              subtitle: m.clubRole != null
                                  ? Text(
                                      RoleUtils.translate(
                                        m.clubRole,
                                        gender: m.gender,
                                      ),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(color: c.textSecondary),
                                    )
                                  : null,
                              controlAffinity: ListTileControlAffinity.trailing,
                            )),
                      );
                    },
                  ),
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
        ],
      ),
    );
  }
}
