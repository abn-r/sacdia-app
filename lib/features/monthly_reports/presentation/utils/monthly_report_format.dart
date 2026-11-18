import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';

import '../../domain/entities/monthly_report.dart';

/// Fecha corta ("6 nov") con el idioma de la app.
String monthlyReportShortDate(BuildContext context, DateTime date) {
  final locale = Localizations.localeOf(context).toString();
  return DateFormat.MMMd(locale).format(date.toLocal());
}

/// Día en que el sistema genera el informe de [month]/[year]: [dueDay] del mes
/// siguiente.
DateTime monthlyReportGenerationDate(int month, int year, int dueDay) =>
    DateTime(year, month + 1, dueDay);

/// Nombre de una sección manual ("Actividad misionera").
String monthlyReportSectionTitle(MonthlyReportManualSection section) =>
    tr('monthly_reports.sections.${section.name}');

/// "Faltan 2 secciones".
String monthlyReportPendingSections(int count) =>
    'monthly_reports.pending_sections'.plural(count);
