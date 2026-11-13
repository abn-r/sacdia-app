import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_card.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// Aviso descartable para un adolescente supervisado cuya mayoría de edad está
/// a menos de 30 días (Fase 4, FP4-60): la fecha y qué pasa después (sus tutores
/// dejan de tener acceso, deberá aceptar los términos y agregar un correo).
///
/// Sale solo con la liberación activa en el servidor (`family_features`) y con
/// la ventana de aviso abierta (`supervision.majority_date`). El descarte vive
/// en este widget (no persiste): el aviso no es una advertencia crítica.
///
/// El aviso para los tutores llega por push y bandeja (`majority_notice`): la
/// lista de menores del servidor no trae la fecha de mayoría de edad, así que la
/// app no la calcula en el cliente.
class MajorityNoticeSlot extends ConsumerStatefulWidget {
  const MajorityNoticeSlot({super.key, this.horizontalPadding = 0});

  final double horizontalPadding;

  @override
  ConsumerState<MajorityNoticeSlot> createState() => _MajorityNoticeSlotState();
}

class _MajorityNoticeSlotState extends ConsumerState<MajorityNoticeSlot> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider.select((v) => v.value));
    final supervision = user?.principal?.supervision;
    if (_dismissed ||
        user == null ||
        !user.isSupervisedTeen ||
        !user.majorityReleaseEnabled ||
        supervision == null ||
        !supervision.hasMajorityNotice) {
      return const SizedBox.shrink();
    }

    final date = supervision.majorityDate!;
    final dateText = DateFormat.yMMMMd(context.locale.toString()).format(date);
    final c = context.sac;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        widget.horizontalPadding,
        16,
        widget.horizontalPadding,
        0,
      ),
      child: SacCard(
        key: const ValueKey('majority_notice_banner'),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedCalendar03,
              size: 24,
              color: c.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'release.notice.title'.tr(namedArgs: {'date': dateText}),
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'release.notice.body'.tr(),
                    style: textTheme.bodySmall?.copyWith(
                      color: c.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              key: const ValueKey('majority_notice_dismiss'),
              tooltip: 'release.notice.dismiss'.tr(),
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() => _dismissed = true),
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedCancel01,
                size: 18,
                color: c.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
