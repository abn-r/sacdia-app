import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/config/route_names.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_pressable.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// Entrada «Historial · Mostrar liberados» de Mi familia (Fase 4).
///
/// Las personas liberadas al cumplir la mayoría de edad NO aparecen en la lista
/// de menores: quedan detrás de esta fila (colapsada, solo bajo demanda). Con la
/// liberación apagada en el servidor no se dibuja nada (FP4-67).
class ReleasedHistoryTile extends ConsumerWidget {
  const ReleasedHistoryTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(
      authNotifierProvider.select(
        (v) => v.value?.majorityReleaseEnabled ?? false,
      ),
    );
    if (!enabled) return const SizedBox.shrink();

    final c = context.sac;
    final accent = SacAccent.of(context);
    // One-row group, like the rest of Mi familia.
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
      child: Semantics(
        button: true,
        label: 'family.history.entry_title'.tr(),
        excludeSemantics: true,
        child: Container(
          key: const ValueKey('family_released_history_entry'),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            border: Border.all(color: c.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: SacInkWell(
            onTap: () => context.push(RouteNames.familyReleased),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 60),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accent.light,
                        borderRadius: BorderRadius.circular(AppTheme.radiusXS),
                      ),
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedTime04,
                        size: 19,
                        color: accent.color,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'family.history.entry_title'.tr(),
                            style: TextStyle(
                              fontSize: SacFontSize.titleMedium,
                              fontWeight: FontWeight.w600,
                              color: c.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'family.history.entry_subtitle'.tr(),
                            style: TextStyle(
                              fontSize: SacFontSize.bodyMedium,
                              color: c.textSecondary,
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
          ),
        ),
      ),
    );
  }
}
