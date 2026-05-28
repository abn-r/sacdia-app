import 'package:easy_localization/easy_localization.dart';

import '../../../investiture/domain/entities/investiture_status.dart';

/// Returns the i18n key that represents a raw investiture backend status.
///
/// Ranking breakdowns receive backend enum values such as `IN_PROGRESS`.
/// Presentation code must translate those values before rendering them.
String rankingInvestitureStatusKey(String? rawStatus) {
  if (rawStatus == null || rawStatus.trim().isEmpty) {
    return 'investiture.status.in_progress';
  }

  final status = InvestitureStatus.fromString(rawStatus);
  switch (status) {
    case InvestitureStatus.inProgress:
      return 'investiture.status.in_progress';
    case InvestitureStatus.submittedForValidation:
      return 'investiture.status.submitted';
    case InvestitureStatus.clubApproved:
      return 'investiture.status.club_approved';
    case InvestitureStatus.coordinatorApproved:
      return 'investiture.status.coordinator_approved';
    case InvestitureStatus.fieldApproved:
      return 'investiture.status.field_approved';
    case InvestitureStatus.approved:
      return 'investiture.status.approved';
    case InvestitureStatus.rejected:
      return 'investiture.status.rejected';
    case InvestitureStatus.investido:
      return 'investiture.status.investido';
    case InvestitureStatus.expired:
      return 'investiture.status.expired';
  }
}

String rankingInvestitureStatusLabel(String? rawStatus) {
  return tr(rankingInvestitureStatusKey(rawStatus));
}
