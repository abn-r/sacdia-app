import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/page_transitions.dart';
import 'package:sacdia_app/core/errors/user_error_message.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/core/widgets/sac_text_field.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/widgets/status_progress/status_progress.dart';

import '../../../members/domain/entities/club_member.dart';
import '../../../members/domain/usecases/get_club_members.dart';
import '../../../members/presentation/providers/members_providers.dart';
import '../../domain/entities/unit.dart';
import '../../domain/usecases/get_unit_detail.dart';
import '../providers/units_providers.dart';
import '../widgets/unit_form_rows.dart';
import '../widgets/unit_member_picker_sheets.dart';

final _unitFormDetailProvider =
    FutureProvider.autoDispose.family<Unit, int>((ref, unitId) async {
  final ctx = await ref.watch(clubContextProvider.future);
  if (ctx == null) {
    throw Exception('units.form.club_context_error'.tr());
  }

  final result = await ref.read(getUnitDetailUseCaseProvider).call(
        GetUnitDetailParams(clubId: ctx.clubId, unitId: unitId),
      );

  return result.fold(
    (failure) => throw Exception(failure.message),
    (unit) => unit,
  );
});

final _unitFormMembersProvider =
    FutureProvider.autoDispose.family<List<ClubMember>, int>(
  (ref, sectionId) async {
    final ctx = await ref.watch(clubContextProvider.future);
    if (ctx == null) return const <ClubMember>[];

    final result = await ref.read(getClubMembersUseCaseProvider).call(
          GetClubMembersParams(clubId: ctx.clubId, sectionId: sectionId),
        );

    return result.fold(
      (failure) => throw Exception(failure.message),
      (members) => members,
    );
  },
);

/// Members shown before the "Ver los N restantes" row.
const int _kCollapsedMembers = 4;

/// Opens the full-screen unit create/edit form.
///
/// Pass [unit] to enter edit mode. Returns `true` when a unit was created or
/// updated so the caller can refresh; `null` when dismissed without saving.
Future<bool?> openUnitForm(BuildContext context, {Unit? unit}) {
  // Root navigator: the form covers the whole screen, tab bar included.
  return Navigator.of(context, rootNavigator: true).push<bool>(
    SacSharedAxisRoute<bool>(
      fullscreenDialog: true,
      builder: (_) => UnitFormView(unit: unit),
    ),
  );
}

enum _UnitRole { captain, secretary, advisor, substituteAdvisor }

class UnitFormView extends ConsumerStatefulWidget {
  const UnitFormView({super.key, this.unit});

  final Unit? unit;

  @override
  ConsumerState<UnitFormView> createState() => _UnitFormViewState();
}

class _UnitFormViewState extends ConsumerState<UnitFormView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  final Map<_UnitRole, ClubMember?> _roles = {
    for (final role in _UnitRole.values) role: null,
  };
  List<ClubMember> _members = [];

  bool _isSaving = false;
  bool _didResolveEditFields = false;
  bool _submitAttempted = false;
  bool _showAllMembers = false;

  bool get _isEditMode => widget.unit != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) _nameController.text = widget.unit!.name;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // ── Edit-mode pre-population ────────────────────────────────────────────────

  /// Finds the [ClubMember]s matching the ids stored in [unit]. Runs once,
  /// after the members list is available.
  void _resolveEditFields(Unit unit, List<ClubMember> allMembers) {
    if (!_isEditMode || _didResolveEditFields || !mounted) return;

    ClubMember? find(String? id) =>
        id == null ? null : allMembers.where((m) => m.userId == id).firstOrNull;

    // UnitMember.id maps to ClubMember.userId.
    final unitMemberIds = unit.members.map((um) => um.id).toSet();

    setState(() {
      _didResolveEditFields = true;
      _roles[_UnitRole.captain] = find(unit.captainId);
      _roles[_UnitRole.secretary] = find(unit.secretaryId);
      _roles[_UnitRole.advisor] = find(unit.advisorId);
      _roles[_UnitRole.substituteAdvisor] = find(unit.substituteAdvisorId);
      _members =
          allMembers.where((m) => unitMemberIds.contains(m.userId)).toList();
    });
  }

  // ── Pickers ─────────────────────────────────────────────────────────────────

  /// Ids held by a role other than [except]: a person cannot hold two roles.
  Set<String> _idsOfOtherRoles(_UnitRole except) => {
        for (final entry in _roles.entries)
          if (entry.key != except && entry.value != null) entry.value!.userId,
      };

  Set<String> get _assignedRoleIds => {
        for (final m in _roles.values)
          if (m != null) m.userId,
      };

  String _pickerTitle(_UnitRole role) => switch (role) {
        _UnitRole.captain => 'units.form.picker_captain'.tr(),
        _UnitRole.secretary => 'units.form.picker_secretary'.tr(),
        _UnitRole.advisor => 'units.form.picker_advisor'.tr(),
        _UnitRole.substituteAdvisor =>
          'units.form.picker_substitute_advisor'.tr(),
      };

  Future<void> _pickRole(_UnitRole role, List<ClubMember> allMembers) async {
    final picked = await showUnitMemberPickerSheet(
      context: context,
      members: allMembers,
      title: _pickerTitle(role),
      currentUserId: _roles[role]?.userId,
      excludeIds: _idsOfOtherRoles(role),
    );
    if (picked != null && mounted) {
      setState(() {
        _roles[role] = picked;
        // A leader is never also a plain member of the unit.
        _members.removeWhere((m) => m.userId == picked.userId);
      });
    }
  }

  Future<void> _pickMembers(List<ClubMember> allMembers) async {
    final picked = await showUnitMultiMemberPickerSheet(
      context: context,
      members: allMembers,
      selectedIds: _members.map((m) => m.userId).toSet(),
      excludeIds: _assignedRoleIds,
    );
    if (picked != null && mounted) setState(() => _members = picked);
  }

  // ── Save ────────────────────────────────────────────────────────────────────

  /// Maps the club type name (from [ClubContext]) to its backend id:
  /// 1=Aventureros, 2=Conquistadores, 3=Guías Mayores. Falls back to 2.
  int _clubTypeIdFromName(String? name) {
    if (name == null) return 2;
    final lower = name.toLowerCase();
    if (lower.contains('aventurer')) return 1;
    if (lower.contains('conquistador')) return 2;
    if (lower.contains('guía') || lower.contains('guia')) return 3;
    return 2;
  }

  bool get _hasRequiredRoles =>
      _roles[_UnitRole.captain] != null &&
      _roles[_UnitRole.secretary] != null &&
      _roles[_UnitRole.advisor] != null;

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _submitAttempted = true);
    final nameValid = _formKey.currentState!.validate();
    if (!nameValid || !_hasRequiredRoles) return;

    setState(() => _isSaving = true);

    final notifier = ref.read(unitsNotifierProvider.notifier);
    final name = _nameController.text.trim();
    final captain = _roles[_UnitRole.captain]!;
    final secretary = _roles[_UnitRole.secretary]!;
    final advisor = _roles[_UnitRole.advisor]!;
    final substitute = _roles[_UnitRole.substituteAdvisor];
    final memberIds = _members.map((m) => m.userId).toList();

    bool success;

    if (_isEditMode) {
      success = await notifier.updateUnit(
        unitId: widget.unit!.id,
        name: name,
        captainId: captain.userId,
        secretaryId: secretary.userId,
        advisorId: advisor.userId,
        substituteAdvisorId: substitute?.userId,
        memberUserIds: memberIds,
      );
    } else {
      final ctx = await ref.read(clubContextProvider.future);
      if (ctx == null) {
        if (mounted) {
          SacSnackBar.show(context, 'units.form.club_context_error'.tr());
          setState(() => _isSaving = false);
        }
        return;
      }

      success = await notifier.createUnit(
        name: name,
        captainId: captain.userId,
        secretaryId: secretary.userId,
        advisorId: advisor.userId,
        substituteAdvisorId: substitute?.userId,
        clubTypeId: _clubTypeIdFromName(ctx.clubTypeName),
        clubSectionId: ctx.sectionId,
        memberUserIds: memberIds,
      );
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      Navigator.of(context).pop(true);
    } else {
      final errorMsg = ref.read(unitsNotifierProvider).errorMessage ??
          'common.error_generic'.tr();
      SacSnackBar.show(context, errorMsg, isError: true);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    final unitDetailAsync = _isEditMode
        ? ref.watch(_unitFormDetailProvider(widget.unit!.id))
        : null;
    final editUnit = unitDetailAsync?.value ?? widget.unit;

    final clubContextAsync = ref.watch(clubContextProvider);
    final targetSectionId =
        editUnit?.clubSectionId ?? clubContextAsync.value?.sectionId;

    final membersAsync = targetSectionId == null
        ? const AsyncValue<List<ClubMember>>.loading()
        : ref.watch(_unitFormMembersProvider(targetSectionId));
    final allMembers = membersAsync.value ?? const <ClubMember>[];

    final canResolveEditFields =
        _isEditMode && editUnit != null && unitDetailAsync?.hasValue == true;
    if (canResolveEditFields &&
        !_didResolveEditFields &&
        membersAsync.hasValue) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _didResolveEditFields) return;
        _resolveEditFields(editUnit, membersAsync.value ?? const []);
      });
    }

    final isLoadingFormData =
        membersAsync.isLoading || (unitDetailAsync?.isLoading ?? false);
    final formLoadError = unitDetailAsync?.hasError == true
        ? unitDetailAsync!.error
        : membersAsync.hasError
            ? membersAsync.error
            : null;
    final isReady = !isLoadingFormData &&
        formLoadError == null &&
        (!_isEditMode || _didResolveEditFields);

    return PopScope(
      canPop: !_isSaving,
      child: Scaffold(
        backgroundColor: c.background,
        appBar: _buildTopBar(context, canSave: isReady),
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: isLoadingFormData
              ? const Center(child: SacLoading())
              : formLoadError != null
                  ? SacErrorState(
                      title: userErrorMessage(formLoadError),
                      onRetry: () {
                        if (_isEditMode) {
                          ref.invalidate(
                            _unitFormDetailProvider(widget.unit!.id),
                          );
                        }
                        if (targetSectionId != null) {
                          ref.invalidate(
                            _unitFormMembersProvider(targetSectionId),
                          );
                        }
                      },
                    )
                  : _buildBody(allMembers),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildTopBar(
    BuildContext context, {
    required bool canSave,
  }) {
    final c = context.sac;
    final accent = SacAccent.of(context);
    final barText = TextButton.styleFrom(
      minimumSize: const Size(44, 44),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      textStyle: const TextStyle(fontSize: SacFontSize.titleMedium),
    );

    return SacTopBar(
      title: _isEditMode
          ? 'units.form.edit_title'.tr()
          : 'units.form.create_title'.tr(),
      centerTitle: true,
      automaticallyImplyLeading: false,
      leadingWidth: 104,
      leading: Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          key: const ValueKey('unit-form-cancel'),
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          style: barText.copyWith(
            foregroundColor: WidgetStatePropertyAll(accent.color),
          ),
          child: Text('common.cancel'.tr()),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: _isSaving
              ? const SizedBox(
                  width: 72,
                  child: Center(child: SacLoadingSmall()),
                )
              : TextButton(
                  key: const ValueKey('unit-form-save'),
                  onPressed: canSave ? _save : null,
                  style: barText.copyWith(
                    foregroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.disabled)
                          ? c.textTertiary
                          : accent.color,
                    ),
                    textStyle: const WidgetStatePropertyAll(
                      TextStyle(
                        fontSize: SacFontSize.titleMedium,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  child: Text(
                    _isEditMode ? 'common.save'.tr() : 'units.form.create'.tr(),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildBody(List<ClubMember> allMembers) {
    final canPick = allMembers.isNotEmpty;

    return Form(
      key: _formKey,
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(
          0,
          8,
          0,
          32 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: SacTextField(
              controller: _nameController,
              label: 'units.form.name_label'.tr(),
              hint: 'units.form.name_hint'.tr(),
              textCapitalization: TextCapitalization.words,
              enabled: !_isSaving,
              textInputAction: TextInputAction.done,
              onTapOutside: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'units.form.name_required'.tr()
                  : null,
            ),
          ),
          SacGroupedSection(
            label: 'units.form.responsibles_section'.tr(),
            action: const SizedBox.shrink(),
            children: [
              _roleRow(
                _UnitRole.captain,
                HugeIcons.strokeRoundedUserStar01,
                'units.form.captain_label'.tr(),
                'units.form.captain_required'.tr(),
                allMembers,
                canPick,
              ),
              _roleRow(
                _UnitRole.secretary,
                HugeIcons.strokeRoundedUserAccount,
                'units.form.secretary_label'.tr(),
                'units.form.secretary_required'.tr(),
                allMembers,
                canPick,
              ),
              _roleRow(
                _UnitRole.advisor,
                HugeIcons.strokeRoundedUserShield01,
                'units.form.advisor_label'.tr(),
                'units.form.advisor_required'.tr(),
                allMembers,
                canPick,
              ),
              _roleRow(
                _UnitRole.substituteAdvisor,
                HugeIcons.strokeRoundedUser,
                'units.form.substitute_advisor_label'.tr(),
                null,
                allMembers,
                canPick,
              ),
            ],
          ),
          _buildMembersGroup(allMembers, canPick),
        ],
      ),
    );
  }

  Widget _roleRow(
    _UnitRole role,
    HugeIconData icon,
    String label,
    String? requiredError,
    List<ClubMember> allMembers,
    bool canPick,
  ) {
    final selected = _roles[role];
    final isOptional = requiredError == null;
    return UnitFormRoleRow(
      icon: icon,
      label: label,
      placeholder: isOptional
          ? 'units.form.optional'.tr()
          : 'units.form.pick_member'.tr(),
      selected: selected,
      errorText: _submitAttempted && selected == null ? requiredError : null,
      onTap: _isSaving || !canPick ? null : () => _pickRole(role, allMembers),
      onClear: isOptional && !_isSaving
          ? () => setState(() => _roles[role] = null)
          : null,
    );
  }

  Widget _buildMembersGroup(List<ClubMember> allMembers, bool canPick) {
    final visible =
        _showAllMembers ? _members : _members.take(_kCollapsedMembers).toList();
    final remaining = _members.length - visible.length;

    return SacGroupedSection(
      label: 'units.form.members_section'.tr(),
      count: _members.length,
      children: [
        UnitFormAddMembersRow(
          onTap: _isSaving || !canPick ? null : () => _pickMembers(allMembers),
        ),
        for (final m in visible)
          UnitFormMemberRow(
            key: ValueKey('unit-form-member-${m.userId}'),
            member: m,
            onRemove: () => setState(() => _members.remove(m)),
          ),
        if (remaining > 0)
          UnitFormShowMoreRow(
            remaining: remaining,
            onTap: () => setState(() => _showAllMembers = true),
          ),
      ],
    );
  }
}
