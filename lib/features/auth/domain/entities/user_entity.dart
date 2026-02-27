import 'package:equatable/equatable.dart';

/// Entidad de usuario para la capa de dominio
class UserEntity extends Equatable {
  final String id;
  final String email;
  final String? name;
  final String? avatar;
  final Map<String, dynamic>? metadata;
  final DateTime? lastSignInAt;
  final DateTime? createdAt;
  final bool postRegisterComplete;

  const UserEntity({
    required this.id,
    required this.email,
    this.name,
    this.avatar,
    this.metadata,
    this.lastSignInAt,
    this.createdAt,
    this.postRegisterComplete = false,
  });

  @override
  List<Object?> get props => [
        id,
        email,
        name,
        avatar,
        metadata,
        lastSignInAt,
        createdAt,
        postRegisterComplete,
      ];
}
