import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/widgets/sac_sheet.dart';
import 'investiture_date_sheet_body.dart';

/// Abre la hoja para presentar personas (solicitud nueva) o agregarlas a la
/// solicitud abierta. Devuelve la fecha elegida, o `null` si se cancela.
///
/// Con [adding] y [previousDate] (solicitud existente) esa fecha es el valor
/// inicial (IA-21); si no, hay que elegir una (IA-20).
Future<DateTime?> showPresentSheet(
  BuildContext context, {
  required int peopleCount,
  required DateTime firstDate,
  required DateTime lastDate,
  bool adding = false,
  DateTime? previousDate,
}) {
  return showSacSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => PresentSheet(
      peopleCount: peopleCount,
      firstDate: firstDate,
      lastDate: lastDate,
      adding: adding,
      previousDate: previousDate,
    ),
  );
}

class PresentSheet extends StatelessWidget {
  const PresentSheet({
    super.key,
    required this.peopleCount,
    required this.firstDate,
    required this.lastDate,
    this.adding = false,
    this.previousDate,
  });

  final int peopleCount;
  final DateTime firstDate;
  final DateTime lastDate;

  /// `true` cuando se suma gente a la solicitud abierta.
  final bool adding;
  final DateTime? previousDate;

  @override
  Widget build(BuildContext context) {
    return InvestitureDateSheetBody(
      title: adding
          ? 'investiture_requests.section.sheet.add_title'.tr()
          : 'investiture_requests.section.sheet.present_title'.tr(),
      confirmLabel: adding
          ? 'investiture_requests.section.sheet.confirm_add'.tr()
          : 'investiture_requests.section.sheet.confirm_present'.tr(),
      peopleCount: peopleCount,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDate: previousDate,
      previousDate: previousDate,
    );
  }
}
