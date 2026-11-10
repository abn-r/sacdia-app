import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';

import '../../../../core/consent/consent_evidence.dart';
import '../../../../core/utils/file_display_name.dart';
import '../../domain/entities/service_credential_review.dart';

/// Único título de la constancia: el curso de consejería son las 10 horas.
String serviceCredentialTitle() => 'service_credentials.title'.tr();

String serviceCredentialDate(BuildContext context, DateTime date) =>
    DateFormat.yMMMd(context.locale.toString()).format(date.toLocal());

/// Kind of a stored file from its extension: «PDF», «Foto» or null when the
/// name says nothing (the picker's own names have no reliable kind either).
String? serviceCredentialFileKind(String? fileName) {
  final name = fileName?.trim().toLowerCase() ?? '';
  if (name.endsWith('.pdf')) return 'service_credentials.file_kind.pdf'.tr();
  const photo = ['.jpg', '.jpeg', '.png', '.heic', '.webp'];
  if (photo.any(name.endsWith)) {
    return 'service_credentials.file_kind.photo'.tr();
  }
  return null;
}

/// What identifies the stored file to a person: its name when it has a human
/// one, otherwise its kind. Never the raw `image_picker_<uuid>` name.
String? serviceCredentialFileLabel(String? fileName) {
  final name = fileName == null ? null : meaningfulFileName(fileName);
  return name ?? serviceCredentialFileKind(fileName);
}

/// Rótulo (plural) de la pestaña de la cola y del grupo de una lista.
String reviewFilterLabel(ReviewStatusFilter filter) => switch (filter) {
      ReviewStatusFilter.pending => 'service_credentials.group.pending'.tr(),
      ReviewStatusFilter.approved => 'service_credentials.group.approved'.tr(),
      ReviewStatusFilter.rejected => 'service_credentials.group.rejected'.tr(),
    };

/// Por qué un archivo elegido no se puede subir como constancia (PDF, JPG o PNG
/// de hasta 10 MB). WebP y HEIC se rechazan aunque la ficha de consentimiento
/// sí los acepte.
enum ServiceCredentialFileProblem { unsupportedType, tooLarge, empty }

ServiceCredentialFileProblem? serviceCredentialFileProblem(
  ConsentEvidenceLocalFile file,
) {
  const accepted = {'application/pdf', 'image/jpeg', 'image/png'};
  if (!accepted.contains(file.mimeType)) {
    return ServiceCredentialFileProblem.unsupportedType;
  }
  if (file.sizeBytes <= 0) return ServiceCredentialFileProblem.empty;
  if (file.sizeBytes > consentEvidenceMaxBytes) {
    return ServiceCredentialFileProblem.tooLarge;
  }
  return null;
}

String serviceCredentialFileProblemText(ServiceCredentialFileProblem problem) =>
    switch (problem) {
      ServiceCredentialFileProblem.unsupportedType =>
        'service_credentials.upload.problems.unsupported_type'.tr(),
      ServiceCredentialFileProblem.tooLarge =>
        'service_credentials.upload.problems.too_large'.tr(),
      ServiceCredentialFileProblem.empty =>
        'service_credentials.upload.problems.empty'.tr(),
    };
