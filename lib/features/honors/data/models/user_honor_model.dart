import 'package:equatable/equatable.dart';
import '../../domain/entities/user_honor.dart';

const String _honorImagesBase =
    'https://sacdia-files.s3.us-east-1.amazonaws.com/Especialidades/';

String? _buildImageUrl(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  if (raw.startsWith('http')) return raw;
  return '$_honorImagesBase$raw';
}

/// Modelo de especialidad de usuario para la capa de datos
class UserHonorModel extends Equatable {
  final int id;
  final int honorId;
  final String userId;
  final bool active;
  final bool validate;
  final String certificate;
  final List<String> images;
  final String? document;
  final DateTime date;

  // Embedded honor details from the nested `honors` object in the API response
  final String? honorName;
  final String? honorImageUrl;
  final String? honorCategoryName;

  const UserHonorModel({
    required this.id,
    required this.honorId,
    required this.userId,
    this.active = true,
    this.validate = false,
    this.certificate = '',
    this.images = const [],
    this.document,
    required this.date,
    this.honorName,
    this.honorImageUrl,
    this.honorCategoryName,
  });

  /// Crea una instancia desde JSON
  factory UserHonorModel.fromJson(Map<String, dynamic> json) {
    // PK is 'user_honor_id'; 'id' as fallback
    final id = (json['user_honor_id'] ?? json['id']) as int;

    // Parse images — stored as JSON array of strings
    List<String> images = const [];
    final rawImages = json['images'];
    if (rawImages is List) {
      images = rawImages.map((e) => e.toString()).toList();
    }

    // Date field: 'date' is the honor date, 'created_at' as fallback
    final dateRaw = json['date'] as String? ?? json['created_at'] as String?;
    final date = dateRaw != null
        ? DateTime.tryParse(dateRaw) ?? DateTime.now()
        : DateTime.now();

    // Parse nested honor details returned by GET /users/:userId/honors.
    // The backend includes: { honor_id, name, honor_image, skill_level,
    //   honors_categories: { name, icon } }
    String? honorName;
    String? honorImageUrl;
    String? honorCategoryName;
    final nestedHonor = json['honors'] as Map<String, dynamic>?;
    if (nestedHonor != null) {
      honorName = nestedHonor['name'] as String?;
      honorImageUrl = _buildImageUrl(nestedHonor['honor_image'] as String?);
      final nestedCategory =
          nestedHonor['honors_categories'] as Map<String, dynamic>?;
      honorCategoryName = nestedCategory?['name'] as String?;
    }

    return UserHonorModel(
      id: id,
      honorId: json['honor_id'] as int,
      userId: json['user_id'] as String,
      active: (json['active'] as bool?) ?? true,
      validate: (json['validate'] as bool?) ?? false,
      certificate: (json['certificate'] as String?) ?? '',
      images: images,
      document: json['document'] as String?,
      date: date,
      honorName: honorName,
      honorImageUrl: honorImageUrl,
      honorCategoryName: honorCategoryName,
    );
  }

  /// Convierte la instancia a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'honor_id': honorId,
      'user_id': userId,
      'active': active,
      'validate': validate,
      'certificate': certificate,
      'images': images,
      'document': document,
      'date': date.toIso8601String(),
    };
  }

  /// Convierte el modelo a entidad de dominio
  UserHonor toEntity() {
    return UserHonor(
      id: id,
      honorId: honorId,
      userId: userId,
      active: active,
      validate: validate,
      certificate: certificate,
      images: images,
      document: document,
      date: date,
      honorName: honorName,
      honorImageUrl: honorImageUrl,
      honorCategoryName: honorCategoryName,
    );
  }

  /// Crea una copia con campos actualizados
  UserHonorModel copyWith({
    int? id,
    int? honorId,
    String? userId,
    bool? active,
    bool? validate,
    String? certificate,
    List<String>? images,
    String? document,
    DateTime? date,
    String? honorName,
    String? honorImageUrl,
    String? honorCategoryName,
  }) {
    return UserHonorModel(
      id: id ?? this.id,
      honorId: honorId ?? this.honorId,
      userId: userId ?? this.userId,
      active: active ?? this.active,
      validate: validate ?? this.validate,
      certificate: certificate ?? this.certificate,
      images: images ?? this.images,
      document: document ?? this.document,
      date: date ?? this.date,
      honorName: honorName ?? this.honorName,
      honorImageUrl: honorImageUrl ?? this.honorImageUrl,
      honorCategoryName: honorCategoryName ?? this.honorCategoryName,
    );
  }

  @override
  List<Object?> get props => [
        id,
        honorId,
        userId,
        active,
        validate,
        certificate,
        images,
        document,
        date,
        honorName,
        honorImageUrl,
        honorCategoryName,
      ];
}
