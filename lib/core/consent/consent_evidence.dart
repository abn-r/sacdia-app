import 'dart:io';

import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

/// Tamaño máximo de la ficha firmada (igual que el backend: 10 MB).
const int consentEvidenceMaxBytes = 10 * 1024 * 1024;

/// Recibo de una ficha subida (`201` de `.../consent-evidence`).
class ConsentEvidenceReceipt extends Equatable {
  final String evidenceId;
  final String contentType;
  final int sizeBytes;
  final DateTime? uploadedAt;

  const ConsentEvidenceReceipt({
    required this.evidenceId,
    required this.contentType,
    required this.sizeBytes,
    this.uploadedAt,
  });

  @override
  List<Object?> get props => [evidenceId, contentType, sizeBytes, uploadedAt];
}

/// Ficha vigente con URL firmada (`GET .../consent-evidence`).
///
/// La URL caduca ([expiresIn] segundos) y NUNCA se persiste ni se cachea en
/// disco: se pide cada vez que se va a mostrar.
class ConsentEvidenceAccess extends Equatable {
  final String url;
  final int expiresIn;
  final String contentType;
  final DateTime? uploadedAt;

  /// Solo lo informa el endpoint del director.
  final String? uploadedByDisplayName;

  const ConsentEvidenceAccess({
    required this.url,
    required this.expiresIn,
    required this.contentType,
    this.uploadedAt,
    this.uploadedByDisplayName,
  });

  bool get isPdf => contentType.toLowerCase() == 'application/pdf';
  bool get isImage => contentType.toLowerCase().startsWith('image/');

  @override
  List<Object?> get props =>
      [url, expiresIn, contentType, uploadedAt, uploadedByDisplayName];
}

/// Parseo tolerante de los contratos de consent-evidence (`data` ya sin el
/// envelope `{status, data}`).
abstract final class ConsentEvidenceJson {
  static DateTime? _date(Object? raw) =>
      raw is String && raw.isNotEmpty ? DateTime.tryParse(raw) : null;

  static String? _string(Object? raw) {
    if (raw == null) return null;
    final value = raw.toString();
    return value.isEmpty ? null : value;
  }

  static int _int(Object? raw, int fallback) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw) ?? fallback;
    return fallback;
  }

  static ConsentEvidenceReceipt receipt(Map<String, dynamic> json) {
    return ConsentEvidenceReceipt(
      evidenceId: json['evidence_id'].toString(),
      contentType: _string(json['content_type']) ?? 'application/octet-stream',
      sizeBytes: _int(json['size_bytes'], 0),
      uploadedAt: _date(json['uploaded_at']),
    );
  }

  static ConsentEvidenceAccess access(Map<String, dynamic> json) {
    return ConsentEvidenceAccess(
      url: json['url'].toString(),
      expiresIn: _int(json['expires_in'], 900),
      contentType: _string(json['content_type']) ?? 'application/octet-stream',
      uploadedAt: _date(json['uploaded_at']),
      uploadedByDisplayName: _string(json['uploaded_by_display_name']),
    );
  }
}

/// Por qué una ficha elegida no se puede subir.
enum ConsentFileProblem {
  /// Ni JPEG, ni PNG, ni WebP, ni PDF.
  unsupportedType,

  /// HEIC/HEIF: el backend lo rechaza (la app lo pasa a JPEG al elegirlo).
  heic,

  /// Pesa más de [consentEvidenceMaxBytes].
  tooLarge,

  /// Vacío.
  empty,
}

/// Archivo local elegido (foto, imagen o PDF) listo para subir como ficha.
class ConsentEvidenceLocalFile extends Equatable {
  final String path;
  final String name;
  final String mimeType;
  final int sizeBytes;

  const ConsentEvidenceLocalFile({
    required this.path,
    required this.name,
    required this.mimeType,
    required this.sizeBytes,
  });

  static const _accepted = {
    'image/jpeg',
    'image/png',
    'image/webp',
    'application/pdf',
  };

  /// MIME a partir de la extensión (la fuente fiable de un archivo local; el
  /// backend revalida por magic bytes de todos modos).
  static String mimeFromName(String name) {
    final dot = name.lastIndexOf('.');
    final ext = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'pdf' => 'application/pdf',
      'heic' => 'image/heic',
      'heif' => 'image/heif',
      _ => 'application/octet-stream',
    };
  }

  bool get isPdf => mimeType == 'application/pdf';
  bool get isImage => mimeType.startsWith('image/');

  /// `null` si se puede subir.
  ConsentFileProblem? get problem {
    if (mimeType == 'image/heic' || mimeType == 'image/heif') {
      return ConsentFileProblem.heic;
    }
    if (!_accepted.contains(mimeType)) {
      return ConsentFileProblem.unsupportedType;
    }
    if (sizeBytes <= 0) return ConsentFileProblem.empty;
    if (sizeBytes > consentEvidenceMaxBytes) return ConsentFileProblem.tooLarge;
    return null;
  }

  /// Campo multipart `file` del backend.
  Future<FormData> toFormData() async {
    return FormData.fromMap({
      'file': await MultipartFile.fromFile(
        path,
        filename: name,
        contentType: DioMediaType.parse(mimeType),
      ),
    });
  }

  @override
  List<Object?> get props => [path, name, mimeType, sizeBytes];
}

/// De dónde sale la ficha.
enum ConsentSource { camera, gallery, pdf }

/// Elige la ficha desde la cámara, la galería o un PDF.
///
/// Los selectores son inyectables para probar sin el plugin.
///
/// HEIC -> JPEG: `image_picker` vuelve a codificar la imagen (cámara y galería)
/// como JPEG cuando se piden `maxWidth/maxHeight/imageQuality`, que es lo que se
/// hace aquí. Si aun así llegara un `.heic/.heif`, [ConsentEvidenceLocalFile.problem]
/// lo marca como `heic` y no se sube.
class ConsentEvidencePicker {
  const ConsentEvidencePicker({
    this.pickImage = _defaultPickImage,
    this.pickPdf = _defaultPickPdf,
  });

  final Future<XFile?> Function(ImageSource source) pickImage;
  final Future<({String path, String name, int size})?> Function() pickPdf;

  static Future<XFile?> _defaultPickImage(ImageSource source) {
    return ImagePicker().pickImage(
      source: source,
      maxWidth: 2400,
      maxHeight: 2400,
      imageQuality: 88,
    );
  }

  static Future<({String path, String name, int size})?>
      _defaultPickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      allowMultiple: false,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    final path = file.path;
    if (path == null || path.trim().isEmpty) return null;
    final size = file.size > 0 ? file.size : await File(path).length();
    return (path: path, name: file.name, size: size);
  }

  Future<ConsentEvidenceLocalFile?> pick(ConsentSource source) async {
    switch (source) {
      case ConsentSource.camera:
        return _fromImage(await pickImage(ImageSource.camera));
      case ConsentSource.gallery:
        return _fromImage(await pickImage(ImageSource.gallery));
      case ConsentSource.pdf:
        final picked = await pickPdf();
        if (picked == null) return null;
        return ConsentEvidenceLocalFile(
          path: picked.path,
          name: picked.name,
          mimeType: 'application/pdf',
          sizeBytes: picked.size,
        );
    }
  }

  Future<ConsentEvidenceLocalFile?> _fromImage(XFile? image) async {
    if (image == null) return null;
    final name =
        image.name.isNotEmpty ? image.name : image.path.split('/').last;
    final byName = ConsentEvidenceLocalFile.mimeFromName(
      name.contains('.') ? name : image.path,
    );
    return ConsentEvidenceLocalFile(
      path: image.path,
      name: name,
      mimeType: byName == 'application/octet-stream'
          ? (image.mimeType ?? byName)
          : byName,
      sizeBytes: await image.length(),
    );
  }
}
