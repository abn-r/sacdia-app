import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/role_utils.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_profile_image.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';

import '../../domain/entities/assignable_role.dart';
import '../../domain/entities/club_member.dart';
import '../providers/members_providers.dart';

/// Vista de asignación de rol de club a un miembro.
/// Accesible solo para Director y Subdirector.
class RoleAssignmentView extends ConsumerStatefulWidget {
  final ClubMember member;
  final ClubContext clubContext;

  const RoleAssignmentView({
    super.key,
    required this.member,
    required this.clubContext,
  });

  @override
  ConsumerState<RoleAssignmentView> createState() => _RoleAssignmentViewState();
}

class _RoleAssignmentViewState extends ConsumerState<RoleAssignmentView> {
  /// Orden de visualización. También es el respaldo si falla el endpoint de
  /// roles asignables (el servidor igual valida al guardar).
  static const _displayOrder = [
    'director',
    'deputy-director',
    'secretary',
    'treasurer',
    'secretary-treasurer',
    'counselor',
    'member',
  ];

  /// Roles del endpoint en orden de visualización; los desconocidos al final.
  static List<AssignableRole> _sortRoles(List<AssignableRole> roles) {
    int rank(AssignableRole r) {
      final i = _displayOrder.indexOf(r.roleName);
      return i < 0 ? _displayOrder.length : i;
    }

    final sorted = List<AssignableRole>.of(roles);
    // sort de Dart no es estable: desempata por nombre.
    sorted.sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      return byRank != 0 ? byRank : a.roleName.compareTo(b.roleName);
    });
    return sorted;
  }

  String? _blockedReason(AssignableRole role) {
    if (role.allowed) return null;
    switch (role.violationCode) {
      case clubRoleMemberRequiresGuideMajorSectionCode:
        return 'members.role_assignment.blocked_member_in_guide_major_section'
            .tr();
      case clubRoleGuideMajorRequiredCode:
      default:
        return 'members.role_assignment.blocked_guide_major_required'.tr();
    }
  }

  String? _selectedRole;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-seleccionar el rol actual si tiene
    _selectedRole = widget.member.clubRole;
  }

  Future<void> _save() async {
    if (_selectedRole == null) return;
    if (_selectedRole == widget.member.clubRole) {
      Navigator.pop(context, false);
      return;
    }

    setState(() => _isLoading = true);

    final failure = await ref.read(membersNotifierProvider.notifier).assignRole(
          context: widget.clubContext,
          userId: widget.member.userId,
          role: _selectedRole!,
        );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (failure == null) {
      SacSnackBar.show(
          context,
          tr('members.role_assignment.assigned_role', namedArgs: {
            'role':
                RoleUtils.translate(_selectedRole, gender: widget.member.gender)
          }),
          backgroundColor: AppColors.secondary);
      Navigator.pop(context, true);
    } else {
      SacSnackBar.show(context, _assignErrorMessage(failure), isError: true);
    }
  }

  /// Muestra el motivo del backend en rechazos de negocio (4xx, p. ej. cupo
  /// del cargo lleno); para el resto, el mensaje genérico.
  String _assignErrorMessage(Failure failure) {
    final code = failure.code;
    final isBusinessRejection =
        failure is ServerFailure && code != null && code >= 400 && code < 500;
    if (isBusinessRejection && failure.message.trim().isNotEmpty) {
      return failure.message;
    }
    return 'members.role_assignment.assign_error'.tr();
  }

  Widget _buildRoleList(BuildContext context, List<AssignableRole> roles) {
    final c = context.sac;
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: roles.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final assignable = roles[index];
        final role = assignable.roleName;
        final enabled = assignable.allowed;
        final reason = _blockedReason(assignable);
        final isSelected = role == _selectedRole;

        return Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Material(
            color: isSelected
                ? SacAccent.of(context).color.withValues(alpha: 0.08)
                : c.surface,
            borderRadius: BorderRadius.circular(12),
            child: SacInkWell(
              onTap:
                  enabled ? () => setState(() => _selectedRole = role) : null,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? SacAccent.of(context).color : c.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            RoleUtils.translate(role,
                                gender: widget.member.gender),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: isSelected
                                  ? SacAccent.of(context).color
                                  : c.text,
                            ),
                          ),
                          if (reason != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                reason,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: c.textSecondary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                        color: SacAccent.of(context).color,
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final rolesAsync = ref.watch(assignableRolesProvider(AssignableRolesParams(
      clubId: widget.clubContext.clubId,
      sectionId: widget.clubContext.sectionId,
      userId: widget.member.userId,
    )));

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
          title: 'members.role_assignment.title'.tr(),
          centerTitle: true,
          automaticallyImplyLeading: !_isLoading,
          frosted: true),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => SafeArea(
            child: Column(
              children: [
                // ── Member info ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: SacAccent.of(context).surface,
                        backgroundImage: widget.member.avatar != null
                            ? sacProfileImageProvider(widget.member.avatar!)
                            : null,
                        child: widget.member.avatar == null
                            ? Text(
                                widget.member.initials,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: SacAccent.of(context).color,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.member.fullName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: c.text,
                              ),
                            ),
                            if (widget.member.clubRole != null)
                              Text(
                                tr('members.role_assignment.current_role',
                                    namedArgs: {
                                      'role': RoleUtils.translate(
                                          widget.member.clubRole,
                                          gender: widget.member.gender)
                                    }),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: c.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Container(height: 1, color: c.divider),

                // ── Role list ────────────────────────────────────────────
                Expanded(
                  child: rolesAsync.when(
                    loading: () => const Center(child: SacLoading()),
                    // Si el endpoint falla, se muestra la lista previa y el
                    // servidor aplica la regla al guardar.
                    error: (_, __) => _buildRoleList(context, [
                      for (final name in _displayOrder)
                        AssignableRole(
                          roleId: '',
                          roleName: name,
                          allowed: true,
                        ),
                    ]),
                    data: (result) => _buildRoleList(
                      context,
                      _sortRoles(result.roles),
                    ),
                  ),
                ),

                // ── Save button ──────────────────────────────────────────
                Container(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    12,
                    20,
                    12 + MediaQuery.of(context).padding.bottom,
                  ),
                  decoration: BoxDecoration(
                    color: c.surface,
                    border: Border(top: BorderSide(color: c.border)),
                  ),
                  child: SacButton.primary(
                    text: 'members.role_assignment.save_button'.tr(),
                    icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                    isLoading: _isLoading,
                    onPressed: _isLoading ||
                            _selectedRole == null ||
                            _selectedRole == widget.member.clubRole
                        ? null
                        : _save,
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
