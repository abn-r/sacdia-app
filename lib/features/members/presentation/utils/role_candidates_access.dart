import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/domain/utils/authorization_utils.dart';
import '../../../classes/domain/entities/progressive_class.dart';
import '../providers/members_providers.dart';

/// Capacidad con la que el servidor dice que el actor puede asignar cargos en
/// una sección (`SectionRoleMutationPolicy`). Es la misma regla que valida el
/// `POST /clubs/:clubId/sections/:sectionId/roles` con el que se asigna.
const String kAssignSectionRolesCapability = 'club_roles.assign_section';

/// La sección activa es la de Guías Mayores: sus cargos no salen de otra
/// sección, así que ahí no se ofrece «Agregar directivo».
bool isGuideMajorSection(ClubContext context) {
  if (context.clubTypeId == ProgressiveClass.masterGuidesClubTypeId) {
    return true;
  }
  final name = (context.clubTypeName ?? '').trim().toLowerCase();
  return name.contains('guías mayores') ||
      name.contains('guias mayores') ||
      name.contains('master guide');
}

/// El usuario ve «Agregar directivo»: puede asignar cargos de sección Y la
/// sección activa es de Aventureros o Conquistadores (no Guías Mayores).
/// El servidor sigue siendo la autoridad (403 al asignar).
bool canAddBoardMember(UserEntity? user, ClubContext? context) =>
    user != null &&
    context != null &&
    !isGuideMajorSection(context) &&
    hasCapability(user, kAssignSectionRolesCapability);
