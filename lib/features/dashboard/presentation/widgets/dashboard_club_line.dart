import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/club_type.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/theme/sac_font_size.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/section_switcher_sheet.dart';

import '../../../auth/domain/utils/authorization_utils.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';

/// Línea de club bajo el saludo del inicio: logo del tipo de club, «Club ·
/// Tipo» y, si el usuario tiene más de una asignación utilizable, un chevron y
/// un toque que abre el selector de sección ([showSectionSwitcher]).
///
/// El club y el tipo salen de la concesión activa (la misma fuente que el
/// selector); [clubName] del resumen del dashboard tiene prioridad para el
/// nombre, como en `ClubInfoCard`. Sin concesión activa no se pinta nada.
class DashboardClubLine extends ConsumerWidget {
  const DashboardClubLine({super.key, this.clubName});

  /// Nombre del club según el resumen del dashboard (opcional).
  final String? clubName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authorization = ref.watch(
      authNotifierProvider.select((v) => v.value?.authorization),
    );
    final activeGrant = authorization?.activeGrant;
    if (activeGrant == null) return const SizedBox.shrink();

    final assignments = visibleClubAssignments(
      authorization?.clubAssignments ?? const [],
    );
    final userGender = ref.watch(
      profileNotifierProvider.select((v) => v.value?.gender),
    );
    final hasMultiple = selectableClubAssignments(assignments).length > 1;

    final name = (clubName?.trim().isNotEmpty ?? false)
        ? clubName!.trim()
        : activeGrant.clubName?.trim();
    final type = activeGrant.clubTypeName?.trim();
    final parts = [
      if (name != null && name.isNotEmpty) name,
      if (type != null && type.isNotEmpty) type,
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    final label = parts.join(' · ');

    final c = context.sac;
    final logoAsset = clubLogoAssetFromName(type);

    final line = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (logoAsset != null) ...[
          ExcludeSemantics(
            child: Image.asset(
              logoAsset,
              width: 16,
              height: 16,
              fit: BoxFit.contain,
              cacheWidth: 48,
              cacheHeight: 48,
              errorBuilder: (_, __, ___) => const SizedBox(width: 16),
            ),
          ),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: SacFontSize.bodySmall,
              color: c.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (hasMultiple) ...[
          const SizedBox(width: 4),
          HugeIcon(
            icon: HugeIcons.strokeRoundedArrowDown01,
            size: 14,
            color: c.textTertiary,
          ),
        ],
      ],
    );

    if (!hasMultiple) {
      return Semantics(label: label, child: line);
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SacPressable(
          semanticLabel: tr(
            'dashboard.club_line.switch_semantics',
            namedArgs: {'club': label},
          ),
          onTap: () {
            showSectionSwitcher(
              context: context,
              ref: ref,
              assignments: assignments,
              activeAssignmentId: authorization?.activeAssignmentId,
              userGender: userGender,
            );
          },
          child: ExcludeSemantics(child: line),
        ),
      ),
    );
  }
}
