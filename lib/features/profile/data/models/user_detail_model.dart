import '../../domain/entities/user_detail.dart';

/// Modelo de detalle completo del usuario
class UserDetailModel extends UserDetail {
  const UserDetailModel({
    required super.id,
    required super.email,
    required super.name,
    super.paternalSurname,
    super.maternalSurname,
    super.avatar,
    super.phone,
    super.birthDate,
    super.gender,
    super.address,
    super.baptized,
    super.baptismDate,
    super.clubName,
    super.clubType,
    super.currentClass,
    super.roles,
    super.createdAt,
    super.lastSignInAt,
  });

  /// Crea un UserDetailModel a partir de datos de la API
  factory UserDetailModel.fromJson(Map<String, dynamic> json) {
    // Roles: API sends flat List<String>, legacy format was List<{name: String}>
    final rolesList = json['roles'] as List<dynamic>?;
    final roles = rolesList
            ?.map((r) => r is String ? r : (r['name'] as String? ?? ''))
            .where((r) => r.isNotEmpty)
            .toList() ??
        [];

    // Club: API sends { club_name, club_type, club_id }
    final club = json['club'] as Map<String, dynamic>?;

    // Birthdate: API sends 'birthday', legacy was 'birth_date'
    final birthdayRaw =
        json['birthday'] as String? ?? json['birth_date'] as String?;

    return UserDetailModel(
      id: json['user_id'] as String? ?? json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      // API sends 'paternal_last_name' / 'maternal_last_name'
      paternalSurname: json['paternal_last_name'] as String? ??
          json['p_lastname'] as String?,
      maternalSurname: json['maternal_last_name'] as String? ??
          json['m_lastname'] as String?,
      // API sends 'user_image', legacy was 'avatar'
      avatar: json['user_image'] as String? ?? json['avatar'] as String?,
      phone: json['phone'] as String?,
      birthDate: birthdayRaw != null ? DateTime.tryParse(birthdayRaw) : null,
      gender: json['gender'] as String?,
      address: json['address'] as String?,
      baptized: json['baptism'] as bool? ?? false,
      baptismDate: json['baptism_date'] != null
          ? DateTime.tryParse(json['baptism_date'].toString())
          : null,
      // Club fields: API sends club_name / club_type (not name / type)
      clubName: club?['club_name'] as String? ?? club?['name'] as String?,
      clubType: club?['club_type'] as String? ?? club?['type'] as String?,
      currentClass: json['current_class']?['name'] as String?,
      roles: roles,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      lastSignInAt: json['last_sign_in_at'] != null
          ? DateTime.tryParse(json['last_sign_in_at'].toString())
          : null,
    );
  }

  /// Convierte el modelo a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'p_lastname': paternalSurname,
      'm_lastname': maternalSurname,
      'avatar': avatar,
      'phone': phone,
      'birth_date': birthDate?.toIso8601String(),
      'gender': gender,
      'address': address,
      'baptism': baptized,
      'baptism_date': baptismDate?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'last_sign_in_at': lastSignInAt?.toIso8601String(),
    };
  }

  /// Crea una copia del modelo con valores actualizados
  UserDetailModel copyWith({
    String? id,
    String? email,
    String? name,
    String? paternalSurname,
    String? maternalSurname,
    String? avatar,
    String? phone,
    DateTime? birthDate,
    String? gender,
    String? address,
    bool? baptized,
    DateTime? baptismDate,
    String? clubName,
    String? clubType,
    String? currentClass,
    List<String>? roles,
    DateTime? createdAt,
    DateTime? lastSignInAt,
  }) {
    return UserDetailModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      paternalSurname: paternalSurname ?? this.paternalSurname,
      maternalSurname: maternalSurname ?? this.maternalSurname,
      avatar: avatar ?? this.avatar,
      phone: phone ?? this.phone,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      address: address ?? this.address,
      baptized: baptized ?? this.baptized,
      baptismDate: baptismDate ?? this.baptismDate,
      clubName: clubName ?? this.clubName,
      clubType: clubType ?? this.clubType,
      currentClass: currentClass ?? this.currentClass,
      roles: roles ?? this.roles,
      createdAt: createdAt ?? this.createdAt,
      lastSignInAt: lastSignInAt ?? this.lastSignInAt,
    );
  }
}
