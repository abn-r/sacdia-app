import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/core/widgets/evidence_staging/evidence_staging_manager.dart';
import 'package:sacdia_app/core/widgets/evidence_staging/staged_file.dart';
import 'package:sacdia_app/core/widgets/evidence_staging/upload_progress_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

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
    // The shown progress catches up with the reported one, then stops.
    await tester.pumpAndSettle();

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
    await tester.pumpAndSettle();

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

  testWidgets('shows why a file failed under its name', (tester) async {
    final progressController = StreamController<List<StagedFile>>.broadcast();
    addTearDown(progressController.close);

    const failedFile = StagedFile(
      id: 'failed-file',
      name: 'evidencia-qa.pdf',
      type: 'pdf',
      status: StagedFileStatus.error,
      errorMessage: 'Esta clase ya está cerrada.',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showUploadProgressSheet(
                  context: context,
                  initialFiles: const [failedFile],
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

    expect(find.text('evidencia-qa.pdf'), findsOneWidget);
    expect(find.text('Esta clase ya está cerrada.'), findsOneWidget);
  });

  group('stagedUploadErrorMessage', () {
    test('uses the AppException message as is', () {
      expect(
        stagedUploadErrorMessage(ServerException(message: 'Sin permiso')),
        'Sin permiso',
      );
    });

    test('drops the technical "Exception: " prefix', () {
      expect(stagedUploadErrorMessage(Exception('Falló')), 'Falló');
    });
  });

  Future<StreamController<List<StagedFile>>> openSheet(
    WidgetTester tester,
    List<StagedFile> files,
  ) async {
    final controller = StreamController<List<StagedFile>>.broadcast();
    addTearDown(controller.close);
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('es')],
        path: 'assets/translations',
        fallbackLocale: const Locale('es'),
        startLocale: const Locale('es'),
        assetLoader: const _FileAssetLoader(),
        child: Builder(
          builder: (context) => MaterialApp(
            locale: context.locale,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () => showUploadProgressSheet(
                      context: context,
                      initialFiles: files,
                      uploadStream: controller.stream,
                    ),
                    child: const Text('Mostrar progreso'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mostrar progreso'));
    await tester.pumpAndSettle();
    return controller;
  }

  List<StagedFile> files(StagedFileStatus status, int count) => [
        for (var i = 0; i < count; i++)
          StagedFile(
            id: 'file-$i',
            name: 'Evidencia 0$i.jpg',
            type: 'image',
            status: status,
          ),
      ];

  testWidgets('while uploading, the deck stays stacked with no toggle',
      (tester) async {
    await openSheet(tester, [
      ...files(StagedFileStatus.completed, 1),
      StagedFile(
        id: 'up',
        name: 'Evidencia 09.jpg',
        type: 'image',
        status: StagedFileStatus.uploading,
        uploadProgress: 0.4,
      ),
      ...files(StagedFileStatus.local, 3)
          .map((f) => f.copyWith(id: 'w-${f.id}')),
    ]);

    expect(find.byKey(const ValueKey('upload-toggle-view')), findsNothing);
    // The file on top is the one uploading.
    expect(find.text('Evidencia 09.jpg'), findsOneWidget);
  });

  testWidgets('when done, «Ver todos» opens the deck into a grid and back',
      (tester) async {
    await openSheet(tester, files(StagedFileStatus.completed, 5));

    final deck = find.byKey(const ValueKey('upload-file-deck'));
    final toggle = find.byKey(const ValueKey('upload-toggle-view'));
    expect(toggle, findsOneWidget);
    final stackedHeight = tester.getSize(deck).height;

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    final gridHeight = tester.getSize(deck).height;
    expect(gridHeight, greaterThan(stackedHeight));
    // Every card sits in its own grid cell: no two share a position.
    final tops = {
      for (var i = 0; i < 5; i++)
        tester.getTopLeft(find.byKey(ValueKey('upload-card-file-$i'))),
    };
    expect(tops.length, 5);

    // The grid pushes the toggle down; bring it into view first.
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.getSize(deck).height, stackedHeight);
  });

  testWidgets('a file that uploads at once still fills from 0 to 100%',
      (tester) async {
    final controller = await openSheet(tester, [
      StagedFile(
        id: 'fast',
        name: 'Evidencia 01.jpg',
        type: 'image',
        status: StagedFileStatus.uploading,
        uploadProgress: 0,
      ),
    ]);

    // The server reports the whole file in one step.
    controller.add(const [
      StagedFile(
        id: 'fast',
        name: 'Evidencia 01.jpg',
        type: 'image',
        status: StagedFileStatus.completed,
        uploadProgress: 1,
      ),
    ]);
    await tester.pump();
    // First frame starts the ticker; the next ones move the bar.
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 150));

    double bar() => tester
        .widget<LinearProgressIndicator>(
          find.byKey(const ValueKey('upload-overall-progress-bar')),
        )
        .value!;
    expect(bar(), greaterThan(0));
    expect(bar(), lessThan(1));
    // Not «done» yet while the bar is still filling.
    expect(find.text('Subiendo 1 de 1'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(bar(), 1);
    expect(find.text('1 archivo subido'), findsOneWidget);
  });

  testWidgets('a single file has nothing to expand', (tester) async {
    await openSheet(tester, files(StagedFileStatus.completed, 1));
    expect(find.byKey(const ValueKey('upload-toggle-view')), findsNothing);
  });
}

class _FileAssetLoader extends AssetLoader {
  const _FileAssetLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async =>
      jsonDecode(
              File('$path/${locale.toLanguageTag()}.json').readAsStringSync())
          as Map<String, dynamic>;
}
