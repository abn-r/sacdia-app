import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';

import '../../domain/entities/role_candidate.dart';
import '../utils/role_candidate_labels.dart';

/// Header strip of the sheet: one pill per service role with its slot count
/// («Subdirector 1/2», «Secretario 1/1», «Consejeros 3»). A slot with room uses
/// the quiet accent; a full slot goes neutral so it reads as «no room» and
/// never as «selected» (the counter already says 1/1).
class RoleSlotPills extends StatelessWidget {
  const RoleSlotPills({super.key, required this.slots});

  final List<RoleSlot> slots;

  List<RoleSlot> get _ordered {
    final byRole = {for (final s in slots) s.role: s};
    return [
      for (final role in kBoardServiceRoles)
        if (byRole.containsKey(role)) byRole[role]!,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final ordered = _ordered;
    if (ordered.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: ordered.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => _Pill(slot: ordered[i]),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.slot});

  final RoleSlot slot;

  @override
  Widget build(BuildContext context) {
    final accent = SacAccent.of(context);
    final c = context.sac;
    final full = slot.isFull;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: full ? c.surfaceVariant : accent.light,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Center(
          child: Text(
            roleSlotLabel(slot),
            style: TextStyle(
              fontSize: SacFontSize.bodySmall,
              fontWeight: FontWeight.w600,
              color: full ? c.textSecondary : accent.dark,
            ),
          ),
        ),
      ),
    );
  }
}
