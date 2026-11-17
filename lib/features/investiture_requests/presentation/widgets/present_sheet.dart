import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_date_picker.dart';
import '../../../../core/widgets/sac_sheet.dart';
import '../../../activities/presentation/widgets/activity_form_widgets.dart';
import '../../domain/entities/presentation_context.dart';
import '../utils/investiture_dates.dart';
import 'investiture_rows.dart';

const _i18n = 'investiture_requests.section.sheet';

/// Abre la hoja para enviar personas a autorización: fecha de investidura, las
/// personas elegidas y a quién le llegará. Devuelve la fecha elegida, o `null`
/// si se cancela. La solicitud existente (o nueva) la resuelve el backend.
///
/// Con [currentDate] (ya hay una solicitud abierta) esa fecha es el valor
/// inicial; si no, hay que elegir una.
Future<DateTime?> showPresentSheet(
  BuildContext context, {
  required List<PresentationCandidate> people,
  required DateTime firstDate,
  required DateTime lastDate,
  String? pastor,
  DateTime? currentDate,
}) {
  return showSacSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => PresentSheet(
      people: people,
      firstDate: firstDate,
      lastDate: lastDate,
      pastor: pastor,
      currentDate: currentDate,
    ),
  );
}

class PresentSheet extends StatefulWidget {
  const PresentSheet({
    super.key,
    required this.people,
    required this.firstDate,
    required this.lastDate,
    this.pastor,
    this.currentDate,
  });

  final List<PresentationCandidate> people;
  final DateTime firstDate;
  final DateTime lastDate;

  /// "Ptr. Samuel Ibarra"; `null` si el backend no informa quién autoriza.
  final String? pastor;
  final DateTime? currentDate;

  @override
  State<PresentSheet> createState() => _PresentSheetState();
}

class _PresentSheetState extends State<PresentSheet> {
  DateTime? _date;

  @override
  void initState() {
    super.initState();
    final current = widget.currentDate;
    _date = current == null
        ? null
        : clampCivilDay(
            civilDay(current),
            civilDay(widget.firstDate),
            civilDay(widget.lastDate),
          );
  }

  Future<void> _pickDate() async {
    final first = civilDay(widget.firstDate);
    final last = civilDay(widget.lastDate);
    final picked = await showSacDatePicker(
      context: context,
      initialDate:
          clampCivilDay(_date ?? civilDay(DateTime.now()), first, last),
      firstDate: first,
      lastDate: last,
      locale: context.locale,
    );
    if (picked != null && mounted) setState(() => _date = civilDay(picked));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final pastor = widget.pastor;
    final subtitle = pastor == null
        ? tr('$_i18n.reviewer_generic')
        : tr('$_i18n.reviewer', namedArgs: {'name': pastor});

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
            SacSheetHeader(
              title: tr(
                '$_i18n.present_title',
                namedArgs: {'count': '${widget.people.length}'},
              ),
              subtitle: '$subtitle ${tr('$_i18n.progress_locked')}',
              showClose: true,
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ActivityDatePickerField(
                      label: tr('$_i18n.date_label'),
                      value: _date,
                      enabled: true,
                      onTap: _pickDate,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tr(
                        '$_i18n.window_hint',
                        namedArgs: {
                          'start':
                              formatInvestitureDate(context, widget.firstDate),
                          'end':
                              formatInvestitureDate(context, widget.lastDate),
                        },
                      ),
                      style: TextStyle(
                        fontSize: SacFontSize.bodySmall,
                        color: c.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      tr('$_i18n.people_label'),
                      style: TextStyle(
                        fontSize: SacFontSize.bodyMedium,
                        fontWeight: FontWeight.w600,
                        color: c.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Material(
                      color: c.surface,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                        side: BorderSide(color: c.border),
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < widget.people.length; i++) ...[
                            if (i > 0) Divider(height: 1, color: c.divider),
                            _PersonLine(candidate: widget.people[i]),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: SacButton.primary(
                text: tr('$_i18n.confirm_present'),
                onPressed: _date == null
                    ? null
                    : () => Navigator.of(context).pop(_date),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonLine extends StatelessWidget {
  const _PersonLine({required this.candidate});

  final PresentationCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final name = candidate.userName?.trim().isNotEmpty ?? false
        ? candidate.userName!.trim()
        : tr('investiture_requests.section.unnamed_person');
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            InvestitureAvatar(name: name, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: SacFontSize.titleSmall,
                  fontWeight: FontWeight.w600,
                  color: c.text,
                ),
              ),
            ),
            if (candidate.className != null) ...[
              const SizedBox(width: 8),
              Text(
                candidate.className!,
                style: TextStyle(
                  fontSize: SacFontSize.bodySmall,
                  color: c.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
