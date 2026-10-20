import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_card.dart';
import '../../../auth/domain/entities/principal_info.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// Nota de transparencia para un adolescente con tutor verificado (FP3-26):
/// qué ve su tutor (progreso y asistencia) y qué no (salud y mensajes).
///
/// Es texto estático traducido en los 4 idiomas: no depende de ningún dato del
/// servidor, así que nunca puede prometer más ni menos de lo que el resumen del
/// tutor muestra de verdad.
class SupervisionInfoCard extends StatelessWidget {
  const SupervisionInfoCard({super.key, this.horizontalPadding = 0});

  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 20, horizontalPadding, 0),
      child: SacCard(
        key: const ValueKey('supervision_info_card'),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedShield01,
              size: 24,
              color: SacAccent.of(context).color,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'teen.info.title'.tr(),
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'teen.info.body'.tr(),
                    style: textTheme.bodySmall?.copyWith(
                      color: c.textSecondary,
                      height: 1.4,
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

/// Pone [SupervisionInfoCard] solo cuando la cuenta es la de un adolescente con
/// tutor verificado; para cualquier otra no dibuja nada.
class SupervisionInfoSlot extends ConsumerWidget {
  const SupervisionInfoSlot({super.key, this.horizontalPadding = 0});

  final double horizontalPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supervised = ref.watch(
      authNotifierProvider.select(
        (v) => v.valueOrNull?.mode == AccountMode.teenSupervised,
      ),
    );
    if (!supervised) return const SizedBox.shrink();
    return SupervisionInfoCard(horizontalPadding: horizontalPadding);
  }
}
