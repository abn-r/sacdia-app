import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_badge.dart';
import '../../../../providers/catalogs_provider.dart';
import '../../domain/entities/own_investiture_entry.dart';
import '../../domain/entities/person_status.dart';
import '../providers/investiture_requests_providers.dart';
import '../utils/investiture_dates.dart';
import '../utils/own_investiture_selection.dart';

const _i18n = 'investiture_requests.own';

/// Estado de investidura de la persona en una clase, para el detalle de clase.
///
/// Toma del historial propio la entrada más reciente de [classId]. Sin entrada
/// (o mientras carga o falla) no ocupa espacio.
class OwnInvestitureCard extends ConsumerWidget {
  const OwnInvestitureCard({super.key, required this.classId});

  final int classId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(ownInvestitureEntryForClassProvider(classId));
    if (entry == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 2),
      child: OwnInvestitureEntryCard(entry: entry),
    );
  }
}

/// Tarjeta de una entrada del historial propio.
///
/// Solo muestra los textos cerrados del plan funcional (§3.6 y §4). La persona
/// nunca ve el motivo humano de un rechazo, el texto largo del sistema ni quién
/// decidió: aunque la entrada traiga esos campos, aquí no se leen.
class OwnInvestitureEntryCard extends ConsumerWidget {
  const OwnInvestitureEntryCard({super.key, required this.entry});

  final OwnInvestitureEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ownEntryHasContent(entry)) return const SizedBox.shrink();
    final c = context.sac;
    final dark = Theme.brightnessOf(context) == Brightness.dark;
    final look = _Look.of(entry.status);
    final accent = look.accent;

    final title = switch (entry.status) {
      PersonStatus.pending => tr('$_i18n.pending'),
      PersonStatus.invested => tr('$_i18n.invested'),
      PersonStatus.closedYear => tr(
          '$_i18n.closed_year',
          namedArgs: {'year': _yearLabel(ref)},
        ),
      PersonStatus.removed => entry.personText!.trim(),
      _ => tr('$_i18n.rejected'),
    };

    final showDate = entry.status == PersonStatus.pending ||
        entry.status == PersonStatus.invested ||
        entry.status == PersonStatus.rejected ||
        entry.status == PersonStatus.rejectedByPerson ||
        entry.status == PersonStatus.rejectedBySystem;
    final subtitle = [
      if (entry.className != null && entry.className!.isNotEmpty)
        entry.className!,
      if (showDate) formatInvestitureDate(context, entry.investitureDate),
    ].join(' · ');

    final comment = entry.status == PersonStatus.invested
        ? entry.authorizationComment?.trim()
        : null;

    return Semantics(
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: dark ? accent.withValues(alpha: 0.16) : look.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.24)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: c.paper.withValues(alpha: dark ? 0.12 : 0.78),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: HugeIcon(
                  icon: look.icon,
                  size: 18,
                  color: dark ? accent : look.foreground,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (entry.status == PersonStatus.pending) ...[
                    SacBadge.warning(
                      label: tr('investiture_requests.section.pending_badge'),
                      icon: HugeIcons.strokeRoundedClock01,
                    ),
                    const SizedBox(height: 6),
                  ] else if (entry.status == PersonStatus.invested) ...[
                    SacBadge.success(
                      label: tr('investiture.status.investido'),
                      icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: c.ink900,
                      height: 1.25,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: c.ink600,
                        height: 1.3,
                      ),
                    ),
                  ],
                  if (comment != null && comment.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _CommentQuote(text: comment, accent: accent),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Nombre del año eclesiástico ("2025-2026"); si el catálogo no lo trae,
  /// el año calendario de la fecha prevista.
  String _yearLabel(WidgetRef ref) {
    final years = ref.watch(ecclesiasticalYearsProvider(null)).valueOrNull;
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
}

class _CommentQuote extends StatelessWidget {
  const _CommentQuote({required this.text, required this.accent});

  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: c.paper.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('$_i18n.comment_title'),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: c.ink500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: c.ink800,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

/// Colores e ícono por estado; mismos tokens que la tarjeta legada del detalle
/// de clase (pendiente = azul, investida = verde, falta = coral).
class _Look {
  const _Look({
    required this.accent,
    required this.foreground,
    required this.background,
    required this.icon,
  });

  final Color accent;
  final Color foreground;
  final Color background;
  final List<List<dynamic>> icon;

  static _Look of(PersonStatus status) {
    switch (status) {
      case PersonStatus.pending:
        return const _Look(
          accent: AppColors.sentColor,
          foreground: AppColors.sentDark,
          background: AppColors.sentBg,
          icon: HugeIcons.strokeRoundedClock01,
        );
      case PersonStatus.invested:
        return const _Look(
          accent: AppColors.validatedColor,
          foreground: AppColors.validatedDark,
          background: AppColors.validatedBg,
          icon: HugeIcons.strokeRoundedCheckmarkCircle02,
        );
      case PersonStatus.rejected:
      case PersonStatus.rejectedByPerson:
      case PersonStatus.rejectedBySystem:
        return const _Look(
          accent: AppColors.coral700,
          foreground: AppColors.coral700,
          background: AppColors.coral50,
          icon: HugeIcons.strokeRoundedAlert02,
        );
      case PersonStatus.closedYear:
      case PersonStatus.removed:
      case PersonStatus.unknown:
        return const _Look(
          accent: AppColors.sentColor,
          foreground: AppColors.sentDark,
          background: AppColors.sentBg,
          icon: HugeIcons.strokeRoundedCalendar03,
        );
    }
  }
}
