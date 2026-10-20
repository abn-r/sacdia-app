import 'package:easy_localization/easy_localization.dart';

import '../../domain/entities/acting_for_info.dart';
import '../../domain/entities/authorization_snapshot.dart';
import '../../domain/entities/principal_info.dart';
import '../../domain/entities/user_entity.dart';

/// Modelo de usuario para la capa de datos
class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    super.email,
    super.name,
    super.avatar,
    super.birthday,
    super.metadata,
    super.authorization,
    super.lastSignInAt,
    super.createdAt,
    super.postRegisterComplete,
    super.legalAcceptancePending,
    super.actingFor,
    super.family,
    super.principal,
    super.familyFeatures,
    super.analyticsAnonymous,
    super.serverMode,
  });

  /// Crea un UserModel a partir de la respuesta de la API personalizada
  /// Soporta tanto 'user_id' como 'id' en la respuesta
  factory UserModel.fromCustomApi(Map<String, dynamic> data,
      {bool postRegisterComplete = false}) {
    // La API puede devolver el id como 'user_id' o como 'id'
    final userId = (data['user_id'] ?? data['id'])?.toString();
    if (userId == null || userId.isEmpty) {
      throw FormatException(
          tr('errors.invalid_user_response', namedArgs: {'data': '$data'}));
    }

    return UserModel(
      id: userId,
      email: _parseEmail(data['email']),
      name: data['name'] as String?,
      avatar: data['avatar'] as String? ??
          data['user_image'] as String? ??
          data['picture_url'] as String?,
      birthday: _parseDateTime(data['birthday']),
      metadata: data,
      authorization: _parseAuthorization(data['authorization']),
      lastSignInAt: _parseDateTime(data['last_sign_in_at']) ?? DateTime.now(),
      createdAt: _parseDateTime(data['created_at']) ?? DateTime.now(),
      postRegisterComplete: postRegisterComplete,
      legalAcceptancePending: _parseLegalPending(data['legal']),
      actingFor: _parseActingFor(data['acting_for']),
      family: _parseFamily(data['family']),
      principal: parsePrincipal(data['principal'], club: data['club']),
      familyFeatures: _parseFamilyFeatures(data['family_features']),
      analyticsAnonymous: _parseAnalyticsAnonymous(data),
      serverMode: _parseMode(data),
    );
  }

  /// Convierte a un mapa de JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'avatar': avatar,
      'birthday': birthday?.toIso8601String(),
      'metadata': metadata,
      'authorization': _authorizationToJson(authorization),
      'lastSignInAt': lastSignInAt?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'postRegisterComplete': postRegisterComplete,
    };
  }

  /// El correo es nulo en perfiles de dependientes; una cadena vacía o
  /// solo con espacios también cuenta como ausente.
  static String? _parseEmail(dynamic value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// `data.acting_for`: nulo (o malformado) significa que no se actúa por nadie.
  static ActingForInfo? _parseActingFor(dynamic value) {
    if (value is! Map) return null;
    final actor = value['actor_user_id']?.toString();
    final dependent = value['dependent_user_id']?.toString();
    if (actor == null ||
        actor.isEmpty ||
        dependent == null ||
        dependent.isEmpty) {
      return null;
    }
    final rawScopes = value['scopes'];
    return ActingForInfo(
      actorUserId: actor,
      dependentUserId: dependent,
      guardianshipId: value['guardianship_id']?.toString(),
      consentStatus: value['consent_status']?.toString(),
      scopes: rawScopes is List
          ? rawScopes.map((s) => s.toString()).toList(growable: false)
          : const [],
    );
  }

  /// `data.family`: `{is_guardian, dependents_count}`; ausente o malformado es
  /// nulo.
  static FamilySummary? _parseFamily(dynamic value) {
    if (value is! Map) return null;
    final count = value['dependents_count'];
    return FamilySummary(
      isGuardian: value['is_guardian'] == true,
      dependentsCount: count is num ? count.toInt() : 0,
    );
  }

  /// `data.principal` (`/auth/me`) o `data.user.principal` (`/auth/login`).
  ///
  /// En `/auth/me` `supervision` es un objeto; en el login es solo el estado
  /// (`"pending_guardian"` | `"active"` | `null`). Se aceptan las dos formas.
  /// Ausente o malformado es nulo: el modo cae a adulto y la analítica queda
  /// anónima.
  static PrincipalInfo? parsePrincipal(dynamic value, {dynamic club}) {
    if (value is! Map) return null;
    final rawScopes = value['scopes'];
    final kind = PrincipalKind.parse(value['kind']);
    return PrincipalInfo(
      kind: kind,
      scopes: rawScopes is List
          ? rawScopes.map((s) => s.toString()).toList(growable: false)
          : null,
      supervision: _parseSupervision(value['supervision']),
      device: _parseDevice(
        value['device'],
        // Solo un teléfono vinculado trae el club fuera de `authorization`.
        club: kind == PrincipalKind.linkedDevice ? club : null,
      ),
    );
  }

  /// `principal.device`: `{linked_device_id, label, paired_at}`. Ausente o
  /// malformado es nulo.
  static DeviceInfo? _parseDevice(dynamic value, {dynamic club}) {
    final clubMap = club is Map ? club : null;
    if (value is! Map && clubMap == null) return null;
    final device = value is Map ? value : const {};
    return DeviceInfo(
      linkedDeviceId: device['linked_device_id']?.toString(),
      label: device['label']?.toString(),
      pairedAt: _parseDateTime(device['paired_at']),
      clubId: clubMap == null
          ? null
          : int.tryParse(clubMap['club_id']?.toString() ?? ''),
      clubName: clubMap?['club_name']?.toString(),
      clubType: clubMap?['club_type']?.toString(),
    );
  }

  static SupervisionInfo? _parseSupervision(dynamic value) {
    if (value is String) {
      final status = SupervisionStatus.parse(value);
      return status == null ? null : SupervisionInfo(status: status);
    }
    if (value is! Map) return null;
    final status = SupervisionStatus.parse(value['status']);
    if (status == null) return null;
    final guardians = value['guardians'];
    final daysLeft = value['days_left'];
    return SupervisionInfo(
      status: status,
      pendingSince: _parseDateTime(value['pending_since']),
      guardians: guardians is List
          ? guardians
              .whereType<Map>()
              .map(
                (g) => SupervisionGuardian(
                  displayName: g['display_name']?.toString() ?? '—',
                  relationshipTypeName: g['relationship_type_name']?.toString(),
                  guardianshipId: g['guardianship_id']?.toString(),
                  consentStatus: g['consent_status']?.toString(),
                ),
              )
              .toList(growable: false)
          : const [],
      // Solo `false` explícito lo oculta: el aviso de transparencia es el lado
      // honesto por defecto.
      summaryVisibleToGuardians: value['summary_visible_to_guardians'] != false,
      serverDaysLeft: daysLeft is num ? daysLeft.toInt() : null,
    );
  }

  /// `data.family_features`: ausente o malformado es nulo (todo apagado).
  static FamilyFeatures? _parseFamilyFeatures(dynamic value) {
    if (value is! Map) return null;
    return FamilyFeatures(
      teenLogin: value['teen_login'] == true,
      linkedDevice: value['linked_device'] == true,
      directorCreateMinor: value['director_create_minor'] == true,
    );
  }

  /// `analytics_anonymous` en `data` o dentro de `data.principal`. Solo un
  /// booleano real cuenta; todo lo demás es nulo (= anónimo, FP3-30).
  static bool? _parseAnalyticsAnonymous(Map<String, dynamic> data) {
    final top = data['analytics_anonymous'];
    if (top is bool) return top;
    final principal = data['principal'];
    if (principal is Map && principal['analytics_anonymous'] is bool) {
      return principal['analytics_anonymous'] as bool;
    }
    return null;
  }

  /// `mode` (`adult` | `teen_pending` | `teen_supervised`) en `data` o en
  /// `data.principal`. Un valor desconocido es nulo y el modo se deriva del
  /// principal.
  static AccountMode? _parseMode(Map<String, dynamic> data) {
    final top = AccountMode.parse(data['mode']);
    if (top != null) return top;
    final principal = data['principal'];
    return principal is Map ? AccountMode.parse(principal['mode']) : null;
  }

  /// `data.legal.requires_acceptance == true`. Un bloque ausente o malformado
  /// cuenta como no pendiente.
  static bool _parseLegalPending(dynamic value) =>
      value is Map && value['requires_acceptance'] == true;

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
    final section = value['section'];
    final club = value['club'];

    // Support both new 'section' key and legacy 'instance' key
    final sectionData = section is Map<String, dynamic>
        ? section
        : (instance is Map<String, dynamic> ? instance : null);

    // club_type_name may sit at the top level of the grant object or nested
    // inside the section object, depending on the backend serializer version.
    final rawClubTypeName = value['club_type_name'] ??
        (sectionData is Map<String, dynamic>
            ? sectionData['club_type_name']
            : null);
    final rawClubTypeId = value['club_type_id'] ??
        (sectionData is Map<String, dynamic>
            ? sectionData['club_type_id']
            : null);
    final rawClubName = club is Map<String, dynamic>
        ? club['club_name']?.toString().trim()
        : null;

    return AuthorizationGrant(
      assignmentId: value['assignment_id']?.toString(),
      roleName: value['role_name']?.toString(),
      permissions: _parseStringList(value['permissions']),
      clubId: club is Map<String, dynamic>
          ? int.tryParse(club['club_id']?.toString() ?? '')
          : null,
      clubName:
          (rawClubName != null && rawClubName.isNotEmpty) ? rawClubName : null,
      sectionId: sectionData != null
          ? int.tryParse(
              (sectionData['club_section_id'] ?? sectionData['instance_id'])
                      ?.toString() ??
                  '')
          : null,
      clubTypeId: int.tryParse(rawClubTypeId?.toString() ?? ''),
      clubTypeName: rawClubTypeName?.toString(),
      status: value['status']?.toString(),
      expiresAt: _parseDateTime(value['expires_at']),
      rejectionReason: value['rejection_reason']?.toString(),
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
          'club': grant.clubId == null && grant.clubName == null
              ? null
              : {
                  'club_id': grant.clubId,
                  'club_name': grant.clubName,
                },
          'section': {
            'club_section_id': grant.sectionId,
            'club_type_id': grant.clubTypeId,
          },
          'club_type_id': grant.clubTypeId,
          'club_type_name': grant.clubTypeName,
          'status': grant.status,
          'expires_at': grant.expiresAt?.toIso8601String(),
          'rejection_reason': grant.rejectionReason,
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
      email: json['email'] as String?,
      name: json['name'] as String?,
      avatar: json['avatar'] as String?,
      birthday: _parseDateTime(json['birthday']),
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
    DateTime? birthday,
    Map<String, dynamic>? metadata,
    AuthorizationSnapshot? authorization,
    DateTime? lastSignInAt,
    DateTime? createdAt,
    bool? postRegisterComplete,
    bool? legalAcceptancePending,
    ActingForInfo? actingFor,
    FamilySummary? family,
    PrincipalInfo? principal,
    FamilyFeatures? familyFeatures,
    bool? analyticsAnonymous,
    AccountMode? serverMode,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      birthday: birthday ?? this.birthday,
      metadata: metadata ?? this.metadata,
      authorization: authorization ?? this.authorization,
      lastSignInAt: lastSignInAt ?? this.lastSignInAt,
      createdAt: createdAt ?? this.createdAt,
      postRegisterComplete: postRegisterComplete ?? this.postRegisterComplete,
      legalAcceptancePending:
          legalAcceptancePending ?? this.legalAcceptancePending,
      actingFor: actingFor ?? this.actingFor,
      family: family ?? this.family,
      principal: principal ?? this.principal,
      familyFeatures: familyFeatures ?? this.familyFeatures,
      analyticsAnonymous: analyticsAnonymous ?? this.analyticsAnonymous,
      serverMode: serverMode ?? this.serverMode,
    );
  }
}
