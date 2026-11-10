import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';

import '../../domain/entities/role_candidate.dart';
import '../utils/role_candidate_labels.dart';
import 'role_candidate_header.dart';

/// Step 2: the five service roles with their slot state. Roles the server did
/// not put in `allowed_roles` are disabled and say why («Ocupado por Jorge
/// Pérez», «No compatible con Secretario»).
class RoleCandidateRoleStep extends StatelessWidget {
  const RoleCandidateRoleStep({
    super.key,
    required this.candidate,
    required this.slots,
    required this.onPick,
    required this.onViewDetail,
  });

  final RoleCandidate candidate;
  final List<RoleSlot> slots;
  final ValueChanged<String> onPick;
  final VoidCallback onViewDetail;

  RoleSlot? _slotFor(String role) {
    for (final slot in slots) {
      if (slot.role == role) return slot;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        RoleCandidateHeader(candidate: candidate),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: SacButton(
            text: 'members.role_candidates.view_detail'.tr(),
            icon: HugeIcons.strokeRoundedUserSearch01,
            variant: SacButtonVariant.ghost,
            size: SacButtonSize.small,
            onPressed: onViewDetail,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Semantics(
            header: true,
            child: Text(
              'members.role_candidates.choose_role'.tr(),
              style: TextStyle(
                fontSize: SacFontSize.titleSmall,
                fontWeight: FontWeight.w700,
                color: c.textSecondary,
              ),
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            border: Border.all(color: c.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            child: Column(
              children: [
                for (var i = 0; i < kBoardServiceRoles.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: c.borderLight),
                  _RoleRow(
                    key: ValueKey('role-option-${kBoardServiceRoles[i]}'),
                    role: kBoardServiceRoles[i],
                    candidate: candidate,
                    slot: _slotFor(kBoardServiceRoles[i]),
                    onPick: onPick,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RoleRow extends StatelessWidget {
  const _RoleRow({
    super.key,
    required this.role,
    required this.candidate,
    required this.slot,
    required this.onPick,
  });

  final String role;
  final RoleCandidate candidate;
  final RoleSlot? slot;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final reason = roleDisabledReason(role, candidate, slot);
    final enabled = reason == null;
    final subtitle = enabled ? roleSlotStateLabel(slot) : reason;

    return MergeSemantics(
      child: SacPressable(
        onTap: enabled ? () => onPick(role) : null,
        enabled: enabled,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        candidateRoleLabel(role, gender: candidate.gender),
                        style: TextStyle(
                          fontSize: SacFontSize.titleMedium,
                          fontWeight: FontWeight.w600,
                          color: enabled ? c.text : c.textTertiary,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: SacFontSize.bodySmall,
                            color: c.textSecondary,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ExcludeSemantics(
                  child: HugeIcon(
                    icon: enabled
                        ? HugeIcons.strokeRoundedArrowRight01
                        : HugeIcons.strokeRoundedLockKey,
                    size: 18,
                    color: c.textTertiary,
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
