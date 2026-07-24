import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/widgets/evidence_staging/staged_file.dart';
import 'package:sacdia_app/core/widgets/evidence_staging/upload_progress_sheet.dart';

void main() {
  testWidgets('animates real upload progress for the batch and active file', (
    tester,
  ) async {
    final progressController = StreamController<List<StagedFile>>.broadcast();
    addTearDown(progressController.close);

    final uploadingFile = StagedFile(
      id: 'uploading-file',
      name: 'Evidencia 01.png',
      type: 'image',
      status: StagedFileStatus.uploading,
      uploadProgress: 0.25,
    );
    final pendingFile = const StagedFile(
      id: 'pending-file',
      name: 'Evidencia 02.png',
      type: 'image',
      status: StagedFileStatus.local,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showUploadProgressSheet(
                  context: context,
                  initialFiles: [uploadingFile, pendingFile],
                  uploadStream: progressController.stream,
                ),
                child: const Text('Mostrar progreso'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mostrar progreso'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byKey(const ValueKey('upload-overall-progress-bar')),
          )
          .value,
      closeTo(0.125, 0.001),
    );
    expect(
      tester
          .widget<CircularProgressIndicator>(
            find.byKey(const ValueKey('upload-file-progress-uploading-file')),
          )
          .value,
      closeTo(0.25, 0.001),
    );
    expect(find.text('25%'), findsOneWidget);

    progressController.add([
      uploadingFile.copyWith(uploadProgress: 0.75),
      pendingFile,
    ]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byKey(const ValueKey('upload-overall-progress-bar')),
          )
          .value,
      closeTo(0.375, 0.001),
    );
    expect(
      tester
          .widget<CircularProgressIndicator>(
            find.byKey(const ValueKey('upload-file-progress-uploading-file')),
          )
          .value,
      closeTo(0.75, 0.001),
    );
    expect(find.text('75%'), findsOneWidget);
  });
}
