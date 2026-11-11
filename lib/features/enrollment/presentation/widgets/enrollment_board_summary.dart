import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../members/domain/entities/club_member.dart';
import '../utils/board_role_matchers.dart';

/// Resumen de solo lectura de los directivos del registro anual.
///
/// La directiva no se edita aquí: el backend la toma de los cargos activos de
/// Miembros al crear o editar el registro. Este widget solo muestra lo que
/// se enviará y ofrece ir a Miembros para corregirlo.
class EnrollmentBoardSummary extends StatelessWidget {
  final List<ClubMember> members;
  final bool isLoading;
  final VoidCallback? onOpenMembers;

  const EnrollmentBoardSummary({
    super.key,
    required this.members,
    this.isLoading = false,
    this.onOpenMembers,
  });

  static const _maxDeputies = 2;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final director = members.where((m) => isDirectorRole(m.clubRole));
    final deputies = members
        .where((m) => isDeputyDirectorRole(m.clubRole))
        .take(_maxDeputies);
    final secretary = members.where((m) => isSecretaryRole(m.clubRole));
    final treasurer = members.where((m) => isTreasurerRole(m.clubRole));
    final combined = members.where((m) => isSecretaryTreasurerRole(m.clubRole));
    final useCombined =
        combined.isNotEmpty && secretary.isEmpty && treasurer.isEmpty;

    final rows = <(String, List<ClubMember>)>[
      ('enrollment.form.label_director', director.take(1).toList()),
      ('enrollment.form.label_deputy_directors', deputies.toList()),
      if (useCombined)
        ('enrollment.form.label_secretary_treasurer', combined.take(1).toList())
      else ...[
        ('enrollment.form.label_secretary', secretary.take(1).toList()),
        ('enrollment.form.label_treasurer', treasurer.take(1).toList()),
      ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: c.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            border: Border.all(color: c.border),
          ),
          child: isLoading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (final (labelKey, assigned) in rows)
                      _BoardRow(label: labelKey.tr(), members: assigned),
                  ],
                ),
        ),
        const SizedBox(height: 8),
        Text(
          'enrollment.form.board_helper'.tr(),
          style: TextStyle(
            fontSize: SacFontSize.bodySmall,
            color: c.textTertiary,
          ),
        ),
        if (onOpenMembers != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: SacButton.text(
              text: 'enrollment.form.board_go_to_members'.tr(),
              onPressed: onOpenMembers,
            ),
          ),
      ],
    );
  }
}

class _BoardRow extends StatelessWidget {
  final String label;
  final List<ClubMember> members;

  const _BoardRow({required this.label, required this.members});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final value = members.isEmpty
        ? 'enrollment.form.board_unassigned'.tr()
        : members.map((m) => m.fullName).join('\n');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: SacFontSize.bodyMedium,
                fontWeight: FontWeight.w600,
                color: c.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: SacFontSize.titleSmall,
                color: members.isEmpty ? c.textTertiary : c.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
