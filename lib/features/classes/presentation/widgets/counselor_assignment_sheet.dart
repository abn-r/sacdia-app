import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/role_utils.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_dialog.dart';
import '../../../../core/widgets/sac_member_avatar.dart';
import '../../../../core/widgets/sac_pressable.dart';
import '../../../../core/widgets/sac_sheet.dart';
import '../../../members/domain/entities/club_member.dart';
import '../../domain/entities/class_counselor_assignment.dart';
import '../providers/classes_providers.dart';
import '../utils/counselor_rows.dart';

/// Message for a failed assignment call. Reads only the business `code`
/// (`errors.class_counselor_*`); the server's own text is never shown.
String assignmentErrorMessage(ClassCounselorAssignmentActionState state) {
  final code = state.errorCode;
  if (code != null && code.isNotEmpty) {
    final key = 'errors.${code.toLowerCase()}';
    final message = key.tr();
    if (message != key) return message;
  }
  return 'common.error_generic'.tr();
}

/// Sheet to set the counselor and the sub-counselor of one class. «Guardar»
/// creates, replaces or revokes whatever changed; «Quitar» revokes both.
class CounselorAssignmentSheet extends ConsumerStatefulWidget {
  const CounselorAssignmentSheet({
    super.key,
    required this.query,
    required this.row,
    required this.candidates,
    required this.canAssign,
    required this.canRevoke,
  });

  final ClassCounselorAssignmentsQuery query;
  final ClassCounselorRow row;

  /// People that can be responsible: see `isAssignableResponsible`.
  final List<ClubMember> candidates;
  final bool canAssign;
  final bool canRevoke;

  @override
  ConsumerState<CounselorAssignmentSheet> createState() =>
      _CounselorAssignmentSheetState();
}

class _CounselorAssignmentSheetState
    extends ConsumerState<CounselorAssignmentSheet> {
  late String? _counselorId = widget.row.primary?.userId;
  late String? _assistantId = widget.row.assistant?.userId;
  bool _isBusy = false;
  String? _error;

  late final Map<String, String> _names = {
    for (final a in [widget.row.primary, widget.row.assistant])
      if (a != null) a.userId: counselorPersonName(a.user, a.userId),
    for (final m in widget.candidates) m.userId: m.fullName,
  };

  String? _nameOf(String? userId) => userId == null ? null : _names[userId];

  ClassCounselorAssignmentsNotifier get _notifier => ref.read(
        classCounselorAssignmentsNotifierProvider(widget.query).notifier,
      );

  ClassCounselorAssignmentActionState get _state =>
      ref.read(classCounselorAssignmentsNotifierProvider(widget.query));

  Future<void> _pick({required bool isCounselor}) async {
    final taken = isCounselor ? _assistantId : _counselorId;
    final picked = await showSacSheet<_PickResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.sac.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXL)),
      ),
      builder: (_) => _PersonPickerSheet(
        title: isCounselor
            ? 'classes.grouped.assign.picker_counselor'.tr()
            : 'classes.grouped.assign.picker_assistant'.tr(),
        candidates: widget.candidates.where((m) => m.userId != taken).toList(),
        selectedId: isCounselor ? _counselorId : _assistantId,
        allowNone: !isCounselor,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _error = null;
      if (isCounselor) {
        _counselorId = picked.userId ?? _counselorId;
      } else {
        _assistantId = picked.userId;
      }
    });
  }

  Future<void> _save() async {
    if (_counselorId != null && _counselorId == _assistantId) {
      setState(() => _error = 'classes.grouped.assign.same_person'.tr());
      return;
    }
    final plan = planAssignmentChange(
      widget.row,
      counselorId: _counselorId,
      assistantId: _assistantId,
    );
    if (plan.isEmpty) {
      setState(() => _error = 'classes.grouped.assign.no_changes'.tr());
      return;
    }

    setState(() {
      _isBusy = true;
      _error = null;
    });

    // Revoke first: a person cannot be swapped in place and the backend
    // allows one counselor and one sub-counselor per class.
    final revoked = <ClassCounselorAssignment>[];
    var ok = true;
    for (final a in plan.revokes) {
      ok = await _notifier.revoke(assignmentId: a.assignmentId);
      if (!ok) break;
      revoked.add(a);
    }
    if (ok) {
      for (final (userId, responsibility) in plan.creates) {
        ok = await _notifier.create(
          userId: userId,
          classId: widget.row.classId,
          ecclesiasticalYearId: widget.query.yearId,
          responsibilityType: responsibility,
        );
        if (!ok) break;
      }
    }

    if (!ok) {
      final message = assignmentErrorMessage(_state);
      // Do not leave the class without the people it had.
      for (final a in revoked) {
        await _notifier.create(
          userId: a.userId,
          classId: widget.row.classId,
          ecclesiasticalYearId: widget.query.yearId,
          responsibilityType: a.responsibilityType,
        );
      }
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _error = message;
      });
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop(_SheetOutcome.saved);
  }

  Future<void> _remove() async {
    final confirmed = await SacDialog.show(
      context,
      title: 'classes.grouped.assign.remove_title'.tr(),
      content: 'classes.grouped.assign.remove_body'
          .tr(namedArgs: {'className': widget.row.name}),
      confirmLabel: 'classes.grouped.assign.remove'.tr(),
      cancelLabel: 'common.cancel'.tr(),
      confirmIsDestructive: true,
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _isBusy = true;
      _error = null;
    });
    for (final a in [widget.row.primary, widget.row.assistant]) {
      if (a == null) continue;
      final ok = await _notifier.revoke(assignmentId: a.assignmentId);
      if (!ok) {
        final message = assignmentErrorMessage(_state);
        if (!mounted) return;
        setState(() {
          _isBusy = false;
          _error = message;
        });
        return;
      }
    }
    if (!mounted) return;
    Navigator.of(context).pop(_SheetOutcome.removed);
  }

  @override
  Widget build(BuildContext context) {
    // Listen so the autoDispose notifier lives while the sheet is open: the
    // calls below read it across awaits.
    ref.watch(classCounselorAssignmentsNotifierProvider(widget.query));
    final c = context.sac;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final canRemove = widget.canRevoke && widget.row.hasAnyAssignment;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SacSheetHeader(
              title: widget.row.name,
              subtitle: 'classes.grouped.assign.sheet_subtitle'.tr(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PersonField(
                    key: const ValueKey('assign-field-counselor'),
                    label: 'classes.grouped.assign.field_counselor'.tr(),
                    name: _nameOf(_counselorId),
                    onTap: _isBusy || !widget.canAssign
                        ? null
                        : () => _pick(isCounselor: true),
                  ),
                  const SizedBox(height: 10),
                  _PersonField(
                    key: const ValueKey('assign-field-assistant'),
                    label: 'classes.grouped.assign.field_assistant'.tr(),
                    name: _nameOf(_assistantId),
                    onTap: _isBusy || !widget.canAssign
                        ? null
                        : () => _pick(isCounselor: false),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        key: const ValueKey('assign-error'),
                        style: TextStyle(
                          fontSize: SacFontSize.bodyMedium,
                          color: c.error,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      if (canRemove) ...[
                        SacButton(
                          key: const ValueKey('assign-remove'),
                          variant: SacButtonVariant.outline,
                          fullWidth: false,
                          text: 'classes.grouped.assign.remove'.tr(),
                          textColor: c.onErrorContainer,
                          onPressed: _isBusy ? null : _remove,
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (widget.canAssign)
                        Expanded(
                          child: SacButton.primary(
                            key: const ValueKey('assign-save'),
                            text: 'classes.grouped.assign.save'.tr(),
                            isLoading: _isBusy,
                            onPressed: _isBusy ? null : _save,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What the sheet did, so the screen can say it.
enum _SheetOutcome { saved, removed }

/// Result of the person picker: [userId] null means "nobody".
class _PickResult {
  const _PickResult(this.userId);
  final String? userId;
}

/// Outcome of [CounselorAssignmentSheet] as a message key, or null when the
/// sheet was dismissed without changes.
String? assignmentOutcomeMessage(Object? outcome) {
  if (outcome == _SheetOutcome.saved) {
    return 'classes.grouped.assign.saved'.tr();
  }
  if (outcome == _SheetOutcome.removed) {
    return 'classes.grouped.assign.removed'.tr();
  }
  return null;
}

class _PersonField extends StatelessWidget {
  const _PersonField({
    super.key,
    required this.label,
    required this.name,
    required this.onTap,
  });

  final String label;
  final String? name;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Semantics(
      button: true,
      label: '$label: ${name ?? 'classes.grouped.assign.pick'.tr()}',
      excludeSemantics: true,
      child: SacInkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(AppTheme.radiusSM),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: SacFontSize.labelSmall,
                        color: c.textSecondary,
                      ),
                    ),
                    Text(
                      name ?? 'classes.grouped.assign.pick'.tr(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: SacFontSize.titleMedium,
                        color: name == null ? c.textTertiary : c.text,
                      ),
                    ),
                  ],
                ),
              ),
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                size: 18,
                color: c.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonPickerSheet extends StatelessWidget {
  const _PersonPickerSheet({
    required this.title,
    required this.candidates,
    required this.selectedId,
    required this.allowNone,
  });

  final String title;
  final List<ClubMember> candidates;
  final String? selectedId;

  /// Offers «Sin subconsejero» to clear the role.
  final bool allowNone;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.7;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SacSheetHeader(title: title),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                if (allowNone)
                  _PickerTile(
                    key: const ValueKey('assign-pick-none'),
                    title: 'classes.grouped.assign.picker_none'.tr(),
                    isSelected: selectedId == null,
                    onTap: () => Navigator.of(context).pop(
                      const _PickResult(null),
                    ),
                  ),
                for (final m in candidates)
                  _PickerTile(
                    key: ValueKey('assign-pick-${m.userId}'),
                    leading: SacMemberAvatar(
                      imageUrl: m.avatar,
                      name: m.fullName,
                      size: 32,
                    ),
                    title: m.fullName,
                    subtitle: RoleUtils.translate(
                      m.clubRole,
                      gender: m.gender,
                    ),
                    isSelected: m.userId == selectedId,
                    onTap: () =>
                        Navigator.of(context).pop(_PickResult(m.userId)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    super.key,
    required this.title,
    required this.isSelected,
    required this.onTap,
    this.leading,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return SacInkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 12)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: SacFontSize.titleMedium,
                        fontWeight: FontWeight.w600,
                        color: c.text,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: SacFontSize.bodySmall,
                          color: c.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (isSelected)
                HugeIcon(
                  icon: HugeIcons.strokeRoundedTick02,
                  size: 20,
                  color: c.text,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
