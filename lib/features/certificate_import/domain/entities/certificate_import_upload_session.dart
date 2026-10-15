import 'certificate_import_payloads.dart';

/// Progress of one proof upload, kept between attempts so a retry resumes
/// instead of starting over.
///
/// A retry after `PDF_BUSY` (429) repeats only `confirm` against the same
/// [batchId] and file, without creating another draft batch.
class CertificateImportUploadSession {
  /// Draft batch created for this proof, once it exists.
  String? batchId;

  /// Presign ticket (and its `fileId`) for the file being uploaded.
  CertificateImportPresignTicket? ticket;

  /// True once the bytes reached storage; only `confirm` is left.
  bool uploaded = false;

  String? get fileId => ticket?.fileId;

  void reset() {
    batchId = null;
    ticket = null;
    uploaded = false;
  }
}
