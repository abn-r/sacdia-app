import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/widgets/sac_sheet.dart';
import 'investiture_date_sheet_body.dart';

/// Abre la hoja para cambiar la fecha de las personas pendientes elegidas.
/// Devuelve la nueva fecha, o `null` si se cancela.
Future<DateTime?> showChangeDateSheet(
  BuildContext context, {
  required int peopleCount,
  required DateTime firstDate,
  required DateTime lastDate,
  required DateTime currentDate,
}) {
  return showSacSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ChangeDateSheet(
      peopleCount: peopleCount,
      firstDate: firstDate,
      lastDate: lastDate,
      currentDate: currentDate,
    ),
  );
}

class ChangeDateSheet extends StatelessWidget {
  const ChangeDateSheet({
    super.key,
    required this.peopleCount,
    required this.firstDate,
    required this.lastDate,
    required this.currentDate,
  });

  final int peopleCount;
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime currentDate;

  @override
  Widget build(BuildContext context) {
    return InvestitureDateSheetBody(
      title: 'investiture_requests.section.sheet.change_date_title'.tr(),
      confirmLabel: 'investiture_requests.section.sheet.confirm_change'.tr(),
      peopleCount: peopleCount,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDate: currentDate,
    );
  }
}
