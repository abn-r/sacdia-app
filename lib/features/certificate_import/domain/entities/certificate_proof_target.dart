import 'certificate_import_file.dart';
import 'certificate_import_item.dart';

/// File and page the proof viewer should open (D4, D12, R6).
class CertificateProofTarget {
  const CertificateProofTarget({required this.file, this.page = 1});

  final CertificateImportFile file;

  /// 1-based and always valid for [file] when its page count is known.
  final int page;

  /// Resolves the target for [item], or for the batch when [item] is null.
  ///
  /// - The item's `source_file_id` wins when the batch contains that file.
  /// - `source_page` only applies to a known file, or to a single-file batch
  ///   (the file is then unambiguous).
  /// - Anything missing or inconsistent opens the first file on page 1.
  static CertificateProofTarget? resolve(
    List<CertificateImportFile> files, {
    CertificateImportItem? item,
  }) {
    if (files.isEmpty) return null;
    final sourceId = item?.sourceFileId;
    final match = sourceId == null
        ? null
        : files.where((file) => file.id == sourceId).firstOrNull;
    final file = match ?? files.first;
    final applies = match != null || (sourceId == null && files.length == 1);
    final page = applies ? item?.sourcePage : null;
    final count = file.pageCount;
    final valid = page != null && page >= 1 && (count == null || page <= count);
    return CertificateProofTarget(file: file, page: valid ? page : 1);
  }
}
