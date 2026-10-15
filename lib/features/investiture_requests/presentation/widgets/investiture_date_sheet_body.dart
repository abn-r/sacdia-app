import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_sheet.dart';
import '../../../activities/presentation/widgets/activity_form_widgets.dart';
import '../utils/investiture_dates.dart';

/// Cuerpo común de las hojas de fecha de investidura: encabezado, selector de
/// fecha (obligatorio) y botón de confirmar.
///
/// Cierra con la fecha elegida (`Navigator.pop(date)`); el llamador ejecuta la
/// acción y muestra el resultado, así el error aparece sobre la pantalla y no
/// dentro de la hoja.
class InvestitureDateSheetBody extends StatefulWidget {
  const InvestitureDateSheetBody({
    super.key,
    required this.title,
    required this.peopleCount,
    required this.confirmLabel,
    required this.firstDate,
    required this.lastDate,
    this.initialDate,
    this.previousDate,
  });

  final String title;
  final int peopleCount;
  final String confirmLabel;

  /// Rango permitido (ventana del Campo recortada al año eclesiástico).
  final DateTime firstDate;
  final DateTime lastDate;

  /// Valor con el que abre la hoja; `null` obliga a elegir (IA-20).
  final DateTime? initialDate;

  /// Fecha vigente de la solicitud, cuando se agrega a una existente (IA-21).
  final DateTime? previousDate;

  @override
  State<InvestitureDateSheetBody> createState() =>
      _InvestitureDateSheetBodyState();
}

class _InvestitureDateSheetBodyState extends State<InvestitureDateSheetBody> {
  DateTime? _date;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialDate;
    _date = initial == null
        ? null
        : clampCivilDay(
            civilDay(initial),
            civilDay(widget.firstDate),
            civilDay(widget.lastDate),
          );
  }

  Future<void> _pickDate() async {
    final first = civilDay(widget.firstDate);
    final last = civilDay(widget.lastDate);
    final picked = await showDatePicker(
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
    final theme = Theme.of(context);
    final previous = widget.previousDate;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLG),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SacSheetHeader(
                title: widget.title,
                subtitle: 'investiture_requests.section.sheet.people'
                    .tr(namedArgs: {'count': '${widget.peopleCount}'}),
                showClose: true,
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ActivityDatePickerField(
                      label:
                          'investiture_requests.section.sheet.date_label'.tr(),
                      value: _date,
                      enabled: true,
                      onTap: _pickDate,
                    ),
                    const SizedBox(height: 10),
                    if (previous != null) ...[
                      Text(
                        'investiture_requests.section.sheet.previous_date'.tr(
                          namedArgs: {
                            'date': formatInvestitureDate(context, previous),
                          },
                        ),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: c.textSecondary),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      'investiture_requests.section.sheet.window_range'.tr(
                        namedArgs: {
                          'start':
                              formatInvestitureDate(context, widget.firstDate),
                          'end':
                              formatInvestitureDate(context, widget.lastDate),
                        },
                      ),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: c.textSecondary),
                    ),
                    if (_date == null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'investiture_requests.section.sheet.date_required'.tr(),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: c.textSecondary),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SacButton.primary(
                      text: widget.confirmLabel,
                      onPressed: _date == null
                          ? null
                          : () => Navigator.of(context).pop(_date),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
