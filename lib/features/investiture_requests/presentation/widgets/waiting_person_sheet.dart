import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/utils/icon_helper.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_badge.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_pressable.dart';
import '../../../../core/widgets/sac_sheet.dart';
import '../../domain/entities/investiture_request.dart';
import '../utils/investiture_dates.dart';
import 'investiture_rows.dart';

const _i18n = 'investiture_requests.section.waiting_sheet';

/// Lo que la directiva pide hacer con una persona en espera.
enum WaitingPersonAction { changeDate, remove }

/// Abre la hoja de una persona en espera: cambiar su fecha, ver quién autoriza
/// y retirarla de la solicitud. Devuelve la acción elegida (la ejecuta el
/// llamador) o `null` si se cierra.
///
/// [canManage] es falso con la ventana o el año cerrados: la hoja solo informa.
Future<WaitingPersonAction?> showWaitingPersonSheet(
  BuildContext context, {
  required RequestPerson person,
  required String name,
  String? pastor,
  DateTime? sentAt,
  bool canManage = true,
}) {
  return showSacSheet<WaitingPersonAction>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => WaitingPersonSheet(
      person: person,
      name: name,
      pastor: pastor,
      sentAt: sentAt,
      canManage: canManage,
    ),
  );
}

class WaitingPersonSheet extends StatelessWidget {
  const WaitingPersonSheet({
    super.key,
    required this.person,
    required this.name,
    this.pastor,
    this.sentAt,
    this.canManage = true,
  });

  final RequestPerson person;
  final String name;
  final String? pastor;
  final DateTime? sentAt;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final detail = [
      if (person.className != null && person.className!.isNotEmpty)
        person.className!,
      if (sentAt != null)
        tr(
          '$_i18n.sent_on',
          namedArgs: {'date': formatInvestitureDate(context, sentAt!)},
        ),
    ].join(' · ');

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLG),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SacSheetGrabber(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  InvestitureAvatar(name: name),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: SacFontSize.titleLarge,
                            fontWeight: FontWeight.w700,
                            color: c.text,
                          ),
                        ),
                        if (detail.isNotEmpty)
                          Text(
                            detail,
                            style: TextStyle(
                              fontSize: SacFontSize.bodySmall,
                              color: c.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SacBadge.info(
                      label: tr('investiture_requests.section.pending_badge')),
                ],
              ),
            ),
            Divider(height: 1, color: c.divider),
            _ActionRow(
              icon: HugeIcons.strokeRoundedCalendar03,
              title: tr('$_i18n.change_date'),
              detail: formatInvestitureDate(context, person.investitureDate),
              showChevron: true,
              onTap: canManage
                  ? () =>
                      Navigator.of(context).pop(WaitingPersonAction.changeDate)
                  : null,
            ),
            Divider(height: 1, color: c.divider),
            _ActionRow(
              icon: HugeIcons.strokeRoundedChurch,
              title: tr('$_i18n.authorizer'),
              detail: pastor ?? tr('$_i18n.authorizer_generic'),
            ),
            if (canManage)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: SacButton.outline(
                  text: tr('$_i18n.remove'),
                  icon: HugeIcons.strokeRoundedDelete02,
                  textColor: c.onErrorContainer,
                  borderColor: c.onErrorContainer.withValues(alpha: 0.4),
                  onPressed: () =>
                      Navigator.of(context).pop(WaitingPersonAction.remove),
                ),
              )
            else
              const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.detail,
    this.onTap,
    this.showChevron = false,
  });

  final HugeIconData icon;
  final String title;
  final String detail;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final body = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            InvestitureIconBadge(
              icon: icon,
              background: c.surfaceVariant,
              foreground: c.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: SacFontSize.titleMedium,
                      fontWeight: FontWeight.w500,
                      color: c.text,
                    ),
                  ),
                  Text(
                    detail,
                    style: TextStyle(
                      fontSize: SacFontSize.bodySmall,
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (showChevron && onTap != null) const InvestitureChevron(),
          ],
        ),
      ),
    );
    return onTap == null
        ? Semantics(container: true, child: body)
        : Semantics(button: true, child: SacInkWell(onTap: onTap, child: body));
  }
}
