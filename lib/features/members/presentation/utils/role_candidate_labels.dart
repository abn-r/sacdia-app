import 'package:easy_localization/easy_localization.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/errors/user_error_message.dart';
import '../../../../core/utils/role_utils.dart';
import '../../domain/entities/role_candidate.dart';

const _k = 'members.role_candidates';

/// Cargo traducido; el género solo se aplica si el servidor lo envió.
String candidateRoleLabel(String role, {String? gender}) =>
    RoleUtils.translate(role, gender: gender);

/// D2: «Investido 2019» · «Investido» · «GM aprobado, sin investir» ·
/// «GM en curso». `null` si no hay base conocida.
String? guideMajorBasisLabel(RoleCandidateGuideMajor? gm) {
  if (gm == null) return null;
  switch (gm.basis) {
    case GuideMajorBasis.invested:
      final year = gm.investitureYear;
      return year == null
          ? '$_k.basis_invested'.tr()
          : tr('$_k.basis_invested_year', namedArgs: {'year': year});
    case GuideMajorBasis.approved:
      return '$_k.basis_approved'.tr();
    case GuideMajorBasis.activeEnrollment:
      return '$_k.basis_active_enrollment'.tr();
    case GuideMajorBasis.unknown:
      return null;
  }
}

/// Etiquetas de las fichas de una fila: base de Guía Mayor, «Avanzado»,
/// «Instructor». Cada ficha se pinta por separado.
List<String> guideMajorTags(RoleCandidateGuideMajor? gm) => [
      if (guideMajorBasisLabel(gm) case final basis?) basis,
      if (gm?.advanced == true) '$_k.tag_advanced'.tr(),
      if (gm?.instructor == true) '$_k.tag_instructor'.tr(),
    ];

/// Título del grupo («Sin cargo este año», «Ya con cargo», «Sin inscripción 2026»).
String roleCandidateGroupTitle(RoleCandidateGroup group, {String? year}) =>
    switch (group) {
      RoleCandidateGroup.available => '$_k.group_available'.tr(),
      RoleCandidateGroup.withRole => '$_k.group_with_role'.tr(),
      RoleCandidateGroup.notEnrolled => year == null || year.isEmpty
          ? '$_k.group_not_enrolled_no_year'.tr()
          : tr('$_k.group_not_enrolled', namedArgs: {'year': year}),
    };

/// Texto del chip de filtro.
String roleCandidateFilterLabel(RoleCandidatesFilter filter) =>
    switch (filter) {
      RoleCandidatesFilter.available => '$_k.filter_available'.tr(),
      RoleCandidatesFilter.withRole => '$_k.filter_with_role'.tr(),
      RoleCandidatesFilter.notEnrolled => '$_k.filter_not_enrolled'.tr(),
      RoleCandidatesFilter.all => '$_k.filter_all'.tr(),
    };

/// «Consejeros 3» (sin tope) usa el plural; con tope, «Subdirector 1/2».
String roleSlotLabel(RoleSlot slot) {
  final max = slot.max;
  if (max != null) {
    return tr('$_k.slot_counter', namedArgs: {
      'role': candidateRoleLabel(slot.role),
      'occupied': '${slot.occupied}',
      'max': '$max',
    });
  }
  final pluralKey = '$_k.plural.${slot.role.replaceAll('-', '_')}';
  final plural = pluralKey.tr();
  return tr('$_k.slot_count', namedArgs: {
    'role': plural == pluralKey ? candidateRoleLabel(slot.role) : plural,
    'count': '${slot.occupied}',
  });
}

/// Estado de un cargo en el paso 2: «1 de 2 ocupados» / «1 asignado».
String roleSlotStateLabel(RoleSlot? slot) {
  if (slot == null) return '';
  final max = slot.max;
  if (max == null) {
    return '$_k.slot_state_unbounded'.plural(slot.occupied);
  }
  return tr('$_k.slot_state', namedArgs: {
    'occupied': '${slot.occupied}',
    'max': '$max',
  });
}

/// Por qué [role] no se puede elegir para esta persona (paso 2). `null` si sí.
String? roleDisabledReason(
  String role,
  RoleCandidate candidate,
  RoleSlot? slot,
) {
  if (candidate.allowedRoles.contains(role)) return null;
  if (slot != null && slot.isFull) {
    return slot.holders.isEmpty
        ? '$_k.reason_full'.tr()
        : tr('$_k.reason_occupied_by',
            namedArgs: {'names': slot.holders.join(', ')});
  }
  if (slot != null && slot.blockedBy.isNotEmpty) {
    return tr('$_k.reason_incompatible', namedArgs: {
      'role': slot.blockedBy.map(candidateRoleLabel).join(', '),
    });
  }
  if (candidate.requirementFor(role)?.blocksAssignment == true) {
    return '$_k.credential.reason_missing'.tr();
  }
  return '$_k.reason_unavailable'.tr();
}

/// «Consejero · Conquistadores» y, si es esta sección, «(esta sección)».
String currentRoleLabel(RoleCandidateCurrentRole r, int sectionId,
    {String? gender}) {
  final role = candidateRoleLabel(r.role, gender: gender);
  final club = r.clubTypeName;
  final base = club == null || club.isEmpty
      ? role
      : tr('$_k.role_in_club', namedArgs: {'role': role, 'club': club});
  return r.sectionId == sectionId
      ? tr('$_k.role_in_this_section', namedArgs: {'role': base})
      : base;
}

/// Segunda línea de la fila (primera que aplique):
/// sin inscripción · falta consentimiento · cargos actuales · edad y servicio.
String? roleCandidateSubtitle(RoleCandidate c, int sectionId) {
  if (c.group == RoleCandidateGroup.notEnrolled ||
      c.blockedReason == RoleCandidateBlockedReason.gmMembershipRequired) {
    return '$_k.needs_enrollment'.tr();
  }
  if (c.isConsentMissing) return '$_k.consent_missing'.tr();
  if (c.currentRoles.isNotEmpty) {
    return c.currentRoles
        .map((r) => currentRoleLabel(r, sectionId, gender: c.gender))
        .join('; ');
  }
  if (c.blockedReason == RoleCandidateBlockedReason.selfAssignment) {
    return '$_k.blocked_self'.tr();
  }
  // Nothing left to offer (full slots and/or a required constancia): say so,
  // otherwise the row looks tappable for no reason.
  if (c.allowedRoles.isEmpty) {
    final missingCredential = c.requirements.any((r) => r.blocksAssignment);
    return [
      '$_k.no_roles_available'.tr(),
      if (missingCredential) '$_k.credential.reason_missing'.tr(),
    ].join(' · ');
  }
  final parts = <String>[
    if (c.age != null) tr('$_k.age_years', namedArgs: {'count': '${c.age}'}),
    if (c.serviceYears != null && c.serviceYears! > 0)
      '$_k.service_years'.plural(c.serviceYears!),
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// Los códigos que el `POST` de asignación puede devolver y que cambian la
/// foto de cupos: tras ellos se recarga la lista.
const Set<String> kRoleAssignStaleCodes = {
  'CLUB_ROLE_SLOT_LIMIT_REACHED',
  'CLUB_ROLE_EXCLUSIVE_CONFLICT',
  'CLUB_ROLE_GM_MEMBERSHIP_REQUIRED',
  'CLUB_ROLE_ALREADY_HELD',
  'MR_CONSENT_NOT_VERIFIED',
  'CLUB_ROLE_REQUIREMENT_MISSING',
};

/// Mensaje de un fallo al asignar un cargo. Solo mira `errorCode` (nunca
/// `details`): `errors.<codigo>`; el de consentimiento usa el texto propio de
/// asignar (el genérico habla de «aprobar» una solicitud).
String roleAssignErrorMessage(Failure failure) {
  if (failure.errorCode == RoleCandidateBlockedReason.consentNotVerified) {
    return 'members.role_assignment.consent_not_verified'.tr();
  }
  return userErrorMessage(
    failure,
    fallbackKey: 'members.role_assignment.assign_error',
  );
}

/// «Aprobada» / «En revisión» / «Sin constancia».
String credentialStatusLabel(CredentialStatus status) => switch (status) {
      CredentialStatus.approved => '$_k.credential.status_approved'.tr(),
      CredentialStatus.pendingReview =>
        '$_k.credential.status_pending_review'.tr(),
      CredentialStatus.rejected => '$_k.credential.status_none'.tr(),
    };

/// Nota bajo el título según la exigencia más estricta (`null` sin requisitos).
String? requirementSeverityNote(int? severity) => switch (severity) {
      null => null,
      0 => '$_k.credential.note_info'.tr(),
      1 => '$_k.credential.note_warn'.tr(),
      _ => '$_k.credential.note_block'.tr(),
    };
