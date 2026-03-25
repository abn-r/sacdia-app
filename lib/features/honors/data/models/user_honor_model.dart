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
  final String validationStatus;
  final String certificate;
  final List<String> images;
  final String? document;
  final DateTime date;

  // Validation audit fields
  final DateTime? submittedAt;
  final String? validatedById;
  final DateTime? validatedAt;
  final String? rejectionReason;

  // Embedded honor details
  final String? honorName;
  final String? honorImageUrl;
  final String? honorCategoryName;
  final int? honorSkillLevel;

  const UserHonorModel({
    required this.id,
    required this.honorId,
    required this.userId,
    this.active = true,
    this.validate = false,
    this.validationStatus = 'in_progress',
    this.certificate = '',
    this.images = const [],
    this.document,
    required this.date,
    this.submittedAt,
    this.validatedById,
    this.validatedAt,
    this.rejectionReason,
    this.honorName,
    this.honorImageUrl,
    this.honorCategoryName,
    this.honorSkillLevel,
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

    // Parse nullable timestamps
    DateTime? submittedAt;
    final rawSubmittedAt = json['submitted_at'] as String?;
    if (rawSubmittedAt != null) {
      submittedAt = DateTime.tryParse(rawSubmittedAt);
    }

    DateTime? validatedAt;
    final rawValidatedAt = json['validated_at'] as String?;
    if (rawValidatedAt != null) {
      validatedAt = DateTime.tryParse(rawValidatedAt);
    }

    // Parse nested honor details returned by GET /users/:userId/honors.
    String? honorName;
    String? honorImageUrl;
    String? honorCategoryName;
    int? honorSkillLevel;
    final nestedHonor = json['honors'] as Map<String, dynamic>?;
    if (nestedHonor != null) {
      honorName = nestedHonor['name'] as String?;
      honorImageUrl = _buildImageUrl(nestedHonor['honor_image'] as String?);
      honorSkillLevel = nestedHonor['skill_level'] as int?;
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
      validationStatus:
          (json['validation_status'] as String?) ?? 'in_progress',
      certificate: (json['certificate'] as String?) ?? '',
      images: images,
      document: json['document'] as String?,
      date: date,
      submittedAt: submittedAt,
      validatedById: json['validated_by_id'] as String?,
      validatedAt: validatedAt,
      rejectionReason: json['rejection_reason'] as String?,
      honorName: honorName,
      honorImageUrl: honorImageUrl,
      honorCategoryName: honorCategoryName,
      honorSkillLevel: honorSkillLevel,
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
      'validation_status': validationStatus,
      'certificate': certificate,
      'images': images,
      'document': document,
      'date': date.toIso8601String(),
      'submitted_at': submittedAt?.toIso8601String(),
      'validated_by_id': validatedById,
      'validated_at': validatedAt?.toIso8601String(),
      'rejection_reason': rejectionReason,
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
      validationStatus: validationStatus,
      certificate: certificate,
      images: images,
      document: document,
      date: date,
      submittedAt: submittedAt,
      validatedById: validatedById,
      validatedAt: validatedAt,
      rejectionReason: rejectionReason,
      honorName: honorName,
      honorImageUrl: honorImageUrl,
      honorCategoryName: honorCategoryName,
      honorSkillLevel: honorSkillLevel,
    );
  }

  /// Crea una copia con campos actualizados
  UserHonorModel copyWith({
    int? id,
    int? honorId,
    String? userId,
    bool? active,
    bool? validate,
    String? validationStatus,
    String? certificate,
    List<String>? images,
    String? document,
    DateTime? date,
    DateTime? submittedAt,
    String? validatedById,
    DateTime? validatedAt,
    String? rejectionReason,
    String? honorName,
    String? honorImageUrl,
    String? honorCategoryName,
    int? honorSkillLevel,
  }) {
    return UserHonorModel(
      id: id ?? this.id,
      honorId: honorId ?? this.honorId,
      userId: userId ?? this.userId,
      active: active ?? this.active,
      validate: validate ?? this.validate,
      validationStatus: validationStatus ?? this.validationStatus,
      certificate: certificate ?? this.certificate,
      images: images ?? this.images,
      document: document ?? this.document,
      date: date ?? this.date,
      submittedAt: submittedAt ?? this.submittedAt,
      validatedById: validatedById ?? this.validatedById,
      validatedAt: validatedAt ?? this.validatedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      honorName: honorName ?? this.honorName,
      honorImageUrl: honorImageUrl ?? this.honorImageUrl,
      honorCategoryName: honorCategoryName ?? this.honorCategoryName,
      honorSkillLevel: honorSkillLevel ?? this.honorSkillLevel,
    );
  }

  @override
  List<Object?> get props => [
        id,
        honorId,
        userId,
        active,
        validate,
        validationStatus,
        certificate,
        images,
        document,
        date,
        submittedAt,
        validatedById,
        validatedAt,
        rejectionReason,
        honorName,
        honorImageUrl,
        honorCategoryName,
        honorSkillLevel,
      ];
}
