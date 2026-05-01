import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../domain/entities/unit.dart';
import '../../../members/domain/entities/club_member.dart';
import '../../../members/presentation/providers/members_providers.dart';
import '../providers/units_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public entry point
// ─────────────────────────────────────────────────────────────────────────────

/// Shows the unit create/edit bottom sheet.
///
/// Pass [unit] to enter edit mode (fields pre-populated).
/// Returns `true` when a unit was successfully created or updated so the
/// caller can trigger a refresh. Returns `null` if the user dismissed without
/// saving.
Future<bool?> showUnitFormSheet({
  required BuildContext context,
  required WidgetRef ref,
  Unit? unit,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _UnitFormSheet(unit: unit),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal member picker sheet  (single-select)
// ─────────────────────────────────────────────────────────────────────────────

/// Opens a searchable bottom sheet to pick one [ClubMember].
///
/// [excludeIds] prevents already-assigned members from appearing (optional).
Future<ClubMember?> _showMemberPickerSheet({
  required BuildContext context,
  required List<ClubMember> members,
  required String title,
  String? currentUserId,
  Set<String> excludeIds = const {},
}) {
  return showModalBottomSheet<ClubMember>(
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
Future<List<ClubMember>?> _showMultiMemberPickerSheet({
  required BuildContext context,
  required List<ClubMember> members,
  required Set<String> selectedIds,
  Set<String> excludeIds = const {},
}) {
  return showModalBottomSheet<List<ClubMember>>(
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
// Main form sheet
// ─────────────────────────────────────────────────────────────────────────────

class _UnitFormSheet extends ConsumerStatefulWidget {
  final Unit? unit;

  const _UnitFormSheet({this.unit});

  @override
  ConsumerState<_UnitFormSheet> createState() => _UnitFormSheetState();
}

class _UnitFormSheetState extends ConsumerState<_UnitFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  ClubMember? _captain;
  ClubMember? _secretary;
  ClubMember? _advisor;
  ClubMember? _substituteAdvisor;
  List<ClubMember> _members = [];

  bool _isSaving = false;

  bool get _isEditMode => widget.unit != null;

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _nameController.text = widget.unit!.name;
      // Role fields are resolved once club members are loaded — see
      // _resolveEditFields() which is called inside the build via
      // a post-frame callback triggered on first load.
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // ── Edit-mode pre-population ────────────────────────────────────────────────

  /// Finds [ClubMember] instances matching the IDs stored in [widget.unit].
  /// Called once after the members list is available.
  void _resolveEditFields(List<ClubMember> allMembers) {
    if (!_isEditMode) return;
    final unit = widget.unit!;

    ClubMember? find(String? id) =>
        id == null ? null : allMembers.where((m) => m.userId == id).firstOrNull;

    // Derive unit member list: UnitMember.id maps to ClubMember.userId
    final unitMemberIds =
        unit.members.map((um) => um.id).toSet();

    setState(() {
      _captain = find(unit.captainId);
      _secretary = find(unit.secretaryId);
      _advisor = find(unit.advisorId);
      _substituteAdvisor = find(unit.substituteAdvisorId);
      _members = allMembers
          .where((m) => unitMemberIds.contains(m.userId))
          .toList();
    });
  }

  // ── Role-picker IDs to exclude ───────────────────────────────────────────────

  Set<String> get _assignedRoleIds {
    return {
      if (_captain != null) _captain!.userId,
      if (_secretary != null) _secretary!.userId,
      if (_advisor != null) _advisor!.userId,
      if (_substituteAdvisor != null) _substituteAdvisor!.userId,
    };
  }

  // ── Picker helpers ───────────────────────────────────────────────────────────

  Future<void> _pickCaptain(List<ClubMember> allMembers) async {
    final exclude = {
      if (_secretary != null) _secretary!.userId,
      if (_advisor != null) _advisor!.userId,
      if (_substituteAdvisor != null) _substituteAdvisor!.userId,
    };
    final picked = await _showMemberPickerSheet(
      context: context,
      members: allMembers,
      title: 'units.form.picker_captain'.tr(),
      currentUserId: _captain?.userId,
      excludeIds: exclude,
    );
    if (picked != null) setState(() => _captain = picked);
  }

  Future<void> _pickSecretary(List<ClubMember> allMembers) async {
    final exclude = {
      if (_captain != null) _captain!.userId,
      if (_advisor != null) _advisor!.userId,
      if (_substituteAdvisor != null) _substituteAdvisor!.userId,
    };
    final picked = await _showMemberPickerSheet(
      context: context,
      members: allMembers,
      title: 'units.form.picker_secretary'.tr(),
      currentUserId: _secretary?.userId,
      excludeIds: exclude,
    );
    if (picked != null) setState(() => _secretary = picked);
  }

  Future<void> _pickAdvisor(List<ClubMember> allMembers) async {
    final exclude = {
      if (_captain != null) _captain!.userId,
      if (_secretary != null) _secretary!.userId,
      if (_substituteAdvisor != null) _substituteAdvisor!.userId,
    };
    final picked = await _showMemberPickerSheet(
      context: context,
      members: allMembers,
      title: 'units.form.picker_advisor'.tr(),
      currentUserId: _advisor?.userId,
      excludeIds: exclude,
    );
    if (picked != null) setState(() => _advisor = picked);
  }

  Future<void> _pickSubstituteAdvisor(List<ClubMember> allMembers) async {
    final exclude = {
      if (_captain != null) _captain!.userId,
      if (_secretary != null) _secretary!.userId,
      if (_advisor != null) _advisor!.userId,
    };
    final picked = await _showMemberPickerSheet(
      context: context,
      members: allMembers,
      title: 'units.form.picker_substitute_advisor'.tr(),
      currentUserId: _substituteAdvisor?.userId,
      excludeIds: exclude,
    );
    if (picked != null) setState(() => _substituteAdvisor = picked);
  }

  Future<void> _pickMembers(List<ClubMember> allMembers) async {
    final selectedIds = _members.map((m) => m.userId).toSet();
    final picked = await _showMultiMemberPickerSheet(
      context: context,
      members: allMembers,
      selectedIds: selectedIds,
      excludeIds: _assignedRoleIds,
    );
    if (picked != null) setState(() => _members = picked);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  /// Maps the club type name string (from [ClubContext]) to its backend integer ID.
  ///
  /// Backend convention: 1=Aventureros, 2=Conquistadores, 3=Guías Mayores.
  /// Falls back to 2 (Conquistadores) when the name is unrecognised.
  int _clubTypeIdFromName(String? name) {
    if (name == null) return 2;
    final lower = name.toLowerCase();
    if (lower.contains('aventurer')) return 1;
    if (lower.contains('conquistador')) return 2;
    if (lower.contains('guía') || lower.contains('guia')) return 3;
    return 2;
  }

  // ── Save ─────────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_captain == null || _secretary == null || _advisor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('units.form.roles_required_error'.tr()),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final notifier = ref.read(unitsNotifierProvider.notifier);
    final memberIds = _members.map((m) => m.userId).toList();

    bool success;

    if (_isEditMode) {
      success = await notifier.updateUnit(
        unitId: widget.unit!.id,
        name: _nameController.text.trim(),
        captainId: _captain!.userId,
        secretaryId: _secretary!.userId,
        advisorId: _advisor!.userId,
        substituteAdvisorId: _substituteAdvisor?.userId,
      );
    } else {
      // clubTypeId and clubSectionId are resolved inside the notifier
      // from ClubContext, but createUnit requires them as explicit params.
      // Read context here to pass them correctly.
      final ctx = await ref.read(clubContextProvider.future);
      if (ctx == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('units.form.club_context_error'.tr()),
            ),
          );
          setState(() => _isSaving = false);
        }
        return;
      }

      // Derive the numeric clubTypeId from the club type name in context.
      // Backend IDs: 1=Aventureros, 2=Conquistadores, 3=Guías Mayores.
      final clubTypeId = _clubTypeIdFromName(ctx.clubTypeName);

      success = await notifier.createUnit(
        name: _nameController.text.trim(),
        captainId: _captain!.userId,
        secretaryId: _secretary!.userId,
        advisorId: _advisor!.userId,
        substituteAdvisorId: _substituteAdvisor?.userId,
        clubTypeId: clubTypeId,
        clubSectionId: ctx.sectionId,
        memberUserIds: memberIds,
      );
    }

    if (!mounted) return;

    setState(() => _isSaving = false);

    if (success) {
      Navigator.of(context).pop(true);
    } else {
      final errorMsg =
          ref.read(unitsNotifierProvider).errorMessage ??
              'common.error_generic'.tr();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final theme = Theme.of(context);

    // Watch members — when the async value first resolves in edit mode,
    // pre-populate the role fields.
    final membersAsync = ref.watch(membersNotifierProvider);
    final allMembers = membersAsync.valueOrNull?.members ?? const [];

    // Pre-populate role fields once data arrives in edit mode.
    // We track whether we've done this with a flag to avoid repeated resets.
    ref.listen<AsyncValue<MembersData>>(membersNotifierProvider,
        (prev, next) {
      if (_isEditMode && prev?.valueOrNull == null && next.valueOrNull != null) {
        _resolveEditFields(next.valueOrNull!.members);
      }
    });

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppTheme.radiusLG),
            ),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // ── Drag handle ───────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color:
                            c.textTertiary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(
                            AppTheme.radiusFull),
                      ),
                    ),
                  ),
                ),

                // ── Header ────────────────────────────────────────────────
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _isEditMode
                              ? 'units.form.edit_title'.tr()
                              : 'units.form.create_title'.tr(),
                          style: theme.textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        icon: HugeIcon(
                          icon: HugeIcons.strokeRoundedCancel01,
                          color: c.textSecondary,
                          size: 22,
                        ),
                        onPressed: () =>
                            Navigator.of(context).pop(null),
                        tooltip: 'common.cancel'.tr(),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // ── Scrollable form body ───────────────────────────────────
                Expanded(
                  child: membersAsync.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(
                              20, 20, 20, 0),
                          children: [
                            // ── Name ────────────────────────────────────
                            _SectionLabel(
                              icon:
                                  HugeIcons.strokeRoundedPencilEdit01,
                              label: 'units.form.name_label'.tr(),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _nameController,
                              textCapitalization:
                                  TextCapitalization.words,
                              decoration: InputDecoration(
                                hintText: 'units.form.name_hint'.tr(),
                                hintStyle: TextStyle(
                                    color: c.textTertiary),
                                filled: true,
                                fillColor: c.surfaceVariant,
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                      AppTheme.radiusSM),
                                  borderSide:
                                      BorderSide(color: c.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                      AppTheme.radiusSM),
                                  borderSide:
                                      BorderSide(color: c.border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                      AppTheme.radiusSM),
                                  borderSide: const BorderSide(
                                      color: AppColors.primary,
                                      width: 2),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                      AppTheme.radiusSM),
                                  borderSide: const BorderSide(
                                      color: AppColors.error),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                      AppTheme.radiusSM),
                                  borderSide: const BorderSide(
                                      color: AppColors.error, width: 2),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'units.form.name_required'.tr();
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 24),

                            // ── Captain ──────────────────────────────────
                            _SectionLabel(
                              icon: HugeIcons.strokeRoundedUserStar01,
                              label: 'units.form.captain_label'.tr(),
                              required: true,
                            ),
                            const SizedBox(height: 8),
                            _MemberPickerField(
                              hint: 'units.form.captain_hint'.tr(),
                              selected: _captain,
                              onTap: () =>
                                  _pickCaptain(allMembers),
                            ),

                            const SizedBox(height: 20),

                            // ── Secretary ────────────────────────────────
                            _SectionLabel(
                              icon: HugeIcons
                                  .strokeRoundedUserAccount,
                              label: 'units.form.secretary_label'.tr(),
                              required: true,
                            ),
                            const SizedBox(height: 8),
                            _MemberPickerField(
                              hint: 'units.form.secretary_hint'.tr(),
                              selected: _secretary,
                              onTap: () =>
                                  _pickSecretary(allMembers),
                            ),

                            const SizedBox(height: 20),

                            // ── Advisor ──────────────────────────────────
                            _SectionLabel(
                              icon: HugeIcons.strokeRoundedUserShield01,
                              label: 'units.form.advisor_label'.tr(),
                              required: true,
                            ),
                            const SizedBox(height: 8),
                            _MemberPickerField(
                              hint: 'units.form.advisor_hint'.tr(),
                              selected: _advisor,
                              onTap: () =>
                                  _pickAdvisor(allMembers),
                            ),

                            const SizedBox(height: 20),

                            // ── Substitute Advisor ───────────────────────
                            _SectionLabel(
                              icon: HugeIcons
                                  .strokeRoundedUserStar01,
                              label: 'units.form.substitute_advisor_label'.tr(),
                            ),
                            const SizedBox(height: 8),
                            _MemberPickerField(
                              hint: 'units.form.substitute_advisor_hint'.tr(),
                              selected: _substituteAdvisor,
                              optional: true,
                              onTap: () =>
                                  _pickSubstituteAdvisor(allMembers),
                              onClear: _substituteAdvisor != null
                                  ? () => setState(
                                      () => _substituteAdvisor = null)
                                  : null,
                            ),

                            const SizedBox(height: 28),

                            // ── Members ───────────────────────────────────
                            Row(
                              children: [
                                HugeIcon(
                                  icon: HugeIcons
                                      .strokeRoundedUserGroup,
                                  color: AppColors.primary,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'units.form.members_section'.tr(),
                                  style: theme.textTheme.titleMedium
                                      ?.copyWith(
                                          fontWeight: FontWeight.w600),
                                ),
                                const Spacer(),
                                TextButton.icon(
                                  onPressed: allMembers.isEmpty
                                      ? null
                                      : () => _pickMembers(allMembers),
                                  icon: const Icon(
                                    Icons.add_rounded,
                                    size: 18,
                                  ),
                                  label:
                                      Text('units.form.add_member_button'.tr()),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            if (_members.isEmpty)
                              _EmptyMembersPlaceholder(
                                onTap: allMembers.isEmpty
                                    ? null
                                    : () => _pickMembers(allMembers),
                              )
                            else
                              _MembersChipGrid(
                                members: _members,
                                onRemove: (m) => setState(
                                    () => _members.remove(m)),
                              ),

                            const SizedBox(height: 32),
                          ],
                        ),
                ),

                // ── Bottom action bar ─────────────────────────────────────
                _BottomActionBar(
                  isEditMode: _isEditMode,
                  isSaving: _isSaving,
                  onCancel: () => Navigator.of(context).pop(null),
                  onSave: _isSaving ? null : _save,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
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

  List<ClubMember> get _eligible =>
      widget.members
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
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: c.textTertiary.withValues(alpha: 0.3),
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
            child:             TextField(
              controller: _searchController,
              autofocus: false,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'units.form.search_hint'.tr(),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: _searchController.clear,
                        splashRadius: 16,
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusSM),
                  borderSide: BorderSide(color: c.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusSM),
                  borderSide: BorderSide(color: c.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusSM),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 2),
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
                        Icon(Icons.search_off_rounded,
                            size: 48, color: c.textTertiary),
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
                      return ListTile(
                        minTileHeight: 52,
                        leading: _MemberAvatar(member: m, size: 36),
                        title: Text(
                          m.fullName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isSelected
                                ? AppColors.primary
                                : c.text,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                        subtitle: m.clubRole != null
                            ? Text(
                                m.clubRole!,
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: c.textSecondary),
                              )
                            : null,
                        trailing: isSelected
                            ? const Icon(
                                Icons.check_rounded,
                                color: AppColors.primary,
                                size: 20,
                              )
                            : null,
                        onTap: () => Navigator.of(context).pop(m),
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

class _MultiMemberPickerSheetState
    extends State<_MultiMemberPickerSheet> {
  final _searchController = TextEditingController();
  late Set<String> _selected;
  late List<ClubMember> _filtered;

  List<ClubMember> get _eligible =>
      widget.members
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
    final result = widget.members
        .where((m) => _selected.contains(m.userId))
        .toList();
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
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: c.textTertiary.withValues(alpha: 0.3),
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusFull),
                ),
              ),
            ),
          ),

          // Header row
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'units.form.add_member_button'.tr(),
                              style: theme.textTheme.headlineSmall,
                            ),
                            if (_selected.isNotEmpty)
                              Text(
                                _selected.length == 1
                                    ? tr('units.form.selected_count_one',
                                        namedArgs: {
                                          'count': '${_selected.length}'
                                        })
                                    : tr('units.form.selected_count_other',
                                        namedArgs: {
                                          'count': '${_selected.length}'
                                        }),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                      FilledButton(
                        onPressed: _confirm,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSM),
                          ),
                        ),
                        child: Text('units.form.done'.tr()),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Search field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child:             TextField(
              controller: _searchController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'units.form.search_hint'.tr(),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: _searchController.clear,
                        splashRadius: 16,
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusSM),
                  borderSide: BorderSide(color: c.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusSM),
                  borderSide: BorderSide(color: c.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusSM),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 2),
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
                        Icon(Icons.search_off_rounded,
                            size: 48, color: c.textTertiary),
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
                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (_) => _toggle(m),
                        activeColor: AppColors.primary,
                        secondary: _MemberAvatar(member: m, size: 36),
                        title: Text(
                          m.fullName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isSelected ? AppColors.primary : c.text,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                        subtitle: m.clubRole != null
                            ? Text(
                                m.clubRole!,
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: c.textSecondary),
                              )
                            : null,
                        controlAffinity: ListTileControlAffinity.trailing,
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

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Label row shown above each form section (icon + text + optional asterisk).
class _SectionLabel extends StatelessWidget {
  final HugeIconData icon;
  final String label;
  final bool required;

  const _SectionLabel({
    required this.icon,
    required this.label,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        HugeIcon(
          icon: icon,
          color: AppColors.primary,
          size: 18,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        if (required) ...[
          const SizedBox(width: 4),
          Text(
            '*',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

/// Tappable row that shows the selected [ClubMember] or a placeholder hint.
class _MemberPickerField extends StatelessWidget {
  final String hint;
  final ClubMember? selected;
  final bool optional;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  const _MemberPickerField({
    required this.hint,
    required this.onTap,
    this.selected,
    this.optional = false,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final theme = Theme.of(context);
    final hasValue = selected != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusSM),
          border: Border.all(color: c.border),
          boxShadow: [
            BoxShadow(
              color: c.shadow,
              offset: const Offset(0, 3),
              blurRadius: 20,
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            if (hasValue) ...[
              _MemberAvatar(member: selected!, size: 32),
              const SizedBox(width: 12),
            ] else ...[
              Icon(
                Icons.person_outline_rounded,
                size: 20,
                color: c.textSecondary,
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasValue ? selected!.fullName : hint,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: hasValue ? c.text : c.textTertiary,
                    ),
                  ),
                  if (hasValue && selected!.clubRole != null)
                    Text(
                      selected!.clubRole!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: c.textSecondary),
                    ),
                ],
              ),
            ),
            if (hasValue && onClear != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: c.textTertiary,
                ),
              )
            else
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: c.textSecondary,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}

/// Circular avatar with initials fallback.
class _MemberAvatar extends StatelessWidget {
  final ClubMember member;
  final double size;

  const _MemberAvatar({required this.member, required this.size});

  @override
  Widget build(BuildContext context) {
    if (member.avatar != null && member.avatar!.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: NetworkImage(member.avatar!),
        backgroundColor: AppColors.primaryLight,
      );
    }
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.primaryLight,
      child: Text(
        member.initials,
        style: TextStyle(
          fontSize: size * 0.35,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryDark,
        ),
      ),
    );
  }
}

/// Displayed when no members have been added yet.
class _EmptyMembersPlaceholder extends StatelessWidget {
  final VoidCallback? onTap;

  const _EmptyMembersPlaceholder({this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: c.surfaceVariant,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(
            color: c.borderLight,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.group_add_outlined,
              size: 36,
              color: c.textTertiary,
            ),
            const SizedBox(height: 8),
            Text(
              'units.form.empty_members_title'.tr(),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              'units.form.empty_members_subtitle'.tr(),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: c.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wrap of removable chips — one per selected member.
class _MembersChipGrid extends StatelessWidget {
  final List<ClubMember> members;
  final void Function(ClubMember) onRemove;

  const _MembersChipGrid({
    required this.members,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: members.map((m) {
        return Chip(
          avatar: _MemberAvatar(member: m, size: 24),
          label: Text(
            m.fullName,
            style: const TextStyle(fontSize: 13),
          ),
          deleteIcon: const Icon(Icons.close_rounded, size: 16),
          onDeleted: () => onRemove(m),
          backgroundColor:
              AppColors.primaryLight,
          deleteIconColor: AppColors.primaryDark,
          labelStyle: const TextStyle(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.w500,
          ),
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(AppTheme.radiusFull),
            side: const BorderSide(color: Colors.transparent),
          ),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        );
      }).toList(),
    );
  }
}

/// Sticky bottom bar with Cancel and Save/Create buttons.
class _BottomActionBar extends StatelessWidget {
  final bool isEditMode;
  final bool isSaving;
  final VoidCallback? onCancel;
  final VoidCallback? onSave;

  const _BottomActionBar({
    required this.isEditMode,
    required this.isSaving,
    required this.onCancel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomPad),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(
          top: BorderSide(color: c.border),
        ),
      ),
      child: Row(
        children: [
          // Cancel button
          Expanded(
              child: OutlinedButton(
              onPressed: isSaving ? null : onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: c.textSecondary,
                side: BorderSide(color: c.border),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusSM),
                ),
              ),
              child: Text('common.cancel'.tr()),
            ),
          ),
          const SizedBox(width: 12),
          // Save / Create button
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: isSaving ? null : onSave,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor:
                    AppColors.primaryLight,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusSM),
                ),
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white),
                      ),
                    )
                  : Text(isEditMode
                      ? 'common.save'.tr()
                      : 'units.form.create'.tr()),
            ),
          ),
        ],
      ),
    );
  }
}
