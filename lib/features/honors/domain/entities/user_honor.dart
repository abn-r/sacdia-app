import 'package:equatable/equatable.dart';

/// Entidad de especialidad de usuario del dominio
class UserHonor extends Equatable {
  final int id;
  final int honorId;
  final String userId;
  final bool active;
  final bool validate;
  final String certificate;
  final List<String> images;
  final String? document;
  final DateTime date;

  // Embedded honor details returned by GET /users/:userId/honors
  // These are populated from the nested `honors` object in the API response.
  final String? honorName;
  final String? honorImageUrl;
  final String? honorCategoryName;

  // Computed convenience: derived from 'validate' for UI display
  String get status => validate ? 'completed' : 'in_progress';

  const UserHonor({
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
