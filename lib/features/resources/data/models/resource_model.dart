import 'package:equatable/equatable.dart';
import '../../domain/entities/resource.dart';

/// Modelo de recurso para la capa de datos
class ResourceModel extends Equatable {
  final String resourceId;
  final String title;
  final String? description;
  final String resourceType;
  final int? resourceCategoryId;
  final String? categoryName;
  final int? clubTypeId;
  final String? clubTypeName;
  final String scopeLevel;
  final int? scopeId;
  final String? fileName;
  final int? fileSize;
  final String? fileMimeType;
  final String? content;
  final String? externalUrl;
  final String? signedUrl;
  final DateTime createdAt;

  const ResourceModel({
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

  /// Crea una instancia desde JSON
  factory ResourceModel.fromJson(Map<String, dynamic> json) {
    return ResourceModel(
      resourceId: json['resource_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      resourceType: json['resource_type'] as String? ?? 'document',
      resourceCategoryId: json['resource_category_id'] as int?,
      categoryName: json['category_name'] as String?,
      clubTypeId: json['club_type_id'] as int?,
      clubTypeName: json['club_type_name'] as String?,
      scopeLevel: json['scope_level'] as String? ?? 'system',
      scopeId: json['scope_id'] as int?,
      fileName: json['file_name'] as String?,
      fileSize: json['file_size'] as int?,
      fileMimeType: json['file_mime_type'] as String?,
      content: json['content'] as String?,
      externalUrl: json['external_url'] as String?,
      signedUrl: json['signed_url'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  /// Convierte la instancia a JSON
  Map<String, dynamic> toJson() {
    return {
      'resource_id': resourceId,
      'title': title,
      'description': description,
      'resource_type': resourceType,
      'resource_category_id': resourceCategoryId,
      'category_name': categoryName,
      'club_type_id': clubTypeId,
      'club_type_name': clubTypeName,
      'scope_level': scopeLevel,
      'scope_id': scopeId,
      'file_name': fileName,
      'file_size': fileSize,
      'file_mime_type': fileMimeType,
      'content': content,
      'external_url': externalUrl,
      'signed_url': signedUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Convierte el modelo a entidad de dominio
  Resource toEntity() {
    return Resource(
      resourceId: resourceId,
      title: title,
      description: description,
      resourceType: resourceType,
      resourceCategoryId: resourceCategoryId,
      categoryName: categoryName,
      clubTypeId: clubTypeId,
      clubTypeName: clubTypeName,
      scopeLevel: scopeLevel,
      scopeId: scopeId,
      fileName: fileName,
      fileSize: fileSize,
      fileMimeType: fileMimeType,
      content: content,
      externalUrl: externalUrl,
      signedUrl: signedUrl,
      createdAt: createdAt,
    );
  }

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
