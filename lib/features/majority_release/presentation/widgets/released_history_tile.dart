import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/config/route_names.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_card.dart';
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
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Semantics(
        button: true,
        label: 'family.history.entry_title'.tr(),
        child: SacPressable(
          onTap: () => context.push(RouteNames.familyReleased),
          child: SacCard(
            key: const ValueKey('family_released_history_entry'),
            child: Row(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedTime04,
                  size: 22,
                  color: c.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'family.history.entry_title'.tr(),
                        style: textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'family.history.entry_subtitle'.tr(),
                        style: textTheme.bodySmall
                            ?.copyWith(color: c.textSecondary),
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
    );
  }
}
