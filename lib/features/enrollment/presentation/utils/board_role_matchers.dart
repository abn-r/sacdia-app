import 'package:sacdia_app/core/auth/club_role_names.dart';

/// Spanish alias key (normalized) of a canonical role, read from the shared
/// alias table so no role literal lives here.
String _spanishAliasOf(String canonical) => kClubRoleSpanishAliases.entries
    .firstWhere((e) => e.value == canonical && e.key != canonical)
    .key;

final _deputyFragment = ClubRoleNames.deputyDirector.split('-').first;
final _subdirector = _spanishAliasOf(ClubRoleNames.deputyDirector);
final _secretarioTesorero = _spanishAliasOf(ClubRoleNames.secretaryTreasurer);

/// Deputy director: canonical value, or defensively anything containing
/// `deputy` / the Spanish alias `subdirector`.
bool isDeputyDirectorRole(String? raw) {
  final role = normalizeClubRoleName(raw);
  return role == ClubRoleNames.deputyDirector ||
      role.contains(_deputyFragment) ||
      role.contains(_subdirector);
}

/// Secretary (exact canonical value only, as the form always did).
bool isSecretaryRole(String? raw) =>
    normalizeClubRoleName(raw) == ClubRoleNames.secretary;

/// Treasurer (exact canonical value only, as the form always did).
bool isTreasurerRole(String? raw) =>
    normalizeClubRoleName(raw) == ClubRoleNames.treasurer;

/// Combined secretary-treasurer. After normalization `secretary_treasurer`
/// becomes `secretary-treasurer`, so the old snake_case equality and the
/// two `contains` checks collapse into the canonical value plus the
/// Spanish alias.
bool isSecretaryTreasurerRole(String? raw) {
  final role = normalizeClubRoleName(raw);
  return role == ClubRoleNames.secretaryTreasurer ||
      role.contains(ClubRoleNames.secretaryTreasurer) ||
      role.contains(_secretarioTesorero);
}

/// Director proper: contains `director` but is not a deputy / sub / vice.
bool isDirectorRole(String? raw) {
  final role = normalizeClubRoleName(raw);
  return role.contains(ClubRoleNames.director) &&
      !role.contains('sub') &&
      !role.contains('vice') &&
      !role.contains(_deputyFragment);
}
