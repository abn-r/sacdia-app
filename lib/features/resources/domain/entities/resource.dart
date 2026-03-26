import 'package:equatable/equatable.dart';

/// Entidad de recurso del dominio
class Resource extends Equatable {
  final String resourceId;
  final String title;
  final String? description;
  final String resourceType; // document, audio, image, video_link, text
  final int? resourceCategoryId;
  final String? categoryName;
  final int? clubTypeId;
  final String? clubTypeName;
  final String scopeLevel; // system, union, local_field
  final int? scopeId;
  final String? fileName;
  final int? fileSize;
  final String? fileMimeType;
  final String? content;
  final String? externalUrl;
  final String? signedUrl;
  final DateTime createdAt;

  const Resource({
    required this.resourceId,
    required this.title,
    this.description,
    required this.resourceType,
    this.resourceCategoryId,
    this.categoryName,
    this.clubTypeId,
    this.clubTypeName,
    required this.scopeLevel,
    this.scopeId,
    this.fileName,
    this.fileSize,
    this.fileMimeType,
    this.content,
    this.externalUrl,
    this.signedUrl,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        resourceId,
        title,
        description,
        resourceType,
        resourceCategoryId,
        categoryName,
        clubTypeId,
        clubTypeName,
        scopeLevel,
        scopeId,
        fileName,
        fileSize,
        fileMimeType,
        content,
        externalUrl,
        signedUrl,
        createdAt,
      ];
}
