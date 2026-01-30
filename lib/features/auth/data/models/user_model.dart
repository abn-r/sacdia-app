
import '../../domain/entities/user_entity.dart';

/// Modelo de usuario para la capa de datos
class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.email,
    super.name,
    super.avatar,
    super.metadata,
    super.lastSignInAt,
    super.createdAt,
    super.postRegisterComplete,
  });

  /// Crea un UserModel a partir de la respuesta de la API personalizada
  factory UserModel.fromCustomApi(Map<String, dynamic> data, {bool postRegisterComplete = false}) {
    return UserModel(
      id: data['user_id'] as String,
      email: data['email'] as String? ?? '',
      name: data['name'] as String?,
      // Los siguientes campos pueden ser null o configurarse según la respuesta real de la API
      avatar: null,
      metadata: data,
      lastSignInAt: DateTime.now(), // Usamos la fecha actual para el inicio de sesión
      createdAt: DateTime.now(),   // Usamos la fecha actual para la creación
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
  
  /// Crea un UserModel desde un mapa JSON
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String?,
      avatar: json['avatar'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
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
      lastSignInAt: lastSignInAt ?? this.lastSignInAt,
      createdAt: createdAt ?? this.createdAt,
      postRegisterComplete: postRegisterComplete ?? this.postRegisterComplete,
    );
  }
}
