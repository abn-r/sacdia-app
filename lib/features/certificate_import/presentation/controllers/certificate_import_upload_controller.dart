import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../domain/entities/certificate_import_batch.dart';
import '../../domain/entities/certificate_import_payloads.dart';
import '../../domain/entities/certificate_import_upload_session.dart';
import '../../domain/repositories/certificate_import_repository.dart';
import '../error/certificate_import_error_mapper.dart';

/// What the screen is waiting for while the upload is busy.
enum CertificateImportUploadPhase { uploading, reading }

/// Timings of the reading wait. Feature constants, not motion tokens.
abstract final class CertificateImportWait {
  /// How often the batch is polled for its OCR state.
  static const pollInterval = Duration(seconds: 2);

  /// After this long the UI says reading is slow and offers to stop waiting.
  static const slowAfter = Duration(seconds: 8);

  /// Safety cap: after this long the review opens with "still reading".
  static const maxWait = Duration(seconds: 60);

  /// Polls when the backend sends no `ocr_state` (rows present = ready).
  static const legacyPolls = 6;
}

/// Thrown by [CertificateImportUploadController.run] when the user cancels.
class CertificateImportUploadCancelled implements Exception {
  const CertificateImportUploadCancelled();
}

/// Where [CertificateImportUploadController.run] ended.
class CertificateImportUploadOutcome {
  const CertificateImportUploadOutcome(this.batchId, {this.readingIssue});

  final String batchId;

  /// Why the automatic reading could not start (for example OCR unavailable).
  /// The batch is still usable: the member can add rows by hand.
  final CertificateImportErrorInfo? readingIssue;
}

/// Runs upload → confirm → process-ocr → wait for the reading.
///
/// The controller keeps the upload session between attempts, so calling
/// [run] again after a failure resumes at the failed stage: a `PDF_BUSY`
/// retry repeats only `confirm` on the same batch and file.
class CertificateImportUploadController {
  CertificateImportUploadController(
    this._repository, {
    Future<void> Function(Duration) delay = _defaultDelay,
    DateTime Function() now = DateTime.now,
  })  : _delay = delay,
        _now = now;

  final CertificateImportRepository _repository;
  final Future<void> Function(Duration) _delay;
  final DateTime Function() _now;

  static Future<void> _defaultDelay(Duration d) => Future.delayed(d);

  final ValueNotifier<CertificateImportUploadPhase> phase =
      ValueNotifier(CertificateImportUploadPhase.uploading);

  /// Upload progress from 0 to 1 (storage PUT only).
  final ValueNotifier<double> progress = ValueNotifier(0);

  /// True once reading has taken longer than [CertificateImportWait.slowAfter].
  final ValueNotifier<bool> slow = ValueNotifier(false);

  CertificateImportUploadSession _session = CertificateImportUploadSession();
  String? _proofPath;
  String? _uploadedBatchId;
  CancelToken? _cancel;
  CancelToken? _poll;
  bool _skip = false;
  bool _disposed = false;

  /// Cancels the upload in flight. No effect once the reading started.
  void cancel() => _cancel?.cancel();

  /// Stops waiting for the reading and opens the review right away.
  void skipWait() {
    _skip = true;
    _poll?.cancel();
  }

  void dispose() {
    _disposed = true;
    _cancel?.cancel();
    _poll?.cancel();
    phase.dispose();
    progress.dispose();
    slow.dispose();
  }

  Future<CertificateImportUploadOutcome> run(
    CertificateImportLocalProof proof,
  ) async {
    if (_proofPath != proof.localPath) _resetSession();
    _proofPath = proof.localPath;
    _skip = false;
    slow.value = false;
    phase.value = CertificateImportUploadPhase.uploading;

    final batchId = _uploadedBatchId ?? await _upload(proof);
    _uploadedBatchId = batchId;
    if (_disposed) throw const CertificateImportUploadCancelled();
    phase.value = CertificateImportUploadPhase.reading;

    final queued = await _repository.processOcr(batchId);
    if (_disposed) throw const CertificateImportUploadCancelled();
    CertificateImportBatch? batch;
    CertificateImportErrorInfo? issue;
    queued.fold((failure) {
      final info = CertificateImportErrorMapper.map(failure);
      // Connection trouble is retryable from this stage; anything else
      // (OCR unavailable, quota, unknown) leaves a batch to fill by hand.
      if (info.kind == CertificateImportErrorKind.offline ||
          info.kind == CertificateImportErrorKind.timeout) {
        throw failure;
      }
      issue = info;
    }, (value) => batch = value);

    if (batch != null) await _waitForReading(batch!);
    // The next run starts a new batch instead of reusing this one.
    _resetSession();
    return CertificateImportUploadOutcome(batchId, readingIssue: issue);
  }

  void _resetSession() {
    _session = CertificateImportUploadSession();
    _uploadedBatchId = null;
    _proofPath = null;
  }

  Future<String> _upload(CertificateImportLocalProof proof) async {
    final cancel = _cancel = CancelToken();
    progress.value = 0;
    final result = await _repository.uploadLocalProof(
      proof,
      session: _session,
      onProgress: (value) {
        if (!_disposed) progress.value = value;
      },
      cancelToken: cancel,
    );
    return result.fold((failure) {
      if (cancel.isCancelled) {
        _resetSession();
        throw const CertificateImportUploadCancelled();
      }
      throw failure;
    }, (batch) {
      if (!_disposed) progress.value = 1;
      return batch.id;
    });
  }

  /// Polls the batch until the reading is over, the user skips, the cap is
  /// reached or the controller is disposed. A failed poll ends the wait: the
  /// review loads the batch itself and shows its own error with a retry.
  Future<void> _waitForReading(CertificateImportBatch queued) async {
    var latest = queued;
    final started = _now();
    var legacyPolls = 0;
    while (!_disposed && !_skip) {
      if (latest.hasOcrState) {
        final state = latest.ocrState;
        if (state == null || state.isTerminal) return;
      } else if (latest.items.isNotEmpty ||
          legacyPolls >= CertificateImportWait.legacyPolls) {
        return;
      }
      final elapsed = _now().difference(started);
      if (elapsed >= CertificateImportWait.maxWait) return;
      if (elapsed >= CertificateImportWait.slowAfter) slow.value = true;

      await _delay(CertificateImportWait.pollInterval);
      if (_disposed || _skip) return;
      legacyPolls++;
      final poll = _poll = CancelToken();
      final result = await _repository.getBatch(queued.id, cancelToken: poll);
      if (_disposed || _skip) return;
      final next = result.fold<CertificateImportBatch?>((_) => null, (b) => b);
      if (next == null) return;
      latest = next;
    }
  }
}
