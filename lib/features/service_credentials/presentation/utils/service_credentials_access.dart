import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/domain/utils/authorization_utils.dart';
import '../../../auth/presentation/providers/acting_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/domain/entities/principal_info.dart';

/// Capacidad con la que el servidor dice que el actor revisa constancias de
/// servicio (el servidor filtra la cola por su alcance: Campo Local,
/// coordinadores y pastores).
const String kReviewServiceCredentialsCapability = 'service_credentials.review';

/// «Mis constancias»: solo en la cuenta de un adulto, en su propio perfil.
/// Quedan fuera quien actúa por un menor, el adolescente supervisado, el
/// teléfono vinculado y las cuentas restringidas (el router también las
/// descarta) y el pastor o coordinador sin club, que no abren esa ruta.
///
/// Se ofrece a todo adulto con club: la constancia se sube ANTES de recibir un
/// cargo de servicio, así que no se exige ya tener una asignación.
bool canManageOwnServiceCredentials(
  UserEntity? user, {
  required bool isActing,
}) =>
    user != null &&
    !isActing &&
    user.actingFor == null &&
    user.mode == AccountMode.adult &&
    !isPastorWithoutClub(user) &&
    !isCoordinatorWithoutClub(user);

/// «Constancias por revisar»: capacidad + cuenta de adulto en su propio perfil.
bool canReviewServiceCredentials(
  UserEntity? user, {
  required bool isActing,
}) =>
    user != null &&
    !isActing &&
    user.actingFor == null &&
    user.mode == AccountMode.adult &&
    hasCapability(user, kReviewServiceCredentialsCapability);

/// Derivados de la sesión para las entradas y las vistas.
final canManageOwnServiceCredentialsProvider = Provider.autoDispose<bool>(
  (ref) => canManageOwnServiceCredentials(
    ref.watch(authNotifierProvider.select((v) => v.value)),
    isActing: ref.watch(actingDependentProvider) != null,
  ),
);

final canReviewServiceCredentialsProvider = Provider.autoDispose<bool>(
  (ref) => canReviewServiceCredentials(
    ref.watch(authNotifierProvider.select((v) => v.value)),
    isActing: ref.watch(actingDependentProvider) != null,
  ),
);
