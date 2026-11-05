import 'package:sacdia_app/core/auth/club_role_names.dart';
import 'package:sacdia_app/features/members/domain/entities/club_member.dart';

/// Whether [member] can be assigned as responsible of a class: they must be
/// class-counselor eligible and hold the counselor or secretary role (the
/// Spanish `consejero` / `secretario` aliases are accepted too).
bool isAssignableResponsible(ClubMember member) {
  if (!member.classCounselorEligible) return false;

  final role = canonicalClubRoleName(member.clubRole);
  return role == ClubRoleNames.counselor || role == ClubRoleNames.secretary;
}
