import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/role_utils.dart';
import '../../../../core/widgets/sac_card.dart';
import '../../../auth/domain/entities/authorization_snapshot.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../club/presentation/providers/club_providers.dart';

/// Card que muestra el club/sección activo y permite cambiar de contexto.
///
/// Solo se renderiza cuando el usuario tiene al menos un assignment en su
/// AuthorizationSnapshot. Si tiene un único assignment, el tap abre el sheet
/// pero sin opción de cambio (solo informativo con el checkmark activo).
class ClubContextCard extends ConsumerStatefulWidget {
  const ClubContextCard({super.key});

  @override
  ConsumerState<ClubContextCard> createState() => _ClubContextCardState();
}

class _ClubContextCardState extends ConsumerState<ClubContextCard> {
  bool _isSwitching = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.valueOrNull;
    final authorization = user?.authorization;

    // No renderizar si no hay assignments
    final assignments = authorization?.clubAssignments ?? const [];
    if (assignments.isEmpty) return const SizedBox.shrink();

    final activeGrant = authorization?.activeGrant;
    final activeRoleName = RoleUtils.translate(activeGrant?.roleName);

    // Try to get the club type name from the section data
    final sectionAsync = ref.watch(currentClubSectionProvider);
    final clubTypeName = sectionAsync.valueOrNull?.clubTypeName ?? 'Club';

    final c = context.sac;

    return SacCard(
      accentColor: AppColors.primary,
      onTap: _isSwitching ? null : () => _showSectionPicker(context, authorization!),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedUserGroup,
                color: AppColors.primary,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clubTypeName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (activeRoleName.isNotEmpty)
                  Text(
                    activeRoleName,
                    style: TextStyle(
                      fontSize: 13,
                      color: c.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (_isSwitching)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            )
          else if (assignments.length > 1)
            HugeIcon(
              icon: HugeIcons.strokeRoundedArrowUpDown,
              color: c.textTertiary,
              size: 20,
            ),
        ],
      ),
    );
  }

  Future<void> _showSectionPicker(
    BuildContext context,
    AuthorizationSnapshot authorization,
  ) async {
    final assignments = authorization.clubAssignments;
    // Show a maximum of 3 assignments per spec
    final displayAssignments = assignments.take(3).toList();
    final activeAssignmentId = authorization.activeAssignmentId;

    String? selectedAssignmentId;

    final actions = displayAssignments.map((grant) {
      final roleName = RoleUtils.translate(grant.roleName);
      final isActive = grant.assignmentId == activeAssignmentId;

      return CupertinoActionSheetAction(
        onPressed: () {
          Navigator.of(context).pop(grant.assignmentId);
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                roleName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive ? AppColors.primary : null,
                ),
              ),
            ),
            if (isActive)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(
                  CupertinoIcons.checkmark,
                  size: 16,
                  color: AppColors.primary,
                ),
              ),
          ],
        ),
      );
    }).toList();

    final result = await showCupertinoModalPopup<String?>(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: const Text('Seleccionar club'),
        message: const Text('Elige el club que deseas gestionar'),
        actions: actions,
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: false,
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancelar'),
        ),
      ),
    );

    selectedAssignmentId = result;

    // Ignore if cancelled or same assignment selected
    if (selectedAssignmentId == null ||
        selectedAssignmentId == activeAssignmentId) {
      return;
    }

    await _performSwitch(selectedAssignmentId);
  }

  Future<void> _performSwitch(String assignmentId) async {
    setState(() => _isSwitching = true);

    final success = await ref
        .read(authNotifierProvider.notifier)
        .switchContext(assignmentId);

    if (!mounted) return;

    setState(() => _isSwitching = false);

    if (success) {
      context.showSnackBar('Club cambiado correctamente');
    } else {
      context.showSnackBar(
        'No se pudo cambiar el club. Intentá de nuevo.',
        backgroundColor: AppColors.error,
      );
    }
  }
}
