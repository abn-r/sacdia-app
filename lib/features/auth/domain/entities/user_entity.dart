import 'package:equatable/equatable.dart';

import 'authorization_snapshot.dart';

/// Entidad de usuario para la capa de dominio
class UserEntity extends Equatable {
  final String id;
  final String email;
  final String? name;
  final String? avatar;
  final DateTime? birthday;
  final Map<String, dynamic>? metadata;
  final AuthorizationSnapshot? authorization;
  final DateTime? lastSignInAt;
  final DateTime? createdAt;
  final bool postRegisterComplete;

  /// El servidor exige aceptar una versión vigente de Términos o Privacidad.
  ///
  /// Se deriva de `/auth/me` en cada carga y nunca se cachea. Debe formar parte
  /// de `props`: si no, al limpiarse el flag el estado sería igual al anterior
  /// y el router no se refrescaría.
  final bool legalAcceptancePending;

  const UserEntity({
    required this.id,
    required this.email,
    this.name,
    this.avatar,
    this.birthday,
    this.metadata,
    this.authorization,
    this.lastSignInAt,
    this.createdAt,
    this.postRegisterComplete = false,
    this.legalAcceptancePending = false,
  });

  @override
  List<Object?> get props => [
        id,
        email,
        name,
        avatar,
        birthday,
        metadata,
        authorization,
        lastSignInAt,
        createdAt,
        postRegisterComplete,
        legalAcceptancePending,
      ];
}
