import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../data/investiture_request_error_keys.dart';
import '../../domain/entities/investiture_request.dart';
import '../../domain/entities/investiture_resolution.dart';
import '../../domain/entities/person_status.dart';

const _i18n = 'investiture_requests.authorizer.summary';

/// Resumen del resultado de confirmar las decisiones: quiénes quedaron
/// investidos, rechazados (por quien decidió o por el sistema, con su texto
/// largo), retirados y las decisiones que no se aplicaron con su motivo.
class ResolutionSummary extends StatelessWidget {
  const ResolutionSummary({
    super.key,
    required this.resolution,
    required this.request,
    required this.onDismiss,
  });

  final InvestitureResolution resolution;

  /// Solicitud vigente, para resolver el nombre de quienes solo traen su id.
  final InvestitureRequest? request;
  final VoidCallback onDismiss;

  String _nameOf(String personId) {
    for (final person in request?.people ?? const <RequestPerson>[]) {
      if (person.personId == personId) {
        final name = person.userName?.trim();
        if (name != null && name.isNotEmpty) return name;
      }
    }
    return tr('investiture_requests.section.unnamed_person');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final dark = Theme.brightnessOf(context) == Brightness.dark;
    final accent = AppColors.sentColor;

    final groups = <Widget>[
      if (resolution.invested.isNotEmpty)
        _Group(
          title: tr('$_i18n.invested', namedArgs: _count(resolution.invested)),
          icon: HugeIcons.strokeRoundedCheckmarkCircle02,
          color: AppColors.validatedColor,
          lines: [for (final p in resolution.invested) _line(p.userName)],
        ),
      if (resolution.rejectedByPerson.isNotEmpty)
        _Group(
          title: tr(
            '$_i18n.rejected',
            namedArgs: _count(resolution.rejectedByPerson),
          ),
          icon: HugeIcons.strokeRoundedCancelCircle,
          color: AppColors.coral700,
          lines: [
            for (final p in resolution.rejectedByPerson) _line(p.userName),
          ],
        ),
      if (resolution.rejectedBySystem.isNotEmpty)
        _Group(
          title: tr(
            '$_i18n.rejected_by_system',
            namedArgs: _count(resolution.rejectedBySystem),
          ),
          icon: HugeIcons.strokeRoundedAlert02,
          color: AppColors.coral700,
          lines: [
            for (final p in resolution.rejectedBySystem)
              _line(p.userName, detail: p.systemReason),
          ],
        ),
      if (resolution.retired.isNotEmpty)
        _Group(
          title: tr('$_i18n.retired', namedArgs: _count(resolution.retired)),
          icon: HugeIcons.strokeRoundedInformationCircle,
          color: accent,
          lines: [
            for (final p in resolution.retired)
              _line(p.userName, detail: tr('$_i18n.retired_note')),
          ],
        ),
      if (resolution.blocked.isNotEmpty)
        _Group(
          title: tr('$_i18n.blocked', namedArgs: _count(resolution.blocked)),
          icon: HugeIcons.strokeRoundedAlert02,
          color: AppColors.coral700,
          lines: [
            for (final b in resolution.blocked)
              _line(
                _nameOf(b.personId),
                detail: investitureRequestErrorMessage(b.code) ??
                    tr('investiture_requests.errors.generic'),
              ),
          ],
        ),
      if (resolution.alreadyResolved.isNotEmpty)
        _Group(
          title: tr(
            '$_i18n.already_resolved',
            namedArgs: _count(resolution.alreadyResolved),
          ),
          icon: HugeIcons.strokeRoundedInformationCircle,
          color: accent,
          lines: [
            for (final r in resolution.alreadyResolved)
              _line(
                _nameOf(r.personId),
                detail: _alreadyNote(r.status),
              ),
          ],
        ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? accent.withValues(alpha: 0.16) : AppColors.sentBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              tr('$_i18n.title'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: c.ink900,
              ),
            ),
          ),
          for (final group in groups) ...[
            const SizedBox(height: 14),
            group,
          ],
          const SizedBox(height: 14),
          SacButton.outline(
            text: tr('$_i18n.dismiss'),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }

  static Map<String, String> _count(List<Object?> items) =>
      {'count': '${items.length}'};

  _Line _line(String? name, {String? detail}) => _Line(
        name: (name == null || name.trim().isEmpty)
            ? tr('investiture_requests.section.unnamed_person')
            : name.trim(),
        detail: detail?.trim().isEmpty ?? true ? null : detail!.trim(),
      );

  String _alreadyNote(PersonStatus status) => switch (status) {
        PersonStatus.invested => tr('$_i18n.already_invested'),
        PersonStatus.rejectedByPerson ||
        PersonStatus.rejectedBySystem ||
        PersonStatus.rejected =>
          tr('$_i18n.already_rejected'),
        _ => tr('$_i18n.already_other'),
      };
}

class _Line {
  const _Line({required this.name, this.detail});

  final String name;
  final String? detail;
}

class _Group extends StatelessWidget {
  const _Group({
    required this.title,
    required this.icon,
    required this.color,
    required this.lines,
  });

  final String title;
  final List<List<dynamic>> icon;
  final Color color;
  final List<_Line> lines;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            HugeIcon(icon: icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: c.ink900,
                ),
              ),
            ),
          ],
        ),
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(left: 26, top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.ink800,
                  ),
                ),
                if (line.detail != null)
                  Text(
                    line.detail!,
                    style: TextStyle(
                      fontSize: 13,
                      color: c.ink600,
                      height: 1.35,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
