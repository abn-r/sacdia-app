import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';

import '../../../../core/utils/role_utils.dart';
import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../domain/entities/insurance_overview.dart';

/// "28 feb" in the app language.
String insuranceShortDate(BuildContext context, DateTime date) =>
    DateFormat.MMMd(context.locale.toString()).format(date.toLocal());

/// "28 feb 2027" in the app language.
String insuranceFullDate(BuildContext context, DateTime date) =>
    DateFormat.yMMMd(context.locale.toString()).format(date.toLocal());

/// Name of a section with its club when both are known
/// ("Guías Mayores · Club Orión").
String? insurancePlace(String? section, String? club) {
  final parts = [
    if (section != null && section.isNotEmpty) section,
    if (club != null && club.isNotEmpty) club,
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// "Consejero · directiva" for staff; the class name for members.
String insuranceRoleLine(InsurancePerson person) {
  final label = person.roleLabel;
  if (person.isStaff) {
    final role = RoleUtils.translate(label);
    final suffix = tr('insurance.person.staff_suffix');
    return role.isEmpty ? suffix : '$role · $suffix';
  }
  return label ?? '';
}

SacStatusKind insuranceStatusKind(InsurancePersonStatus status) =>
    switch (status) {
      InsurancePersonStatus.covered => SacStatusKind.validated,
      InsurancePersonStatus.inOrder ||
      InsurancePersonStatus.inReview =>
        SacStatusKind.review,
      InsurancePersonStatus.proofRejected => SacStatusKind.rejected,
      InsurancePersonStatus.uninsured => SacStatusKind.pending,
    };

String insuranceStatusLabel(InsurancePersonStatus status) => switch (status) {
      InsurancePersonStatus.covered => tr('insurance.status.covered'),
      InsurancePersonStatus.inOrder => tr('insurance.status.in_order'),
      InsurancePersonStatus.inReview => tr('insurance.status.in_review'),
      InsurancePersonStatus.proofRejected => tr('insurance.status.rejected'),
      InsurancePersonStatus.uninsured => tr('insurance.status.uninsured'),
    };

/// The one line under a person's name: the thing that matters in their state.
String insuranceDetail(BuildContext context, InsurancePerson person) {
  final coverage = person.coverage;
  final order = person.activeOrder;
  switch (person.status) {
    case InsurancePersonStatus.uninsured:
      return insuranceRoleLine(person);
    case InsurancePersonStatus.inOrder:
      final expires = order?.expiresAt;
      return expires == null
          ? tr('insurance.detail.in_order')
          : tr(
              'insurance.detail.in_order_until',
              namedArgs: {'date': insuranceShortDate(context, expires)},
            );
    case InsurancePersonStatus.inReview:
      return tr('insurance.detail.in_review');
    case InsurancePersonStatus.proofRejected:
      return tr('insurance.detail.rejected');
    case InsurancePersonStatus.covered:
      switch (coverage?.source) {
        case CoverageSource.paidElsewhere:
          final place = coverage?.paidInSectionName ?? coverage?.paidInClubName;
          return place == null
              ? tr('insurance.detail.paid_elsewhere')
              : tr('insurance.detail.paid_in', namedArgs: {'place': place});
        case CoverageSource.reassigned:
          final from = coverage?.reassignedFromName;
          return from == null
              ? tr('insurance.detail.reassigned')
              : tr('insurance.detail.reassigned_from',
                  namedArgs: {'name': from});
        case CoverageSource.paidHere:
        case null:
          final folio = coverage?.orderFolio;
          return folio == null
              ? tr('insurance.detail.paid')
              : tr('insurance.detail.paid_folio', namedArgs: {'folio': folio});
      }
  }
}

/// Filter of the home list.
enum InsuranceFilter { all, uninsured, inProcess, covered }

bool insuranceFilterMatches(InsuranceFilter filter, InsurancePerson person) =>
    switch (filter) {
      InsuranceFilter.all => true,
      InsuranceFilter.uninsured =>
        person.status == InsurancePersonStatus.uninsured,
      InsuranceFilter.inProcess => person.status.inProcess,
      InsuranceFilter.covered => person.status == InsurancePersonStatus.covered,
    };

/// Lowercase without accents, for the search box.
String insuranceNormalize(String value) {
  const from = 'áàäâãéèëêíìïîóòöôõúùüûñç';
  const to = 'aaaaaeeeeiiiiooooouuuunc';
  final lower = value.toLowerCase();
  final out = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    final i = from.indexOf(ch);
    out.write(i >= 0 ? to[i] : ch);
  }
  return out.toString();
}
