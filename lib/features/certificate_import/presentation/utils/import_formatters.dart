import 'package:easy_localization/easy_localization.dart';

import '../../domain/entities/certificate_import_batch.dart';
import '../widgets/certificate_proof_summary.dart';

/// "14 nov 2021" in the app language.
String importShortDate(DateTime date) => DateFormat('d MMM yyyy').format(date);

/// "1.2 MB" / "340 KB" for a local file size (units are not translated).
String importFileSize(int bytes) {
  const kb = 1024;
  const mb = 1024 * 1024;
  if (bytes >= mb) return '${NumberFormat('0.0').format(bytes / mb)} MB';
  return '${(bytes / kb).ceil().clamp(1, 1023)} KB';
}

/// The name of a batch for a title: its proof's file name without extension
/// when the phone did not make it up, otherwise "Envío del 21 nov 2026". The
/// API has no batch name.
String importBatchTitle(CertificateImportBatch batch) {
  for (final file in batch.files) {
    final name = CertificateProofSummary.displayName(file.name);
    if (name == null) continue;
    final dot = name.lastIndexOf('.');
    final bare = dot > 0 ? name.substring(0, dot).trim() : name;
    if (bare.isNotEmpty) return bare;
  }
  final date = batch.createdAt ?? batch.submittedAt;
  return date == null
      ? 'certificate_import.status.title'.tr()
      : 'certificate_import.recent.batch_title'
          .tr(namedArgs: {'date': importShortDate(date.toLocal())});
}
