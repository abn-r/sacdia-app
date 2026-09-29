import 'package:equatable/equatable.dart';

import '../../../../core/utils/json_helpers.dart';
import '../../domain/entities/certificate_import_payloads.dart';

class CertificateImportPresignTicketModel extends Equatable {
  final String fileId;
  final String uploadUrl;
  final int expiresIn;
  final Map<String, String> requiredHeaders;

  const CertificateImportPresignTicketModel({
    required this.fileId,
    required this.uploadUrl,
    required this.expiresIn,
    this.requiredHeaders = const {},
  });

  factory CertificateImportPresignTicketModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawHeaders = json['required_headers'];
    return CertificateImportPresignTicketModel(
      fileId: safeString(json['file_id']),
      uploadUrl: safeString(json['upload_url']),
      expiresIn: safeIntOrNull(json['expires_in']) ?? 0,
      requiredHeaders: rawHeaders is Map
          ? rawHeaders.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            )
          : const {},
    );
  }

  CertificateImportPresignTicket toEntity() => CertificateImportPresignTicket(
        fileId: fileId,
        uploadUrl: uploadUrl,
        expiresIn: expiresIn,
        requiredHeaders: requiredHeaders,
      );

  @override
  List<Object?> get props => [fileId, uploadUrl, expiresIn, requiredHeaders];
}
