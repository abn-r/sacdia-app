/// Persona — the role-derived UI identity of the authenticated user.
///
/// Derived from [AuthorizationSnapshot] by [resolvePersona]. Controls which
/// nav slots are shown in [_MainShell] and which landing route is used
/// after a successful login.
enum Persona {
  miembro,
  consejero,
  director,
  tesorero,
  coordinador,
}
