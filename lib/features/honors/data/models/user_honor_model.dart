import 'package:equatable/equatable.dart';
import '../../domain/entities/user_honor.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/json_helpers.dart';

const String _tag = 'UserHonorModel';

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
  final int? honorCategoryId;
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
    this.honorCategoryId,
    this.honorSkillLevel,
  });

  /// Crea una instancia desde JSON
  factory UserHonorModel.fromJson(Map<String, dynamic> json) {
    // PK is 'user_honor_id'; 'id' as fallback
    final id = safeInt(json['user_honor_id'] ?? json['id']);

    // Parse images — stored as JSON array of strings
    List<String> images = const [];
    final rawImages = json['images'];
    if (rawImages is List) {
      images = rawImages.map((e) => e.toString()).toList();
    }

    // Date field: 'date' is the honor date, 'created_at' as fallback
    final dateRaw = safeStringOrNull(json['date']) ?? safeStringOrNull(json['created_at']);
    DateTime date;
    if (dateRaw != null) {
      final parsed = DateTime.tryParse(dateRaw);
      if (parsed == null) {
        AppLogger.w('Failed to parse date: $dateRaw, using DateTime.now()', tag: _tag);
      }
      date = parsed ?? DateTime.now();
    } else {
      date = DateTime.now();
    }

    // Parse nullable timestamps
    DateTime? submittedAt;
    final rawSubmittedAt = safeStringOrNull(json['submitted_at']);
    if (rawSubmittedAt != null) {
      submittedAt = DateTime.tryParse(rawSubmittedAt);
    }

    DateTime? validatedAt;
    final rawValidatedAt = safeStringOrNull(json['validated_at']);
    if (rawValidatedAt != null) {
      validatedAt = DateTime.tryParse(rawValidatedAt);
    }

    // Parse nested honor details returned by GET /users/:userId/honors.
    String? honorName;
    String? honorImageUrl;
    String? honorCategoryName;
    int? honorCategoryId;
    int? honorSkillLevel;
    final nestedHonor = json['honors'] as Map<String, dynamic>?;
    if (nestedHonor != null) {
      honorName = safeStringOrNull(nestedHonor['name']);
      honorImageUrl = _buildImageUrl(safeStringOrNull(nestedHonor['honor_image']));
      honorSkillLevel = safeIntOrNull(nestedHonor['skill_level']);
      final nestedCategory =
          nestedHonor['honors_categories'] as Map<String, dynamic>?;
      honorCategoryName = safeStringOrNull(nestedCategory?['name']);
      honorCategoryId = safeIntOrNull(nestedCategory?['honor_category_id']);
    }

    return UserHonorModel(
      id: id,
      honorId: safeInt(json['honor_id']),
      userId: safeString(json['user_id']),
      active: safeBool(json['active'], true),
      validate: safeBool(json['validate']),
      validationStatus:
          safeString(json['validation_status'], 'in_progress'),
      certificate: safeString(json['certificate']),
      images: images,
      document: safeStringOrNull(json['document']),
      date: date,
      submittedAt: submittedAt,
      validatedById: safeStringOrNull(json['validated_by_id']),
      validatedAt: validatedAt,
      rejectionReason: safeStringOrNull(json['rejection_reason']),
      honorName: honorName,
      honorImageUrl: honorImageUrl,
      honorCategoryName: honorCategoryName,
      honorCategoryId: honorCategoryId,
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
      honorCategoryId: honorCategoryId,
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
    int? honorCategoryId,
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
      honorCategoryId: honorCategoryId ?? this.honorCategoryId,
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
        honorCategoryId,
        honorSkillLevel,
      ];
}
