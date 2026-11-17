import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../data/investiture_request_error_keys.dart';
import '../../domain/entities/investiture_request.dart';
import '../../domain/entities/investiture_resolution.dart';
import '../../domain/entities/person_status.dart';
import 'investiture_rows.dart';

const _i18n = 'investiture_requests.authorizer.result';

/// Resultado de confirmar las decisiones: qué pasó con cada grupo, en lenguaje
/// claro. La pantalla pone debajo el botón que regresa a la lista.
class AuthorizerResult extends StatelessWidget {
  const AuthorizerResult({
    super.key,
    required this.resolution,
    required this.request,
    required this.subtitle,
  });

  final InvestitureResolution resolution;

  /// Solicitud vigente, para resolver el nombre de quienes solo traen su id.
  final InvestitureRequest? request;

  /// "Club Orión · Conquistadores · 14 dic".
  final String subtitle;

  String _nameOf(String personId) {
    for (final person in request?.people ?? const <RequestPerson>[]) {
      if (person.personId == personId) {
        final name = person.userName?.trim();
        if (name != null && name.isNotEmpty) return name;
      }
    }
    return tr('investiture_requests.section.unnamed_person');
  }

  String _names(Iterable<RequestPerson> people) => people
      .map(
        (p) => p.userName?.trim().isNotEmpty ?? false
            ? p.userName!.trim()
            : tr('investiture_requests.section.unnamed_person'),
      )
      .join(', ');

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final r = resolution;

    Widget row({
      required HugeIconData icon,
      required Color background,
      required Color foreground,
      required String title,
      String? detail,
      Key? key,
    }) =>
        InvestitureRow(
          key: key,
          leading: InvestitureIconBadge(
            icon: icon,
            background: background,
            foreground: foreground,
          ),
          title: title,
          detail: detail,
          detailMaxLines: 3,
        );

    final rows = <Widget>[
      if (r.invested.isNotEmpty)
        row(
          key: const ValueKey('result-invested'),
          icon: HugeIcons.strokeRoundedMedal01,
          background: c.successContainer,
          foreground: c.onSuccessContainer,
          title: '$_i18n.invested'.plural(r.invested.length),
          detail: _names(r.invested),
        ),
      if (r.rejectedByPerson.isNotEmpty)
        row(
          key: const ValueKey('result-rejected'),
          icon: HugeIcons.strokeRoundedCancel01,
          background: c.errorContainer,
          foreground: c.onErrorContainer,
          title: '$_i18n.rejected'.plural(r.rejectedByPerson.length),
          detail: _names(r.rejectedByPerson),
        ),
      if (r.rejectedBySystem.isNotEmpty)
        row(
          icon: HugeIcons.strokeRoundedAlert02,
          background: c.errorContainer,
          foreground: c.onErrorContainer,
          title: tr(
            '$_i18n.rejected_by_system',
            namedArgs: {'count': '${r.rejectedBySystem.length}'},
          ),
          detail: _names(r.rejectedBySystem),
        ),
      if (r.retired.isNotEmpty)
        row(
          icon: HugeIcons.strokeRoundedInformationCircle,
          background: c.surfaceVariant,
          foreground: c.textSecondary,
          title: tr(
            '$_i18n.retired',
            namedArgs: {'count': '${r.retired.length}'},
          ),
          detail: '${_names(r.retired)}. ${tr('$_i18n.retired_note')}',
        ),
      if (r.blocked.isNotEmpty)
        row(
          icon: HugeIcons.strokeRoundedAlert02,
          background: c.warningContainer,
          foreground: c.onWarningContainer,
          title: tr(
            '$_i18n.blocked',
            namedArgs: {'count': '${r.blocked.length}'},
          ),
          detail: r.blocked
              .map(
                (b) =>
                    '${_nameOf(b.personId)}: ${investitureRequestErrorMessage(b.code) ?? tr('investiture_requests.errors.generic')}',
              )
              .join('\n'),
        ),
      if (r.alreadyResolved.isNotEmpty)
        row(
          icon: HugeIcons.strokeRoundedInformationCircle,
          background: c.surfaceVariant,
          foreground: c.textSecondary,
          title: tr(
            '$_i18n.already_resolved',
            namedArgs: {'count': '${r.alreadyResolved.length}'},
          ),
          detail: r.alreadyResolved
              .map((a) => '${_nameOf(a.personId)}: ${_alreadyNote(a.status)}')
              .join('\n'),
        ),
    ];

    return Column(
      key: const ValueKey('authorizer-result'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 40),
        Center(
          child: Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.successContainer,
              shape: BoxShape.circle,
            ),
            child: buildIcon(
              HugeIcons.strokeRoundedCheckmarkCircle02,
              size: 30,
              color: c.onSuccessContainer,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Semantics(
          header: true,
          child: Text(
            tr('$_i18n.title'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: SacFontSize.headlineMedium,
              fontWeight: FontWeight.w700,
              color: c.text,
            ),
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: SacFontSize.titleSmall,
              color: c.textSecondary,
            ),
          ),
        ],
        if (rows.isNotEmpty)
          SacGroupedSection(
            label: tr('$_i18n.group'),
            count: rows.length,
            children: rows,
          ),
      ],
    );
  }

  String _alreadyNote(PersonStatus status) => switch (status) {
        PersonStatus.invested => tr('$_i18n.already_invested'),
        PersonStatus.rejected ||
        PersonStatus.rejectedByPerson ||
        PersonStatus.rejectedBySystem =>
          tr('$_i18n.already_rejected'),
        _ => tr('$_i18n.already_other'),
      };
}
