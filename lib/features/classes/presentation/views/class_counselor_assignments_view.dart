import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/role_utils.dart';
import '../../../../core/widgets/sac_back_button.dart';
import '../../../../core/widgets/sac_card.dart';
import '../../../../core/widgets/sac_loading.dart';
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

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _AssignmentsHeader(
            canAssign: canAssign,
            isActionLoading: isActionLoading,
            onAdd: onAdd,
          ),
          const SizedBox(height: 10),
          if (sortedAssignments.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 72),
              child: _MessageState(
                icon: HugeIcons.strokeRoundedUserGroup,
                title: 'classes.class_assignments.empty_title'.tr(),
                message: 'classes.class_assignments.empty_body'.tr(),
              ),
            )
          else
            for (final entry in sortedAssignments.asMap().entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AssignmentTile(
                  assignment: entry.value,
                  index: entry.key,
                  canEdit: onEdit != null,
                  canRevoke: canRevoke && onRevoke != null,
                  onEdit: onEdit == null ? null : () => onEdit!(entry.value),
                  onRevoke:
                      onRevoke == null ? null : () => onRevoke!(entry.value),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedUserCheck01,
                size: 22,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        'classes.class_assignments.header_title'.tr(),
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink900,
                                ),
                      ),
                    ),
                    if (canAssign && onAdd != null) ...[
                      const SizedBox(width: 8),
                      _AssignmentAddAction(
                        isLoading: isActionLoading,
                        onTap: isActionLoading ? null : onAdd,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  canAssign
                      ? 'classes.class_assignments.header_body'.tr()
                      : 'classes.class_assignments.readonly_body'.tr(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.ink600,
                        height: 1.35,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignmentAddAction extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onTap;

  const _AssignmentAddAction({
    required this.isLoading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final color = enabled ? AppColors.primary : AppColors.ink400;

    return Semantics(
      label: 'classes.class_assignments.add_button'.tr(),
      button: true,
      enabled: enabled,
      child: Material(
        color: AppColors.paper,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: enabled
                ? AppColors.primary.withValues(alpha: 0.22)
                : AppColors.ink150,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  )
                else
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedAdd01,
                    size: 20,
                    color: color,
                  ),
                const SizedBox(width: 6),
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

    return SacCard(
      animate: true,
      animationDelay: Duration(milliseconds: index * 80),
      padding: EdgeInsets.zero,
      borderColor: classColor.withValues(alpha: 0.18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink900,
                          letterSpacing: -0.2,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _ClassAssignmentChip(
                        className: assignment.clazz.name,
                        color: classColor,
                      ),
                      if (roleName != null && roleName.isNotEmpty)
                        _AssignmentChip(
                          label: RoleUtils.translate(roleName),
                          color: AppColors.ink600,
                        ),
                      _AssignmentChip(
                        label:
                            _responsibilityLabel(assignment.responsibilityType),
                        color: classColor,
                      ),
                      if (assignment.exceptional)
                        _AssignmentChip(
                          label:
                              'classes.class_assignments.exceptional_chip'.tr(),
                          color: AppColors.accentDark,
                        ),
                    ],
                  ),
                  if (assignment.exceptional &&
                      (assignment.exceptionReason?.trim().isNotEmpty ??
                          false)) ...[
                    const SizedBox(height: 8),
                    Text(
                      assignment.exceptionReason!.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.ink600,
                            height: 1.3,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (canEdit || canRevoke)
              Semantics(
                button: true,
                label: 'nav.more_options'.tr(),
                child: PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: classColor.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    ),
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedMoreHorizontal,
                      size: 16,
                      color: classColor,
                    ),
                  ),
                  onSelected: (value) {
                    if (value == 'edit') onEdit?.call();
                    if (value == 'revoke') onRevoke?.call();
                  },
                  itemBuilder: (context) => [
                    if (canEdit)
                      PopupMenuItem(
                        value: 'edit',
                        child: Text('common.edit'.tr()),
                      ),
                    if (canRevoke)
                      PopupMenuItem(
                        value: 'revoke',
                        child: Text(
                          'classes.class_assignments.revoke_action'.tr(),
                          style: const TextStyle(color: AppColors.error),
                        ),
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

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: 0.18),
                accent.withValues(alpha: 0.07),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withValues(alpha: 0.16)),
          ),
          clipBehavior: Clip.antiAlias,
          alignment: Alignment.center,
          child: image == null || image.isEmpty
              ? Text(
                  initials.isEmpty ? '?' : initials,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                )
              : CachedNetworkImage(
                  imageUrl: image,
                  fit: BoxFit.cover,
                  width: 54,
                  height: 54,
                  errorWidget: (_, __, ___) => Text(
                    initials.isEmpty ? '?' : initials,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
        ),
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              border: Border.all(color: AppColors.ink150),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedUserCheck01,
              size: 12,
              color: accent,
            ),
          ),
        ),
      ],
    );
  }
}

class _ClassAssignmentChip extends StatelessWidget {
  final String className;
  final Color color;

  const _ClassAssignmentChip({
    required this.className,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 4, 10, 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClassIdentityBadge(
            className: className,
            size: 22,
            logoPadding: 3,
            borderRadius: 7,
            fallbackIcon: HugeIcons.strokeRoundedBookOpen01,
          ),
          const SizedBox(width: 6),
          Text(
            className,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
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
                TextFormField(
                  controller: _reasonController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'classes.class_assignments.reason_label'.tr(),
                    border: const OutlineInputBorder(),
                  ),
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
