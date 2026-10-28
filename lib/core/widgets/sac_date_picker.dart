import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// [showDatePicker] with sentence-case action buttons from i18n.
///
/// Material's own labels are locale-specific and inconsistent (for Spanish the
/// confirm button comes out as "ACEPTAR" next to a "Cancelar"). Explicit
/// [cancelText] / [confirmText] still win.
Future<DateTime?> showSacDatePicker({
  required BuildContext context,
  required DateTime firstDate,
  required DateTime lastDate,
  DateTime? initialDate,
  DateTime? currentDate,
  DatePickerEntryMode initialEntryMode = DatePickerEntryMode.calendar,
  SelectableDayPredicate? selectableDayPredicate,
  String? helpText,
  String? cancelText,
  String? confirmText,
  Locale? locale,
  DatePickerMode initialDatePickerMode = DatePickerMode.day,
  TransitionBuilder? builder,
}) {
  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    currentDate: currentDate,
    initialEntryMode: initialEntryMode,
    selectableDayPredicate: selectableDayPredicate,
    helpText: helpText,
    cancelText: cancelText ?? 'common.cancel'.tr(),
    confirmText: confirmText ?? 'common.picker_confirm'.tr(),
    locale: locale,
    initialDatePickerMode: initialDatePickerMode,
    builder: builder,
  );
}
