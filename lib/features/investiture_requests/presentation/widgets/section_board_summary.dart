import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../domain/entities/presentation_context.dart';
import '../utils/investiture_dates.dart';
import '../utils/section_board.dart';

const _i18n = 'investiture_requests.section';

/// Por qué no se puede enviar a nadie ahora.
enum BoardClosedReason {
  year('year'),
  timeZone('time_zone'),
  window('window');

  const BoardClosedReason(this.key);

  /// Sufijo de las llaves de traducción `section.closed.*`.
  final String key;
}

/// `null` si el envío está abierto.
BoardClosedReason? boardClosedReason(PresentationContext ctx) {
  if (!ctx.yearOpen) return BoardClosedReason.year;
  if (ctx.window.timeZoneInvalid) return BoardClosedReason.timeZone;
  final window = ctx.window;
  if (!window.openToday || window.startDate == null || window.endDate == null) {
    return BoardClosedReason.window;
  }
  return null;
}

/// Caja de resumen del tablero. Abierta: cuántos están listos, la barra de
/// tres tramos y la ventana del Campo. Cerrada: qué pasó y qué hacer.
class SectionBoardSummary extends StatelessWidget {
  const SectionBoardSummary({
    super.key,
    required this.ctx,
    required this.board,
    required this.closedReason,
  });

  final PresentationContext ctx;
  final SectionBoard board;
  final BoardClosedReason? closedReason;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    const padding = EdgeInsets.fromLTRB(20, 12, 20, 0);
    final reason = closedReason;
    if (reason != null) {
      return Padding(
        padding: padding,
        child: SacSummaryBox(
          color: c.warningContainer,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildIcon(
                reason == BoardClosedReason.year
                    ? HugeIcons.strokeRoundedLockKey
                    : HugeIcons.strokeRoundedCalendarLock01,
                size: 20,
                color: c.onWarningContainer,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('$_i18n.closed.${reason.key}_title'),
                      style: TextStyle(
                        fontSize: SacFontSize.titleMedium,
                        fontWeight: FontWeight.w600,
                        color: c.onWarningContainer,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _closedBody(context, reason),
                      style: TextStyle(
                        fontSize: SacFontSize.bodySmall,
                        height: 1.35,
                        color: c.onWarningContainer,
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

    final accent = SacAccent.of(context).color;
    final end = ctx.window.endDate;
    return Padding(
      padding: padding,
      child: SacSummaryBox(
        color: c.surfaceVariant,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('$_i18n.summary.label'),
              style: TextStyle(
                fontSize: SacFontSize.bodySmall,
                fontWeight: FontWeight.w600,
                color: c.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text.rich(
              key: const ValueKey('board-summary-ready'),
              TextSpan(
                children: [
                  TextSpan(
                    text: tr(
                      '$_i18n.summary.ready_of_total',
                      namedArgs: {
                        'ready': '${board.ready.length}',
                        'total': '${board.total}',
                      },
                    ),
                    style: TextStyle(
                      fontSize: SacFontSize.displayMedium,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                      color: c.text,
                    ),
                  ),
                  if (board.waiting.isNotEmpty)
                    TextSpan(
                      text:
                          '  ·  ${tr('$_i18n.summary.waiting_inline', namedArgs: {
                            'count': '${board.waiting.length}',
                          })}',
                      style: TextStyle(
                        fontSize: SacFontSize.bodyMedium,
                        color: c.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SacStatusBar(
              segments: [
                SacStatusSegment(
                  count: board.waiting.length,
                  color: accent,
                  label: tr(
                    '$_i18n.summary.legend_waiting',
                    namedArgs: {'count': '${board.waiting.length}'},
                  ),
                ),
                SacStatusSegment(
                  count: board.ready.length,
                  color: c.success,
                  label: tr(
                    '$_i18n.summary.legend_ready',
                    namedArgs: {'count': '${board.ready.length}'},
                  ),
                ),
                SacStatusSegment(
                  count: board.notYet.length,
                  color: c.textTertiary.withValues(alpha: 0.45),
                  label: tr(
                    '$_i18n.summary.legend_not_yet',
                    namedArgs: {'count': '${board.notYet.length}'},
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Divider(height: 1, thickness: 1, color: c.border),
            const SizedBox(height: 12),
            Row(
              children: [
                buildIcon(
                  HugeIcons.strokeRoundedCalendar03,
                  size: 15,
                  color: c.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    end == null
                        ? tr('$_i18n.window_open_no_end')
                        : tr(
                            '$_i18n.window_open',
                            namedArgs: {
                              'date': formatInvestitureDate(context, end),
                            },
                          ),
                    style: TextStyle(
                      fontSize: SacFontSize.bodySmall,
                      color: c.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _closedBody(BuildContext context, BoardClosedReason reason) {
    switch (reason) {
      case BoardClosedReason.year:
        return tr('$_i18n.closed.year_body');
      case BoardClosedReason.timeZone:
        return tr('$_i18n.closed.time_zone_body');
      case BoardClosedReason.window:
        final window = ctx.window;
        final today = civilDay(DateTime.now());
        final end = window.endDate;
        final start = window.startDate;
        if (end != null && civilDay(end).isBefore(today)) {
          return tr(
            '$_i18n.closed.window_body_ended',
            namedArgs: {'date': formatInvestitureDate(context, end)},
          );
        }
        if (start != null && civilDay(start).isAfter(today)) {
          return tr(
            '$_i18n.closed.window_body_upcoming',
            namedArgs: {'date': formatInvestitureDate(context, start)},
          );
        }
        return tr('$_i18n.closed.window_body');
    }
  }
}
