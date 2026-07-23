import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/animations/motion_tokens.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/role_utils.dart';
import '../../../../core/widgets/sac_back_button.dart';
import '../../../../core/widgets/sac_card.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../../../core/widgets/sac_text_field.dart';
import '../../../auth/domain/utils/authorization_utils.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../members/domain/entities/club_member.dart';
import '../../../members/presentation/providers/members_providers.dart';
import '../../domain/entities/class_counselor_assignment.dart';
import '../../domain/entities/progressive_class.dart';
import '../providers/classes_providers.dart';
import '../widgets/class_identity_badge.dart';

const _responsibilityTypes = <String>['primary', 'assistant', 'substitute'];

String _normalizeRole(String? role) =>
    role?.trim().toLowerCase().replaceAll(RegExp(r'[\s_]+'), '-') ?? '';

bool _isAssignableResponsible(ClubMember member) {
  if (!member.classCounselorEligible) return false;

  final role = _normalizeRole(member.clubRole);
  return role == 'counselor' ||
      role == 'consejero' ||
      role == 'secretary' ||
      role == 'secretario';
}

String _normalizeClassName(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll('á', 'a')
    .replaceAll('é', 'e')
    .replaceAll('í', 'i')
    .replaceAll('ó', 'o')
    .replaceAll('ú', 'u')
    .replaceAll('ü', 'u');

int _classOrder(ClassCounselorAssignment assignment) {
  if (assignment.clazz.displayOrder > 0) return assignment.clazz.displayOrder;

  switch (_normalizeClassName(assignment.clazz.name)) {
    case 'amigo':
      return 1;
    case 'companero':
      return 2;
    case 'explorador':
      return 3;
    case 'orientador':
      return 4;
    case 'viajero':
      return 5;
    case 'guia':
      return 6;
    default:
      return 999;
  }
}

int _responsibilityOrder(String? value) {
  switch (_normalizeRole(value)) {
    case 'primary':
      return 0;
    case 'assistant':
      return 1;
    case 'substitute':
      return 2;
    default:
      return 3;
  }
}

int _compareAssignments(
  ClassCounselorAssignment a,
  ClassCounselorAssignment b,
) {
  final classOrder = _classOrder(a).compareTo(_classOrder(b));
  if (classOrder != 0) return classOrder;

  final className = a.clazz.name.compareTo(b.clazz.name);
  if (className != 0) return className;

  final responsibility = _responsibilityOrder(a.responsibilityType).compareTo(
    _responsibilityOrder(b.responsibilityType),
  );
  if (responsibility != 0) return responsibility;

  return _safePersonName(a.user, a.userId).compareTo(
    _safePersonName(b.user, b.userId),
  );
}

String _responsibilityLabel(String? value) {
  switch (_normalizeRole(value)) {
    case 'assistant':
      return 'classes.class_assignments.responsibility.assistant'.tr();
    case 'substitute':
      return 'classes.class_assignments.responsibility.substitute'.tr();
    case 'primary':
    default:
      return 'classes.class_assignments.responsibility.primary'.tr();
  }
}

String _safePersonName(ClassCounselorPerson person, String fallback) {
  final displayName = person.displayName.trim();
  if (displayName.isNotEmpty) return displayName;
  if (person.email.trim().isNotEmpty) return person.email.trim();
  return fallback;
}

class ClassCounselorAssignmentsView extends ConsumerWidget {
  final int clubId;
  final int sectionId;
  final int? clubTypeId;
  final int? yearId;

  const ClassCounselorAssignmentsView({
    super.key,
    required this.clubId,
    required this.sectionId,
    this.clubTypeId,
    this.yearId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ClassCounselorAssignmentsQuery(
      clubId: clubId,
      sectionId: sectionId,
      yearId: yearId,
      active: true,
    );
    final assignmentsAsync =
        ref.watch(classCounselorAssignmentsProvider(query));
    final classesAsync = clubTypeId == null
        ? null
        : ref.watch(classesByClubTypeProvider(clubTypeId!));
    final membersAsync = ref.watch(membersNotifierProvider);
    final actionState =
        ref.watch(classCounselorAssignmentsNotifierProvider(query));
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final canAssign = hasAnyPermission(user, const {'club_roles:assign'});
    final canRevoke = hasAnyPermission(user, const {'club_roles:revoke'});

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: sacAutoBackButton(context),
        title: Text('classes.class_assignments.title'.tr()),
      ),
      body: assignmentsAsync.when(
        loading: () => const Center(child: SacLoading()),
        error: (error, _) => _AssignmentsErrorState(
          message: error.toString().replaceFirst('Exception: ', ''),
          onRetry: () =>
              ref.invalidate(classCounselorAssignmentsProvider(query)),
        ),
        data: (assignments) => _AssignmentsBody(
          assignments: assignments,
          canAssign: canAssign,
          canRevoke: canRevoke,
          isActionLoading: actionState.isLoading,
          onRefresh: () async {
            ref.invalidate(classCounselorAssignmentsProvider(query));
            ref.invalidate(membersNotifierProvider);
            if (clubTypeId != null) {
              ref.invalidate(classesByClubTypeProvider(clubTypeId!));
            }
          },
          onAdd: canAssign
              ? () => _openAssignmentSheet(
                    context,
                    ref,
                    query,
                    classesAsync: classesAsync,
                    membersAsync: membersAsync,
                  )
              : null,
          onEdit: canAssign
              ? (assignment) => _openAssignmentSheet(
                    context,
                    ref,
                    query,
                    classesAsync: classesAsync,
                    membersAsync: membersAsync,
                    initialAssignment: assignment,
                  )
              : null,
          onRevoke: canRevoke
              ? (assignment) => _confirmRevoke(
                    context,
                    ref,
                    query,
                    assignment,
                  )
              : null,
        ),
      ),
    );
  }

  Future<void> _openAssignmentSheet(
    BuildContext context,
    WidgetRef ref,
    ClassCounselorAssignmentsQuery query, {
    required AsyncValue<List<ProgressiveClass>>? classesAsync,
    required AsyncValue<MembersData> membersAsync,
    ClassCounselorAssignment? initialAssignment,
  }) async {
    final isEditing = initialAssignment != null;
    final classes = classesAsync?.valueOrNull ?? const <ProgressiveClass>[];
    final candidates = (membersAsync.valueOrNull?.members ??
            const <ClubMember>[])
        .where(_isAssignableResponsible)
        .toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));

    if (!isEditing) {
      if (clubTypeId == null) {
        _showSnack(
          context,
          'classes.class_assignments.no_club_type'.tr(),
          isError: true,
        );
        return;
      }
      if ((classesAsync?.isLoading ?? false) || membersAsync.isLoading) {
        _showSnack(context, 'classes.class_assignments.loading_catalog'.tr());
        return;
      }
      if ((classesAsync?.hasError ?? false) || membersAsync.hasError) {
        _showSnack(
          context,
          'classes.class_assignments.catalog_error'.tr(),
          isError: true,
        );
        return;
      }
      if (classes.isEmpty) {
        _showSnack(
          context,
          'classes.class_assignments.no_classes'.tr(),
          isError: true,
        );
        return;
      }
      if (candidates.isEmpty) {
        _showSnack(
          context,
          'classes.class_assignments.no_candidates'.tr(),
          isError: true,
        );
        return;
      }
    }

    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _ClassCounselorAssignmentSheet(
        query: query,
        classes: classes,
        candidates: candidates,
        initialAssignment: initialAssignment,
      ),
    );

    if (changed == true && context.mounted) {
      _showSnack(
        context,
        isEditing
            ? 'classes.class_assignments.update_success'.tr()
            : 'classes.class_assignments.create_success'.tr(),
      );
    }
  }

  Future<void> _confirmRevoke(
    BuildContext context,
    WidgetRef ref,
    ClassCounselorAssignmentsQuery query,
    ClassCounselorAssignment assignment,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('classes.class_assignments.revoke_title'.tr()),
        content: Text(
          'classes.class_assignments.revoke_body'.tr(namedArgs: {
            'name': _safePersonName(assignment.user, assignment.userId),
            'className': assignment.clazz.name,
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('classes.class_assignments.revoke_confirm'.tr()),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final success = await ref
        .read(classCounselorAssignmentsNotifierProvider(query).notifier)
        .revoke(assignmentId: assignment.assignmentId);

    if (!context.mounted) return;
    final state = ref.read(classCounselorAssignmentsNotifierProvider(query));
    _showSnack(
      context,
      success
          ? 'classes.class_assignments.revoke_success'.tr()
          : (state.errorMessage ?? 'common.error_generic'.tr()),
      isError: !success,
    );
  }
}

class _AssignmentsBody extends StatelessWidget {
  final List<ClassCounselorAssignment> assignments;
  final bool canAssign;
  final bool canRevoke;
  final bool isActionLoading;
  final Future<void> Function() onRefresh;
  final VoidCallback? onAdd;
  final void Function(ClassCounselorAssignment assignment)? onEdit;
  final void Function(ClassCounselorAssignment assignment)? onRevoke;

  const _AssignmentsBody({
    required this.assignments,
    required this.canAssign,
    required this.canRevoke,
    required this.isActionLoading,
    required this.onRefresh,
    this.onAdd,
    this.onEdit,
    this.onRevoke,
  });

  @override
  Widget build(BuildContext context) {
    final sortedAssignments = [...assignments]..sort(_compareAssignments);

    // Agrupa por clase preservando el orden progresivo:
    // la clase es la unidad organizadora de la pantalla.
    final groups = <int, List<ClassCounselorAssignment>>{};
    for (final assignment in sortedAssignments) {
      groups.putIfAbsent(assignment.classId, () => []).add(assignment);
    }

    var itemIndex = 0;
    final children = <Widget>[
      _AssignmentsHeader(
        canAssign: canAssign,
        isActionLoading: isActionLoading,
        onAdd: onAdd,
      ),
    ];

    if (sortedAssignments.isEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 72),
          child: _MessageState(
            icon: HugeIcons.strokeRoundedUserGroup,
            title: 'classes.class_assignments.empty_title'.tr(),
            message: 'classes.class_assignments.empty_body'.tr(),
          ),
        ),
      );
    } else {
      for (final group in groups.values) {
        children.add(
          _ClassGroupHeader(className: group.first.clazz.name),
        );
        for (final assignment in group) {
          children.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _AssignmentTile(
                assignment: assignment,
                index: itemIndex++,
                canEdit: onEdit != null,
                canRevoke: canRevoke && onRevoke != null,
                onEdit: onEdit == null ? null : () => onEdit!(assignment),
                onRevoke:
                    onRevoke == null ? null : () => onRevoke!(assignment),
              ),
            ),
          );
        }
      }
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: children,
      ),
    );
  }
}

class _ClassGroupHeader extends StatelessWidget {
  final String className;

  const _ClassGroupHeader({required this.className});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 18, 2, 10),
      child: Row(
        children: [
          ClassIdentityBadge(
            className: className,
            size: 26,
            logoPadding: 3,
            borderRadius: 8,
            fallbackIcon: HugeIcons.strokeRoundedBookOpen01,
          ),
          const SizedBox(width: 10),
          Text(
            className,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink900,
                  letterSpacing: -0.2,
                ),
          ),
        ],
      ),
    );
  }
}

class _AssignmentsHeader extends StatelessWidget {
  final bool canAssign;
  final bool isActionLoading;
  final VoidCallback? onAdd;

  const _AssignmentsHeader({
    required this.canAssign,
    required this.isActionLoading,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              canAssign
                  ? 'classes.class_assignments.header_body'.tr()
                  : 'classes.class_assignments.readonly_body'.tr(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.ink600,
                    height: 1.35,
                  ),
            ),
          ),
          if (canAssign && onAdd != null) ...[
            const SizedBox(width: 12),
            _AssignmentAddAction(
              isLoading: isActionLoading,
              onTap: isActionLoading ? null : onAdd,
            ),
          ],
        ],
      ),
    );
  }
}

class _AssignmentAddAction extends StatefulWidget {
  final bool isLoading;
  final VoidCallback? onTap;

  const _AssignmentAddAction({
    required this.isLoading,
    this.onTap,
  });

  @override
  State<_AssignmentAddAction> createState() => _AssignmentAddActionState();
}

class _AssignmentAddActionState extends State<_AssignmentAddAction> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value || widget.onTap == null) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final color = enabled ? AppColors.primary : AppColors.ink400;
    final reduce = SacMotion.reduceMotionOf(context);

    return Semantics(
      label: 'classes.class_assignments.add_button'.tr(),
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: (!reduce && _pressed) ? 0.96 : 1,
          duration: SacMotion.press,
          curve: SacMotion.easeOut,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: enabled
                  ? AppColors.primary.withValues(alpha: 0.10)
                  : AppColors.ink50,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.isLoading)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  )
                else
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedAdd01,
                    size: 16,
                    color: color,
                  ),
                const SizedBox(width: 5),
                Text(
                  'classes.class_assignments.add_button'.tr(),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
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

class _AssignmentTile extends StatelessWidget {
  final ClassCounselorAssignment assignment;
  final int index;
  final bool canEdit;
  final bool canRevoke;
  final VoidCallback? onEdit;
  final VoidCallback? onRevoke;

  const _AssignmentTile({
    required this.assignment,
    required this.index,
    required this.canEdit,
    required this.canRevoke,
    this.onEdit,
    this.onRevoke,
  });

  @override
  Widget build(BuildContext context) {
    final personName = _safePersonName(assignment.user, assignment.userId);
    final roleName = assignment.classRoleAssignment?.roleName;
    final classColor = AppColors.classColor(assignment.clazz.name);
    final subtitleParts = <String>[
      if (roleName != null && roleName.isNotEmpty) RoleUtils.translate(roleName),
      _responsibilityLabel(assignment.responsibilityType),
    ];
    final exceptionReason = assignment.exceptionReason?.trim() ?? '';

    return SacCard(
      animate: true,
      animationDelay: Duration(milliseconds: index * 36),
      padding: EdgeInsets.zero,
      onTap: canEdit ? onEdit : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _PersonIdentityMark(person: assignment.user, accent: classColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    personName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink900,
                          letterSpacing: -0.2,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          subtitleParts.join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.ink600,
                                  ),
                        ),
                      ),
                      if (assignment.exceptional) ...[
                        const SizedBox(width: 6),
                        _AssignmentChip(
                          label:
                              'classes.class_assignments.exceptional_chip'.tr(),
                          color: AppColors.accentDark,
                        ),
                      ],
                    ],
                  ),
                  if (assignment.exceptional &&
                      exceptionReason.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 1),
                          child: HugeIcon(
                            icon: HugeIcons.strokeRoundedInformationCircle,
                            size: 13,
                            color: AppColors.accentDark,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            exceptionReason,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: AppColors.accentDark,
                                  fontSize: 11.5,
                                  height: 1.3,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 4),
            if (canEdit || canRevoke)
              Semantics(
                button: true,
                label: 'nav.more_options'.tr(),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => _showActionsSheet(context, personName),
                  child: const SizedBox(
                    width: 34,
                    height: 34,
                    child: Center(
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedMoreHorizontal,
                        size: 18,
                        color: AppColors.ink400,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showActionsSheet(
    BuildContext context,
    String personName,
  ) async {
    final classColor = AppColors.classColor(assignment.clazz.name);

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.ink150,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Identity header: quién y qué asignación
              Row(
                children: [
                  _PersonIdentityMark(
                    person: assignment.user,
                    accent: classColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          personName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(sheetContext)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink900,
                                letterSpacing: -0.3,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            ClassIdentityBadge(
                              className: assignment.clazz.name,
                              size: 18,
                              logoPadding: 2,
                              borderRadius: 6,
                              fallbackIcon:
                                  HugeIcons.strokeRoundedBookOpen01,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '${assignment.clazz.name} · '
                                '${_responsibilityLabel(assignment.responsibilityType)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(sheetContext)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppColors.ink600,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Acciones normales
              if (canEdit)
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.paper,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.ink150),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _SheetAction(
                    icon: HugeIcons.strokeRoundedPencilEdit02,
                    label: 'common.edit'.tr(),
                    tint: AppColors.primary,
                    labelColor: AppColors.ink900,
                    onTap: () => Navigator.of(sheetContext).pop('edit'),
                  ),
                ),
              if (canEdit && canRevoke) const SizedBox(height: 10),

              // Acción destructiva separada (grupo propio, iOS-style)
              if (canRevoke)
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.paper,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.16),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _SheetAction(
                    icon: HugeIcons.strokeRoundedUserRemove01,
                    label: 'classes.class_assignments.revoke_action'.tr(),
                    tint: AppColors.error,
                    labelColor: AppColors.error,
                    onTap: () => Navigator.of(sheetContext).pop('revoke'),
                  ),
                ),
              const SizedBox(height: 12),

              // Cancelar: salida obvia, sin scrim-hunting
              Container(
                decoration: BoxDecoration(
                  color: AppColors.ink50,
                  borderRadius: BorderRadius.circular(18),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => Navigator.of(sheetContext).pop(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Center(
                      child: Text(
                        'common.cancel'.tr(),
                        style: Theme.of(sheetContext)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                              color: AppColors.ink600,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (action == 'edit') onEdit?.call();
    if (action == 'revoke') onRevoke?.call();
  }
}

class _SheetAction extends StatefulWidget {
  final List<List<dynamic>> icon;
  final String label;
  final Color tint;
  final Color labelColor;
  final VoidCallback onTap;

  const _SheetAction({
    required this.icon,
    required this.label,
    required this.tint,
    required this.labelColor,
    required this.onTap,
  });

  @override
  State<_SheetAction> createState() => _SheetActionState();
}

class _SheetActionState extends State<_SheetAction> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = SacMotion.reduceMotionOf(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: (!reduce && _pressed) ? 0.98 : 1,
        duration: SacMotion.press,
        curve: SacMotion.easeOut,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: widget.tint.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: HugeIcon(
                    icon: widget.icon,
                    size: 18,
                    color: widget.tint,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: widget.labelColor,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                      ),
                ),
              ),
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                size: 16,
                color: AppColors.ink400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonIdentityMark extends StatelessWidget {
  final ClassCounselorPerson person;
  final Color accent;

  const _PersonIdentityMark({
    required this.person,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = _safePersonName(person, person.userId);
    final initials = displayName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    final image = person.userImage?.trim();

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.14)),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: image == null || image.isEmpty
          ? Text(
              initials.isEmpty ? '?' : initials,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
            )
          : CachedNetworkImage(
              imageUrl: image,
              fit: BoxFit.cover,
              width: 44,
              height: 44,
              memCacheWidth: 132,
              memCacheHeight: 132,
              errorWidget: (_, __, ___) => Text(
                initials.isEmpty ? '?' : initials,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
    );
  }
}

class _AssignmentChip extends StatelessWidget {
  final String label;
  final Color color;

  const _AssignmentChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _ClassOptionLabel extends StatelessWidget {
  final String className;

  const _ClassOptionLabel({required this.className});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClassIdentityBadge(
          className: className,
          size: 28,
          logoPadding: 3,
          borderRadius: 8,
          fallbackIcon: HugeIcons.strokeRoundedBookOpen01,
        ),
        const SizedBox(width: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Text(
            className,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _ClassCounselorAssignmentSheet extends ConsumerStatefulWidget {
  final ClassCounselorAssignmentsQuery query;
  final List<ProgressiveClass> classes;
  final List<ClubMember> candidates;
  final ClassCounselorAssignment? initialAssignment;

  const _ClassCounselorAssignmentSheet({
    required this.query,
    required this.classes,
    required this.candidates,
    this.initialAssignment,
  });

  @override
  ConsumerState<_ClassCounselorAssignmentSheet> createState() =>
      _ClassCounselorAssignmentSheetState();
}

class _ClassCounselorAssignmentSheetState
    extends ConsumerState<_ClassCounselorAssignmentSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _reasonController;
  int? _selectedClassId;
  String? _selectedUserId;
  String _selectedResponsibilityType = 'primary';
  bool _exceptional = false;

  bool get _isEditing => widget.initialAssignment != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialAssignment;
    _selectedClassId = initial?.classId ??
        (widget.classes.isNotEmpty ? widget.classes.first.id : null);
    _selectedUserId = initial?.userId ??
        (widget.candidates.isNotEmpty ? widget.candidates.first.userId : null);
    _selectedResponsibilityType =
        _responsibilityTypes.contains(initial?.responsibilityType)
            ? initial!.responsibilityType
            : 'primary';
    _exceptional = initial?.exceptional ?? false;
    _reasonController =
        TextEditingController(text: initial?.exceptionReason ?? '');
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actionState =
        ref.watch(classCounselorAssignmentsNotifierProvider(widget.query));
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.ink150,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _isEditing
                    ? 'classes.class_assignments.edit_title'.tr()
                    : 'classes.class_assignments.create_title'.tr(),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink900,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'classes.class_assignments.form_body'.tr(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.ink600,
                      height: 1.35,
                    ),
              ),
              const SizedBox(height: 18),
              if (_isEditing) ...[
                _ReadOnlyField(
                  label: 'classes.class_assignments.class_label'.tr(),
                  value: widget.initialAssignment!.clazz.name,
                ),
                const SizedBox(height: 12),
                _ReadOnlyField(
                  label: 'classes.class_assignments.responsible_label'.tr(),
                  value: _safePersonName(
                    widget.initialAssignment!.user,
                    widget.initialAssignment!.userId,
                  ),
                ),
              ] else ...[
                DropdownButtonFormField<int>(
                  initialValue: _selectedClassId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'classes.class_assignments.class_label'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                  items: widget.classes
                      .map(
                        (klass) => DropdownMenuItem<int>(
                          value: klass.id,
                          child: _ClassOptionLabel(className: klass.name),
                        ),
                      )
                      .toList(),
                  validator: (value) => value == null
                      ? 'classes.class_assignments.class_required'.tr()
                      : null,
                  onChanged: actionState.isLoading
                      ? null
                      : (value) => setState(() => _selectedClassId = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedUserId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText:
                        'classes.class_assignments.responsible_label'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                  items: widget.candidates
                      .map(
                        (member) => DropdownMenuItem<String>(
                          value: member.userId,
                          child: Text(
                            '${member.fullName} · ${RoleUtils.translate(member.clubRole, gender: member.gender)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  validator: (value) => value == null
                      ? 'classes.class_assignments.responsible_required'.tr()
                      : null,
                  onChanged: actionState.isLoading
                      ? null
                      : (value) => setState(() => _selectedUserId = value),
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedResponsibilityType,
                decoration: InputDecoration(
                  labelText:
                      'classes.class_assignments.responsibility_label'.tr(),
                  border: const OutlineInputBorder(),
                ),
                items: _responsibilityTypes
                    .map(
                      (type) => DropdownMenuItem<String>(
                        value: type,
                        child: Text(_responsibilityLabel(type)),
                      ),
                    )
                    .toList(),
                onChanged: actionState.isLoading
                    ? null
                    : (value) => setState(
                          () =>
                              _selectedResponsibilityType = value ?? 'primary',
                        ),
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                value: _exceptional,
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppColors.primary,
                title: Text(
                  'classes.class_assignments.exceptional_label'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  'classes.class_assignments.exceptional_hint'.tr(),
                ),
                onChanged: actionState.isLoading
                    ? null
                    : (value) => setState(() => _exceptional = value),
              ),
              if (_exceptional) ...[
                const SizedBox(height: 8),
                SacTextField(
                  controller: _reasonController,
                  label: 'classes.class_assignments.reason_label'.tr(),
                  maxLines: 3,
                  validator: (value) {
                    if (!_exceptional) return null;
                    if ((value ?? '').trim().isEmpty) {
                      return 'classes.class_assignments.reason_required'.tr();
                    }
                    return null;
                  },
                ),
              ],
              if (actionState.errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  actionState.errorMessage!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.error,
                      ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: actionState.isLoading
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: Text('common.cancel'.tr()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: actionState.isLoading ? null : _submit,
                      child: actionState.isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text('common.save'.tr()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final exceptionReason = _exceptional ? _reasonController.text.trim() : null;
    final notifier = ref.read(
      classCounselorAssignmentsNotifierProvider(widget.query).notifier,
    );

    final success = _isEditing
        ? await notifier.update(
            assignmentId: widget.initialAssignment!.assignmentId,
            responsibilityType: _selectedResponsibilityType,
            exceptional: _exceptional,
            exceptionReason: exceptionReason,
          )
        : await notifier.create(
            userId: _selectedUserId!,
            classId: _selectedClassId!,
            ecclesiasticalYearId: widget.query.yearId,
            responsibilityType: _selectedResponsibilityType,
            exceptional: _exceptional,
            exceptionReason: exceptionReason,
          );

    if (!mounted) return;
    if (success) Navigator.of(context).pop(true);
  }
}

class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;

  const _ReadOnlyField({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.ink50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.ink150),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.ink500,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.ink900,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _AssignmentsErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _AssignmentsErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const HugeIcon(
              icon: HugeIcons.strokeRoundedAlert02,
              size: 52,
              color: AppColors.error,
            ),
            const SizedBox(height: 12),
            Text(
              'classes.class_assignments.load_error_title'.tr(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.ink600,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedRefresh,
                size: 18,
                color: Colors.white,
              ),
              label: Text('common.retry'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String title;
  final String message;

  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: icon,
              size: 54,
              color: AppColors.ink400,
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.ink600,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

void _showSnack(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? AppColors.error : AppColors.secondary,
      behavior: SnackBarBehavior.floating,
    ),
  );
}
