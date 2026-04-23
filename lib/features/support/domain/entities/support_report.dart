import 'package:equatable/equatable.dart';

import 'support_category.dart';

/// Payload que la app envía al backend (`POST /support/reports`).
///
/// - `deviceInfo`: siempre presente. Shape capturada desde `device_info_plus`
///   y `package_info_plus`: `{ platform, osVersion, model, appVersion,
///   buildNumber }`.
/// - `userContext`: opcional. La UI puede inyectar contexto útil (ruta
///   actual, club/sección activa, locale) para acelerar el triage.
class SupportReportDraft extends Equatable {
  final SupportCategory category;
  final String title;
  final String description;
  final Map<String, dynamic> deviceInfo;
  final Map<String, dynamic>? userContext;

  const SupportReportDraft({
    required this.category,
    required this.title,
    required this.description,
    required this.deviceInfo,
    this.userContext,
  });

  Map<String, dynamic> toJson() => {
        'category': category.wireValue,
        'title': title,
        'description': description,
        'deviceInfo': deviceInfo,
        if (userContext != null) 'userContext': userContext,
      };

  @override
  List<Object?> get props =>
      [category, title, description, deviceInfo, userContext];
}

/// Respuesta del backend tras crear el reporte.
class SupportReportResult extends Equatable {
  final String reportId;
  final DateTime createdAt;

  const SupportReportResult({required this.reportId, required this.createdAt});

  factory SupportReportResult.fromJson(Map<String, dynamic> json) {
    return SupportReportResult(
      reportId: (json['reportId'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now().toUtc(),
    );
  }

  @override
  List<Object?> get props => [reportId, createdAt];
}
