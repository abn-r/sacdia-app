import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../../../providers/catalogs_provider.dart';
import '../../domain/entities/own_investiture_entry.dart';
import '../../domain/entities/person_status.dart';
import '../utils/investiture_dates.dart';

const _i18n = 'investiture_requests.own';

/// Nombre del año eclesiástico ("2025-2026"); si el catálogo no lo trae, el
/// año calendario de la fecha prevista.
String ownEntryYearLabel(WidgetRef ref, OwnInvestitureEntry entry) {
  final years = ref.watch(ecclesiasticalYearsProvider(null)).value;
  if (years != null) {
    for (final year in years) {
      if (year.ecclesiasticalYearId == entry.ecclesiasticalYearId &&
          year.name.trim().isNotEmpty) {
        return year.name.trim();
      }
    }
  }
  return '${entry.investitureDate.year}';
}

/// ¿La entrada es un rechazo (de la persona o del sistema)? La persona ve los
/// dos igual: el backend los colapsa y nunca le da el motivo.
bool ownEntryIsRejected(OwnInvestitureEntry entry) =>
    entry.status == PersonStatus.rejected ||
    entry.status == PersonStatus.rejectedByPerson ||
    entry.status == PersonStatus.rejectedBySystem;

/// Estilo (color, ícono, texto) del estado de una entrada para la persona.
SacStatusStyle ownEntryStyle(
  BuildContext context,
  WidgetRef ref,
  OwnInvestitureEntry entry,
) {
  switch (entry.status) {
    case PersonStatus.pending:
      return SacStatusStyle.of(
        context,
        SacStatusKind.review,
        label: tr('$_i18n.pending_title'),
        icon: HugeIcons.strokeRoundedClock01,
      );
    case PersonStatus.invested:
      return SacStatusStyle.of(
        context,
        SacStatusKind.validated,
        label: tr('$_i18n.invested_title'),
        icon: HugeIcons.strokeRoundedMedal01,
      );
    case PersonStatus.closedYear:
      return SacStatusStyle.of(
        context,
        SacStatusKind.pending,
        label: tr(
          '$_i18n.closed_year',
          namedArgs: {'year': ownEntryYearLabel(ref, entry)},
        ),
        icon: HugeIcons.strokeRoundedCalendar03,
      );
    case PersonStatus.removed:
      return SacStatusStyle.of(
        context,
        SacStatusKind.pending,
        label: entry.personText?.trim() ?? '',
        icon: HugeIcons.strokeRoundedInformationCircle,
      );
    default:
      return SacStatusStyle.of(
        context,
        SacStatusKind.pending,
        label: tr('$_i18n.not_invested_title'),
        icon: HugeIcons.strokeRoundedInformationCircle,
      );
  }
}

/// Quién y cuándo autorizó: "Autorizó Ptr. X el 14 dic". `null` si el backend
/// no informa a quien autorizó.
String? ownEntryAuthorizedLine(
    BuildContext context, OwnInvestitureEntry entry) {
  final by = entry.resolvedByName?.trim();
  if (by == null || by.isEmpty) return null;
  final at = entry.resolvedAt?.toLocal();
  if (at == null) {
    return tr('$_i18n.authorized_by', namedArgs: {'name': by});
  }
  return tr(
    '$_i18n.authorized_by_on',
    namedArgs: {'name': by, 'date': formatInvestitureDayMonth(context, at)},
  );
}

/// Protagonista de «Mi investidura»: el estado de la clase actual con tres
/// pasos (Requisitos, Enviado, Investido), la fecha y, al investirse, el
/// comentario de quien autorizó.
class OwnInvestitureHero extends ConsumerWidget {
  const OwnInvestitureHero({super.key, required this.entry});

  final OwnInvestitureEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final style = ownEntryStyle(context, ref, entry);
    final year = ownEntryYearLabel(ref, entry);
    final className = entry.className?.trim();
    final trailing = [
      if (className != null && className.isNotEmpty) className,
      year,
    ].join(' · ');

    final (int step, double fill) = switch (entry.status) {
      PersonStatus.pending => (1, 1.0),
      PersonStatus.invested => (2, 1.0),
      PersonStatus.removed || PersonStatus.closedYear => (0, 1.0),
      _ => (1, 0.0),
    };

    final String? meta = switch (entry.status) {
      PersonStatus.pending => tr(
          '$_i18n.pending_meta',
          namedArgs: {
            'date': formatInvestitureLongDay(context, entry.investitureDate),
          },
        ),
      PersonStatus.invested => [
          tr('$_i18n.invested_meta'),
          if (ownEntryAuthorizedLine(context, entry) case final line?) '$line.',
        ].join(' '),
      PersonStatus.removed || PersonStatus.closedYear => null,
      _ => '${tr('$_i18n.rejected')} ${tr('$_i18n.talk_to_board')}',
    };

    final comment = entry.status == PersonStatus.invested
        ? entry.authorizationComment?.trim()
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: SacStatusPanel(
        key: const ValueKey('own-hero'),
        style: style,
        trailing: trailing,
        meta: meta,
        steps: [
          tr('$_i18n.step_requirements'),
          tr('$_i18n.step_sent'),
          tr('$_i18n.step_invested'),
        ],
        currentStep: step,
        fill: fill,
        stepsSemanticsLabel: tr(
          '$_i18n.steps_semantics',
          namedArgs: {
            'step': tr('$_i18n.step_${const [
              'requirements',
              'sent',
              'invested'
            ][step]}')
          },
        ),
        note: comment == null || comment.isEmpty
            ? null
            : Container(
                key: const ValueKey('own-hero-comment'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildIcon(
                      HugeIcons.strokeRoundedMessage01,
                      size: 16,
                      color: c.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '«$comment»',
                        style: TextStyle(
                          fontSize: SacFontSize.titleSmall,
                          fontStyle: FontStyle.italic,
                          height: 1.35,
                          color: c.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
