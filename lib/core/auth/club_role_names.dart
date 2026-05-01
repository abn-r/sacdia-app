/// Canonical CLUB-scope role_name values from
/// sacdia-backend/prisma/seeds/role-permissions.seed.sql.
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

  /// Roles autorizados a gestionar unidades.
  static const management = <String>[
    director,
    deputyDirector,
    secretary,
    treasurer,
    secretaryTreasurer,
  ];

  /// Roles autorizados a ver el ranking de sección
  /// (management staff + counselors responsables de su unidad).
  static const sectionRankingViewers = <String>[
    director,
    deputyDirector,
    secretary,
    treasurer,
    secretaryTreasurer,
    counselor,
  ];
}
