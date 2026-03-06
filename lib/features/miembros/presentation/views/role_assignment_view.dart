import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/role_utils.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';

import '../../domain/entities/club_member.dart';
import '../providers/miembros_providers.dart';

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
  ConsumerState<RoleAssignmentView> createState() =>
      _RoleAssignmentViewState();
}

class _RoleAssignmentViewState extends ConsumerState<RoleAssignmentView> {
  /// Roles disponibles para asignar en el club
  static const _availableRoles = [
    'director',
    'deputy_director',
    'secretary',
    'treasurer',
    'counselor',
    'instructor',
    'member',
  ];

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

    final success = await ref.read(miembrosNotifierProvider.notifier).assignRole(
          context: widget.clubContext,
          userId: widget.member.userId,
          role: _selectedRole!,
        );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cargo asignado: ${RoleUtils.translate(_selectedRole)}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al asignar el cargo. Intenta de nuevo.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        leading: IconButton(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: c.text,
            size: 24,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Asignar cargo',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: c.text,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Member info ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primarySurface,
                    backgroundImage: widget.member.avatar != null
                        ? NetworkImage(widget.member.avatar!)
                        : null,
                    child: widget.member.avatar == null
                        ? Text(
                            widget.member.initials,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
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
                            'Cargo actual: ${RoleUtils.translate(widget.member.clubRole)}',
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
              child: ListView.separated(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: _availableRoles.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final role = _availableRoles[index];
                  final isSelected = role == _selectedRole;

                  return Material(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : c.surface,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () => setState(() => _selectedRole = role),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : c.border,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                RoleUtils.translate(role),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isSelected
                                      ? AppColors.primary
                                      : c.text,
                                ),
                              ),
                            ),
                            if (isSelected)
                              const HugeIcon(
                                icon:
                                    HugeIcons.strokeRoundedCheckmarkCircle01,
                                color: AppColors.primary,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
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
              child: _isLoading
                  ? const Center(child: SacLoading())
                  : SacButton.primary(
                      text: 'Guardar cargo',
                      icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                      onPressed: _selectedRole != null ? _save : null,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
