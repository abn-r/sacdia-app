import 'package:easy_localization/easy_localization.dart';
import 'package:sacdia_app/core/utils/blood_type.dart';
import 'package:sacdia_app/features/investiture/domain/entities/investiture_status.dart';

/// Formatea valores crudos del perfil de miembro para UI de solo lectura.
///
/// Mantiene aquí las conversiones de enums/backend para que la vista no
/// renderice strings técnicos como `O_POSITIVE` o `SUBMITTED_FOR_VALIDATION`.
String? formatMemberBloodTypeDisplay(String? rawBloodType) {
  return BloodType.displayFor(rawBloodType);
}

String? formatMemberBaptismDisplay({
  required bool? baptized,
  required DateTime? baptismDate,
  String? yesLabel,
  String? noLabel,
  DateFormat? dateFormat,
}) {
  if (baptized == null) return null;

  if (!baptized) {
    return noLabel ?? 'common.no'.tr();
  }

  final yes = yesLabel ?? 'common.yes'.tr();
  if (baptismDate == null) return yes;

  final formatter = dateFormat ?? DateFormat('dd/MM/yyyy');
  return '$yes · ${formatter.format(baptismDate)}';
}

InvestitureStatus? memberProfileInvestitureStatus(String? rawStatus) {
  if (rawStatus == null || rawStatus.trim().isEmpty) return null;
  return InvestitureStatus.fromString(rawStatus);
}

String cleanMemberPhoneNumber(String rawPhone) {
  return rawPhone.replaceAll(RegExp(r'[^0-9+]'), '');
}

Uri? memberPhoneDialUri(String rawPhone) {
  final phone = cleanMemberPhoneNumber(rawPhone);
  if (phone.isEmpty) return null;

  return Uri(scheme: 'tel', path: phone);
}
