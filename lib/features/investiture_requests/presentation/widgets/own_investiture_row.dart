import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/config/route_names.dart';
import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../domain/entities/person_status.dart';
import '../providers/investiture_requests_providers.dart';
import '../utils/investiture_dates.dart';
import 'investiture_rows.dart';
import 'own_investiture_hero.dart';

const _i18n = 'investiture_requests.own';

/// Una sola fila de investidura para el detalle de clase propio: el estado
/// del flujo de autorización y, si la clase se acreditó sin él (certificado o
/// la vía anterior), «Investido». Toca para abrir «Mi investidura».
///
/// [enrollmentInvested] dice que la inscripción ya figura investida. Sin
/// entrada y sin investidura no ocupa espacio.
class OwnInvestitureRow extends ConsumerWidget {
  const OwnInvestitureRow({
    super.key,
    required this.classId,
    required this.enrollmentInvested,
    this.isOwnView = true,
  });

  final int classId;
  final bool enrollmentInvested;

  /// `false` cuando la directiva mira la clase de otra persona: solo se
  /// informa «Investido» (sin abrir «Mi investidura», que es de quien mira).
  final bool isOwnView;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isOwnView) {
      if (!enrollmentInvested) return const SizedBox.shrink();
      return _Row(
        key: const ValueKey('own-row-invested-readonly'),
        style: SacStatusStyle.of(
          context,
          SacStatusKind.validated,
          label: tr('$_i18n.row_invested'),
          icon: HugeIcons.strokeRoundedMedal01,
        ),
        title: tr('$_i18n.row_invested'),
        detail: tr('$_i18n.row_invested_registered'),
        tappable: false,
      );
    }
    final entry = ref.watch(ownInvestitureEntryForClassProvider(classId));
    final history = ref.watch(ownInvestitureHistoryProvider);

    if (entry == null) {
      if (!enrollmentInvested) return const SizedBox.shrink();
      // Mientras el historial carga no se sabe si habrá entrada: se espera
      // para no mostrar un estado que enseguida cambia. Si falla, vale la
      // inscripción.
      if (history.isLoading && history.value == null) {
        return const SizedBox.shrink();
      }
      return _Row(
        key: const ValueKey('own-row-invested-registered'),
        style: SacStatusStyle.of(
          context,
          SacStatusKind.validated,
          label: tr('$_i18n.row_invested'),
          icon: HugeIcons.strokeRoundedMedal01,
        ),
        title: tr('$_i18n.row_invested'),
        detail: tr('$_i18n.row_invested_registered'),
      );
    }

    final style = ownEntryStyle(context, ref, entry);
    final String detail = switch (entry.status) {
      PersonStatus.pending => tr(
          '$_i18n.row_pending_detail',
          namedArgs: {
            'date': formatInvestitureShortDay(context, entry.investitureDate),
          },
        ),
      PersonStatus.invested => ownEntryAuthorizedLine(context, entry) ?? '',
      PersonStatus.removed || PersonStatus.closedYear => '',
      _ => tr('$_i18n.row_rejected_detail'),
    };
    final title = switch (entry.status) {
      PersonStatus.pending => tr('$_i18n.row_pending'),
      PersonStatus.invested => tr('$_i18n.row_invested'),
      PersonStatus.removed || PersonStatus.closedYear => style.label,
      _ => tr('$_i18n.row_rejected'),
    };
    return _Row(
      key: ValueKey('own-row-${entry.status.name}'),
      style: style,
      title: title,
      detail: detail,
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.style,
    required this.title,
    required this.detail,
    this.tappable = true,
  });

  final SacStatusStyle style;
  final bool tappable;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return InvestitureCard(
      margin: const EdgeInsets.only(top: 12),
      children: [
        InvestitureRow(
          leading: InvestitureIconBadge(
            icon: style.icon,
            background: style.container,
            foreground: style.onContainer,
          ),
          title: title,
          detail: detail,
          trailing: tappable ? const InvestitureChevron() : null,
          semanticLabel: detail.isEmpty ? title : '$title. $detail',
          onTap:
              tappable ? () => context.push(RouteNames.ownInvestiture) : null,
        ),
      ],
    );
  }
}
