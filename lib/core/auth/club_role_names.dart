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

  // Los grupos de roles (gestión, directiva de investidura, personal
  // operativo) ya no viven aquí: el servidor los publica como capacidades
  // (`units.manage`, `investiture.board`, `club.operational_staff`...) y la app
  // pregunta con `hasCapability` (authorization_utils.dart).
}
