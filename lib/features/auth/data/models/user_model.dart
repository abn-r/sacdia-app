import '../../domain/entities/authorization_snapshot.dart';
import '../../domain/entities/user_entity.dart';

/// Modelo de usuario para la capa de datos
class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.email,
    super.name,
    super.avatar,
    super.metadata,
    super.authorization,
    super.lastSignInAt,
    super.createdAt,
    super.postRegisterComplete,
  });

  /// Crea un UserModel a partir de la respuesta de la API personalizada
  /// Soporta tanto 'user_id' como 'id' en la respuesta
  factory UserModel.fromCustomApi(Map<String, dynamic> data,
      {bool postRegisterComplete = false}) {
    // La API puede devolver el id como 'user_id' o como 'id'
    final userId = (data['user_id'] ?? data['id'])?.toString();
    if (userId == null || userId.isEmpty) {
      throw FormatException(
          'La respuesta de la API no contiene un ID de usuario válido: $data');
    }

    return UserModel(
      id: userId,
      email: (data['email'] as String?) ?? '',
      name: data['name'] as String?,
      avatar: data['avatar'] as String?,
      metadata: data,
      authorization: _parseAuthorization(data['authorization']),
      lastSignInAt: _parseDateTime(data['last_sign_in_at']) ?? DateTime.now(),
      createdAt: _parseDateTime(data['created_at']) ?? DateTime.now(),
      postRegisterComplete: postRegisterComplete,
    );
  }

  /// Convierte a un mapa de JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'avatar': avatar,
      'metadata': metadata,
      'authorization': _authorizationToJson(authorization),
      'lastSignInAt': lastSignInAt?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'postRegisterComplete': postRegisterComplete,
    };
  }

  /// Método estático para parsear fechas de forma segura
  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;

    // Si ya es un DateTime, retornarlo directamente
    if (value is DateTime) return value;

    // Si es String, intentar parsearlo
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return null;
      }
    }

    // Si es otra cosa, convertir a string e intentar parsear
    try {
      return DateTime.parse(value.toString());
    } catch (e) {
      return null;
    }
  }

  static List<String> _parseStringList(dynamic value) {
    if (value is! List) {
      return const [];
    }
    return value
        .map((item) => item?.toString().trim().toLowerCase())
        .whereType<String>()
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }

  static AuthorizationGrant _parseGrant(dynamic value) {
    if (value is! Map<String, dynamic>) {
      return const AuthorizationGrant();
    }

    final instance = value['instance'];
    final club = value['club'];

    return AuthorizationGrant(
      assignmentId: value['assignment_id']?.toString(),
      roleName: value['role_name']?.toString(),
      permissions: _parseStringList(value['permissions']),
      clubId: club is Map<String, dynamic>
          ? int.tryParse(club['club_id']?.toString() ?? '')
          : null,
      instanceType: instance is Map<String, dynamic>
          ? instance['type']?.toString()
          : null,
      instanceId: instance is Map<String, dynamic>
          ? int.tryParse(instance['instance_id']?.toString() ?? '')
          : null,
    );
  }

  static AuthorizationSnapshot? _parseAuthorization(dynamic value) {
    if (value is! Map<String, dynamic>) {
      return null;
    }

    final effective = value['effective'];
    final grants = value['grants'];
    final activeAssignment = value['active_assignment'];

    final effectivePermissions = effective is Map<String, dynamic>
        ? _parseStringList(effective['permissions'])
        : const <String>[];

    final globalGrants = grants is Map<String, dynamic>
        ? ((grants['global_roles'] as List<dynamic>? ?? const [])
            .map(_parseGrant)
            .toList())
        : const <AuthorizationGrant>[];

    final clubAssignments = grants is Map<String, dynamic>
        ? ((grants['club_assignments'] as List<dynamic>? ?? const [])
            .map(_parseGrant)
            .toList())
        : const <AuthorizationGrant>[];

    return AuthorizationSnapshot(
      effectivePermissions: effectivePermissions,
      globalGrants: globalGrants,
      clubAssignments: clubAssignments,
      activeAssignmentId: activeAssignment is Map<String, dynamic>
          ? activeAssignment['assignment_id']?.toString()
          : null,
    );
  }

  static Map<String, dynamic>? _authorizationToJson(
      AuthorizationSnapshot? authorization) {
    if (authorization == null) {
      return null;
    }

    Map<String, dynamic> grantToJson(AuthorizationGrant grant) => {
          'assignment_id': grant.assignmentId,
          'role_name': grant.roleName,
          'permissions': grant.permissions,
          'club': grant.clubId == null ? null : {'club_id': grant.clubId},
          'instance': {
            'type': grant.instanceType,
            'instance_id': grant.instanceId,
          }
        };

    return {
      'effective': {
        'permissions': authorization.effectivePermissions,
      },
      'grants': {
        'global_roles': authorization.globalGrants.map(grantToJson).toList(),
        'club_assignments':
            authorization.clubAssignments.map(grantToJson).toList(),
      },
      'active_assignment': {
        'assignment_id': authorization.activeAssignmentId,
      },
    };
  }

  /// Crea un UserModel desde un mapa JSON
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String?,
      avatar: json['avatar'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      authorization: _parseAuthorization(json['authorization']),
      lastSignInAt: _parseDateTime(json['lastSignInAt']),
      createdAt: _parseDateTime(json['createdAt']),
      postRegisterComplete: json['postRegisterComplete'] as bool? ?? false,
    );
  }

  /// Copia el modelo con nuevos valores
  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? avatar,
    Map<String, dynamic>? metadata,
    AuthorizationSnapshot? authorization,
    DateTime? lastSignInAt,
    DateTime? createdAt,
    bool? postRegisterComplete,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      metadata: metadata ?? this.metadata,
      authorization: authorization ?? this.authorization,
      lastSignInAt: lastSignInAt ?? this.lastSignInAt,
      createdAt: createdAt ?? this.createdAt,
      postRegisterComplete: postRegisterComplete ?? this.postRegisterComplete,
    );
  }
}
