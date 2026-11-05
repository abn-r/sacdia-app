/// Canonical CLUB-scope role_name values. The source of truth is the
/// generated catalog `lib/core/authorization/generated/role_names.dart`
/// (`kClubRoleNames`); `test/core/authorization/generated_catalog_parity_test.dart`
/// enforces that these constants and groups stay inside it.
///
/// `activeGrant.roleName` returns these strings verbatim — never Spanish
/// or snake_case variants.
abstract class ClubRoleNames {
  static const director = 'director';
  static const deputyDirector = 'deputy-director';
  static const secretary = 'secretary';
  static const treasurer = 'treasurer';
  static const secretaryTreasurer = 'secretary-treasurer';
  static const counselor = 'counselor';
  static const member = 'member';
  static const instructor = 'instructor';

  // Los grupos de roles (gestión, directiva de investidura, personal
  // operativo) ya no viven aquí: el servidor los publica como capacidades
  // (`units.manage`, `investiture.board`, `club.operational_staff`...) y la app
  // pregunta con `hasCapability` (authorization_utils.dart).
}

/// Normalizes a raw role string: trims, lowercases and collapses any run of
/// whitespace and/or underscores into a single `-`. `null` yields `''`.
String normalizeClubRoleName(String? raw) {
  return (raw ?? '').trim().toLowerCase().replaceAll(RegExp(r'[\s_]+'), '-');
}

/// Spanish (and already-canonical) role names, normalized, mapped to the
/// canonical [ClubRoleNames] value. Used to read free-text roles and to
/// resolve role ids against `GET /catalogs/roles`.
const Map<String, String> kClubRoleSpanishAliases = {
  'subdirector': ClubRoleNames.deputyDirector,
  'secretario': ClubRoleNames.secretary,
  'tesorero': ClubRoleNames.treasurer,
  'consejero': ClubRoleNames.counselor,
  'miembro': ClubRoleNames.member,
  'secretario-tesorero': ClubRoleNames.secretaryTreasurer,
  'instructor': ClubRoleNames.instructor,
  'director': ClubRoleNames.director,
};

/// Normalizes [raw] and applies the Spanish alias when there is one.
String canonicalClubRoleName(String? raw) {
  final normalized = normalizeClubRoleName(raw);
  return kClubRoleSpanishAliases[normalized] ?? normalized;
}

/// Names under which [role] may appear in `GET /catalogs/roles`: the
/// normalized input first, then its canonical name and every Spanish alias
/// of that canonical name (the table is read in both directions).
List<String> clubRoleLookupCandidates(String role) {
  final normalized = normalizeClubRoleName(role);
  final canonical = kClubRoleSpanishAliases[normalized] ?? normalized;
  return <String>{
    normalized,
    canonical,
    for (final e in kClubRoleSpanishAliases.entries)
      if (e.value == canonical) e.key,
  }.toList();
}
