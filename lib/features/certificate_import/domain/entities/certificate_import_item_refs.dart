import 'package:equatable/equatable.dart';

/// Catalog honor the row points to. Names are already translated by the API.
class CertificateImportHonorRef extends Equatable {
  const CertificateImportHonorRef({
    required this.id,
    required this.name,
    this.categoryId,
    this.categoryName,
  });

  final int id;
  final String name;
  final int? categoryId;
  final String? categoryName;

  @override
  List<Object?> get props => [id, name, categoryId, categoryName];
}

/// Catalog class the row points to, with its club type.
class CertificateImportClassRef extends Equatable {
  const CertificateImportClassRef({
    required this.id,
    required this.name,
    this.assetCode,
    this.clubTypeId,
    this.clubTypeName,
  });

  final int id;
  final String name;
  final String? assetCode;
  final int? clubTypeId;
  final String? clubTypeName;

  @override
  List<Object?> get props => [id, name, assetCode, clubTypeId, clubTypeName];
}

/// Instructor declared on a honor row: a member of the Local Field or a free
/// name. Read-only here; editing it belongs to the instructor slice.
class CertificateImportInstructorRef extends Equatable {
  const CertificateImportInstructorRef({
    required this.isUser,
    required this.displayName,
    this.userId,
    this.photoUrl,
  });

  final bool isUser;
  final String displayName;
  final String? userId;
  final String? photoUrl;

  @override
  List<Object?> get props => [isUser, displayName, userId, photoUrl];
}
