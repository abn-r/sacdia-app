import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/domain/utils/authorization_utils.dart';

/// Permiso del servidor para registrar un menor en una sección
/// (`POST /club-sections/:id/dependents`).
const Set<String> createMinorPermissions = {'dependents:create'};

/// El usuario ve "Registrar un menor": tiene `dependents:create` Y el servidor
/// informó `family_features.director_create_minor` en `/auth/me`. Sin la bandera
/// (apagada o ausente) el servidor respondería 404, así que no se ofrece.
bool canRegisterMinor(UserEntity? user) =>
    user != null &&
    user.familyFeatures?.directorCreateMinor == true &&
    hasAnyPermission(user, createMinorPermissions);
