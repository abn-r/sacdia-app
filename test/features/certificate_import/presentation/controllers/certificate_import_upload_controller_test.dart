import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/certificate_import/domain/entities/certificate_import_batch.dart';
import 'package:sacdia_app/features/certificate_import/domain/entities/certificate_import_ocr_state.dart';
import 'package:sacdia_app/features/certificate_import/domain/entities/certificate_import_item.dart';
import 'package:sacdia_app/features/certificate_import/domain/entities/certificate_import_payloads.dart';
import 'package:sacdia_app/features/certificate_import/domain/entities/certificate_import_upload_session.dart';
import 'package:sacdia_app/features/certificate_import/domain/repositories/certificate_import_repository.dart';
import 'package:sacdia_app/features/certificate_import/presentation/controllers/certificate_import_upload_controller.dart';
import 'package:sacdia_app/features/certificate_import/presentation/error/certificate_import_error_mapper.dart';

const _proof = CertificateImportLocalProof(
  localPath: '/tmp/a.pdf',
  fileName: 'a.pdf',
  mimeType: 'application/pdf',
  fileSize: 4,
);

CertificateImportBatch _batch({
  CertificateImportOcrState? state,
  bool reported = true,
  int items = 0,
}) =>
    CertificateImportBatch(
      id: 'batch-1',
      status: 'DRAFT',
      ocrState: state,
      hasOcrState: reported,
      items: [
        for (var i = 0; i < items; i++)
          CertificateImportItem(
            id: 'i$i',
            type: CertificateImportItemType.honor,
            status: CertificateImportItemStatus.needsReview,
          ),
      ],
    );

/// Only the calls the controller makes; anything else is a test bug.
class _FakeRepo implements CertificateImportRepository {
  final sessions = <CertificateImportUploadSession?>[];
  final uploadResults = <Either<Failure, CertificateImportBatch>>[];
  Either<Failure, CertificateImportBatch> ocrResult =
      Right(_batch(state: CertificateImportOcrState.running));
  final pollResults = <Either<Failure, CertificateImportBatch>>[];
  final pollTokens = <Object?>[];
  var ocrCalls = 0;
  Future<void> Function(CancelToken token)? onUpload;

  /// False simulates a failure before the draft batch exists.
  var createsBatch = true;
  final deleted = <String>[];
  Either<Failure, void> deleteResult = const Right(null);
  void Function()? onDelete;

  @override
  Future<Either<Failure, void>> deleteBatch(String batchId) async {
    deleted.add(batchId);
    onDelete?.call();
    return deleteResult;
  }

  @override
  Future<Either<Failure, CertificateImportBatch>> uploadLocalProof(
    CertificateImportLocalProof proof, {
    CertificateImportUploadSession? session,
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    sessions.add(session);
    if (createsBatch) session!.batchId = 'batch-1';
    onProgress?.call(0.5);
    await onUpload?.call(cancelToken!);
    return uploadResults.isEmpty
        ? Right(_batch(reported: false))
        : uploadResults.removeAt(0);
  }

  @override
  Future<Either<Failure, CertificateImportBatch>> processOcr(
      String batchId) async {
    ocrCalls++;
    return ocrResult;
  }

  @override
  Future<Either<Failure, CertificateImportBatch>> getBatch(
    String batchId, {
    Object? cancelToken,
  }) async {
    pollTokens.add(cancelToken);
    return pollResults.isEmpty
        ? Right(_batch(state: CertificateImportOcrState.running))
        : pollResults.removeAt(0);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _Harness {
  _Harness() {
    controller = CertificateImportUploadController(
      repo,
      delay: (d) async {
        delays.add(d);
        clock = clock.add(d);
        await onDelay?.call();
      },
      now: () => clock,
    );
  }

  final repo = _FakeRepo();
  final delays = <Duration>[];
  var clock = DateTime(2026, 1, 1);
  Future<void> Function()? onDelay;
  late final CertificateImportUploadController controller;
}

void main() {
  test('PDF_BUSY on confirm: the retry reuses the same session', () async {
    final h = _Harness();
    h.repo.uploadResults.add(const Left(ServerFailure(
      message: 'x',
      code: 429,
      errorCode: 'CERTIFICATE_IMPORT_PDF_BUSY',
    )));
    h.repo.ocrResult = Right(_batch(state: CertificateImportOcrState.done));

    await expectLater(
      h.controller.run(_proof),
      throwsA(isA<ServerFailure>().having(
        (f) => CertificateImportErrorMapper.map(f).kind,
        'kind',
        CertificateImportErrorKind.pdfBusy,
      )),
    );
    final outcome = await h.controller.run(_proof);

    expect(outcome.batchId, 'batch-1');
    expect(h.repo.sessions, hasLength(2));
    expect(h.repo.sessions[1], same(h.repo.sessions[0]));
    expect(h.repo.sessions[1]!.batchId, 'batch-1');
  });

  test('a finished run starts a fresh session next time', () async {
    final h = _Harness();
    h.repo.ocrResult = Right(_batch(state: CertificateImportOcrState.done));

    await h.controller.run(_proof);
    await h.controller.run(_proof);

    expect(h.repo.sessions[1], isNot(same(h.repo.sessions[0])));
  });

  test('picking another file drops the previous session', () async {
    final h = _Harness();
    h.repo.uploadResults.add(const Left(ServerFailure(message: 'x')));
    h.repo.ocrResult = Right(_batch(state: CertificateImportOcrState.done));

    await expectLater(h.controller.run(_proof), throwsA(isA<ServerFailure>()));
    await h.controller.run(const CertificateImportLocalProof(
      localPath: '/tmp/b.pdf',
      fileName: 'b.pdf',
      mimeType: 'application/pdf',
      fileSize: 4,
    ));

    expect(h.repo.sessions[1], isNot(same(h.repo.sessions[0])));
  });

  test('cancel aborts the upload and the next run starts clean', () async {
    final h = _Harness();
    final started = Completer<void>();
    h.repo.onUpload = (token) async {
      started.complete();
      await token.whenCancel;
    };
    h.repo.uploadResults.add(const Left(ServerFailure(message: 'cancelled')));

    final run = h.controller.run(_proof);
    final expectation = expectLater(
      run,
      throwsA(isA<CertificateImportUploadCancelled>()),
    );
    await started.future;
    h.controller.cancel();
    await expectation;

    h.repo.onUpload = null;
    h.repo.ocrResult = Right(_batch(state: CertificateImportOcrState.done));
    await h.controller.run(_proof);
    expect(h.repo.sessions[1], isNot(same(h.repo.sessions[0])));
  });

  test('reports upload progress and switches to reading', () async {
    final h = _Harness();
    h.repo.ocrResult = Right(_batch(state: CertificateImportOcrState.done));
    final phases = <CertificateImportUploadPhase>[];
    h.controller.phase.addListener(() => phases.add(h.controller.phase.value));

    await h.controller.run(_proof);

    expect(h.controller.progress.value, 1);
    expect(phases, contains(CertificateImportUploadPhase.reading));
  });

  group('waiting for the reading', () {
    test('polls every 2 s until ocr_state is terminal', () async {
      final h = _Harness();
      h.repo.pollResults.addAll([
        Right(_batch(state: CertificateImportOcrState.running)),
        Right(_batch(state: CertificateImportOcrState.done, items: 2)),
      ]);

      final outcome = await h.controller.run(_proof);

      expect(outcome.batchId, 'batch-1');
      expect(outcome.readingIssue, isNull);
      expect(h.delays, everyElement(const Duration(seconds: 2)));
      expect(h.repo.pollTokens, hasLength(2));
      // The cancel token reaches getBatch so leaving the screen can abort it.
      expect(h.repo.pollTokens, everyElement(isA<CancelToken>()));
    });

    for (final state in [
      CertificateImportOcrState.empty,
      CertificateImportOcrState.failed,
    ]) {
      test('${state.name} ends the wait', () async {
        final h = _Harness();
        h.repo.pollResults.add(Right(_batch(state: state)));

        await h.controller.run(_proof);

        expect(h.repo.pollTokens, hasLength(1));
      });
    }

    test('explicit null ocr_state (OCR never requested) does not wait',
        () async {
      final h = _Harness();
      h.repo.ocrResult = Right(_batch());

      await h.controller.run(_proof);

      expect(h.repo.pollTokens, isEmpty);
    });

    test('says reading is slow after 8 s and stops at the 60 s cap', () async {
      final h = _Harness();
      final slowAt = <int>[];
      h.controller.slow.addListener(() {
        if (h.controller.slow.value) slowAt.add(h.delays.length * 2);
      });

      await h.controller.run(_proof);

      expect(slowAt, [8]);
      expect(h.repo.pollTokens, hasLength(30));
      expect(h.delays.fold<Duration>(Duration.zero, (a, b) => a + b),
          CertificateImportWait.maxWait);
    });

    test('skipWait stops waiting and keeps the batch', () async {
      final h = _Harness();
      h.onDelay = () async {
        if (h.delays.length == 2) h.controller.skipWait();
      };

      final outcome = await h.controller.run(_proof);

      expect(outcome.batchId, 'batch-1');
      expect(h.repo.pollTokens, hasLength(1));
    });

    test('dispose stops polling without touching the notifiers', () async {
      final h = _Harness();
      h.onDelay = () async {
        if (h.delays.length == 2) h.controller.dispose();
      };

      await expectLater(h.controller.run(_proof), completes);
      expect(h.repo.pollTokens, hasLength(1));
    });

    test('a failed poll ends the wait and lets the review load the batch',
        () async {
      final h = _Harness();
      h.repo.pollResults.add(const Left(ServerFailure(message: 'x')));

      final outcome = await h.controller.run(_proof);

      expect(outcome.batchId, 'batch-1');
      expect(h.repo.pollTokens, hasLength(1));
    });
  });

  group('without ocr_state in the response (older backend)', () {
    test('rows already present means ready: no polling', () async {
      final h = _Harness();
      h.repo.ocrResult = Right(_batch(reported: false, items: 3));

      await h.controller.run(_proof);

      expect(h.repo.pollTokens, isEmpty);
    });

    test('polls until rows show up', () async {
      final h = _Harness();
      h.repo.ocrResult = Right(_batch(reported: false));
      h.repo.pollResults.addAll([
        Right(_batch(reported: false)),
        Right(_batch(reported: false, items: 1)),
      ]);

      await h.controller.run(_proof);

      expect(h.repo.pollTokens, hasLength(2));
    });

    test('gives up after 6 polls', () async {
      final h = _Harness();
      h.repo.ocrResult = Right(_batch(reported: false));
      for (var i = 0; i < 10; i++) {
        h.repo.pollResults.add(Right(_batch(reported: false)));
      }

      await h.controller.run(_proof);

      expect(h.repo.pollTokens, hasLength(CertificateImportWait.legacyPolls));
    });
  });

  group('process-ocr failures are not swallowed', () {
    test('OCR_UNAVAILABLE becomes a reading issue and skips the wait',
        () async {
      final h = _Harness();
      h.repo.ocrResult = const Left(ServerFailure(
        message: 'x',
        code: 400,
        errorCode: 'CERTIFICATE_IMPORT_OCR_UNAVAILABLE',
      ));

      final outcome = await h.controller.run(_proof);

      expect(outcome.batchId, 'batch-1');
      expect(outcome.readingIssue?.kind,
          CertificateImportErrorKind.ocrUnavailable);
      expect(h.repo.pollTokens, isEmpty);
    });

    test('a connection failure is retryable from process-ocr, not the upload',
        () async {
      final h = _Harness();
      h.repo.ocrResult = const Left(ServerFailure(
        message: 'x',
        errorCode: 'NETWORK',
      ));

      await expectLater(
          h.controller.run(_proof), throwsA(isA<ServerFailure>()));
      h.repo.ocrResult = Right(_batch(state: CertificateImportOcrState.done));
      final outcome = await h.controller.run(_proof);

      expect(outcome.readingIssue, isNull);
      expect(h.repo.sessions, hasLength(1), reason: 'upload not repeated');
      expect(h.repo.ocrCalls, 2);
    });
  });

  group('abandoned drafts are deleted (best effort)', () {
    const unreadable = Left<Failure, CertificateImportBatch>(ServerFailure(
      message: 'x',
      code: 400,
      errorCode: 'CERTIFICATE_IMPORT_PDF_ENCRYPTED',
    ));

    Future<void> cancelUpload(_Harness h) async {
      final started = Completer<void>();
      h.repo.onUpload = (token) async {
        started.complete();
        await token.whenCancel;
      };
      h.repo.uploadResults.add(const Left(ServerFailure(message: 'x')));
      final run = h.controller.run(_proof);
      final expectation = expectLater(
        run,
        throwsA(isA<CertificateImportUploadCancelled>()),
      );
      await started.future;
      h.controller.cancel();
      await expectation;
    }

    test('cancel deletes the batch of the session', () async {
      final h = _Harness();
      await cancelUpload(h);
      expect(h.repo.deleted, ['batch-1']);
    });

    test('cancel without a batch yet calls nothing', () async {
      final h = _Harness();
      h.repo.createsBatch = false;
      await cancelUpload(h);
      expect(h.repo.deleted, isEmpty);
    });

    test('a 404 on delete is fine and cancel still ends as cancelled',
        () async {
      final h = _Harness();
      // The repository maps 404 to success; the controller just moves on.
      h.repo.deleteResult = const Right(null);
      await cancelUpload(h);
      h.repo.onUpload = null;
      h.repo.ocrResult = Right(_batch(state: CertificateImportOcrState.done));
      final outcome = await h.controller.run(_proof);
      expect(outcome.batchId, 'batch-1');
    });

    test('a 409 on delete is ignored without a crash', () async {
      final h = _Harness();
      h.repo.deleteResult = const Left(ServerFailure(
        message: 'x',
        code: 409,
        errorCode: 'CERTIFICATE_IMPORT_OCR_IN_PROGRESS',
      ));
      await cancelUpload(h);
      expect(h.repo.deleted, ['batch-1']);

      // Nothing is shown to the member and the controller keeps working.
      h.repo.onUpload = null;
      h.repo.ocrResult = Right(_batch(state: CertificateImportOcrState.done));
      expect((await h.controller.run(_proof)).batchId, 'batch-1');
    });

    test('a delete that throws is swallowed', () async {
      final h = _Harness();
      h.repo.onDelete = () => throw StateError('boom');
      await cancelUpload(h);
      expect(h.repo.deleted, ['batch-1']);
    });

    test('a file that cannot be read drops its draft, a busy queue does not',
        () async {
      final h = _Harness();
      h.repo.uploadResults.add(unreadable);
      await expectLater(
          h.controller.run(_proof), throwsA(isA<ServerFailure>()));
      expect(h.repo.deleted, ['batch-1']);

      final busy = _Harness();
      busy.repo.uploadResults.add(const Left(ServerFailure(
        message: 'x',
        code: 429,
        errorCode: 'CERTIFICATE_IMPORT_PDF_BUSY',
      )));
      await expectLater(
          busy.controller.run(_proof), throwsA(isA<ServerFailure>()));
      expect(busy.repo.deleted, isEmpty);
    });

    test('after an unreadable file the next run starts a new session',
        () async {
      final h = _Harness();
      h.repo.uploadResults.add(unreadable);
      await expectLater(
          h.controller.run(_proof), throwsA(isA<ServerFailure>()));
      h.repo.ocrResult = Right(_batch(state: CertificateImportOcrState.done));
      await h.controller.run(_proof);
      expect(h.repo.sessions[1], isNot(same(h.repo.sessions[0])));
    });

    test('picking another file deletes the previous attempt', () async {
      final h = _Harness();
      h.repo.uploadResults.add(const Left(ServerFailure(message: 'x')));
      await expectLater(
          h.controller.run(_proof), throwsA(isA<ServerFailure>()));
      expect(h.repo.deleted, isEmpty);

      h.repo.ocrResult = Right(_batch(state: CertificateImportOcrState.done));
      await h.controller.run(const CertificateImportLocalProof(
        localPath: '/tmp/b.pdf',
        fileName: 'b.pdf',
        mimeType: 'application/pdf',
        fileSize: 4,
      ));
      expect(h.repo.deleted, ['batch-1']);
    });

    test('retrying the same file keeps the draft', () async {
      final h = _Harness();
      h.repo.uploadResults.add(const Left(ServerFailure(message: 'x')));
      await expectLater(
          h.controller.run(_proof), throwsA(isA<ServerFailure>()));
      h.repo.ocrResult = Right(_batch(state: CertificateImportOcrState.done));
      await h.controller.run(_proof);
      expect(h.repo.deleted, isEmpty);
    });

    test('leaving after a failed upload deletes the draft', () async {
      final h = _Harness();
      h.repo.uploadResults.add(const Left(ServerFailure(message: 'x')));
      await expectLater(
          h.controller.run(_proof), throwsA(isA<ServerFailure>()));
      h.controller.dispose();
      expect(h.repo.deleted, ['batch-1']);
    });

    test('leaving after a finished run deletes nothing', () async {
      final h = _Harness();
      h.repo.ocrResult = Right(_batch(state: CertificateImportOcrState.done));
      await h.controller.run(_proof);
      h.controller.dispose();
      expect(h.repo.deleted, isEmpty);
    });

    test('leaving with the file already confirmed keeps the batch', () async {
      final h = _Harness();
      h.repo.ocrResult = const Left(
        ServerFailure(message: 'x', errorCode: 'NETWORK'),
      );
      await expectLater(
          h.controller.run(_proof), throwsA(isA<ServerFailure>()));
      h.controller.dispose();
      expect(h.repo.deleted, isEmpty);
    });

    test('leaving mid-upload deletes the draft once', () async {
      final h = _Harness();
      final started = Completer<void>();
      h.repo.onUpload = (token) async {
        started.complete();
        await token.whenCancel;
      };
      h.repo.uploadResults.add(const Left(ServerFailure(message: 'x')));
      final run = h.controller.run(_proof);
      final expectation = expectLater(
        run,
        throwsA(isA<CertificateImportUploadCancelled>()),
      );
      await started.future;
      h.controller.dispose();
      await expectation;
      expect(h.repo.deleted, ['batch-1']);
    });
  });
}
