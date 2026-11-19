import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/evidence_staging/evidence_staging_layout.dart';
import 'package:sacdia_app/core/widgets/evidence_staging/evidence_staging_manager.dart';
import 'package:sacdia_app/core/widgets/evidence_staging/staged_file.dart';

import '../../../support/l10n_test_support.dart';

StagedFile _remote(int i) => StagedFile(
      id: 'r$i',
      name: 'Evidencia $i.pdf',
      type: 'pdf',
      status: StagedFileStatus.uploaded,
    );

Future<void> _pump(
  WidgetTester tester, {
  int remote = 0,
  int maxFiles = 3,
  bool canModify = true,
  EvidenceStagingLayout layout = EvidenceStagingLayout.addTile,
  bool isResend = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: EvidenceStagingManager(
          layout: layout,
          sectionTitle: 'Archivos',
          isResend: isResend,
          existingFiles: [for (var i = 0; i < remote; i++) _remote(i)],
          maxFiles: maxFiles,
          canModify: canModify,
          onUpload: (_, __, ___) async {},
          onDeleteRemote: (_) async {},
          onSubmit: () async {},
          fileNameBuilder: (name, _) => name,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(loadSpanishTranslations);

  testWidgets('empty and modifiable: the grid is just the add tile',
      (tester) async {
    await _pump(tester);

    expect(find.byKey(const ValueKey('evidence-add-tile')), findsOneWidget);
    expect(find.text('Agregar'), findsOneWidget);
    expect(find.text('ARCHIVOS'), findsOneWidget);
    expect(find.text('0 de 3'), findsOneWidget);
    expect(find.text('Enviar archivos'), findsOneWidget);
  });

  testWidgets('the add tile opens camera / gallery / PDF', (tester) async {
    await _pump(tester);

    await tester.tap(find.byKey(const ValueKey('evidence-add-tile')));
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('evidence-source-camera')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('evidence-source-gallery')), findsOneWidget);
    expect(find.byKey(const ValueKey('evidence-source-pdf')), findsOneWidget);
    expect(find.text('Tomar foto'), findsOneWidget);
    expect(find.text('Elegir de la galería'), findsOneWidget);
    expect(find.text('Elegir PDF'), findsOneWidget);
  });

  testWidgets('the footer counts the files: "Enviar 1 archivo" / "Enviar 2"',
      (tester) async {
    await _pump(tester, remote: 1);
    expect(find.text('Enviar 1 archivo'), findsOneWidget);

    await _pump(tester, remote: 2);
    await tester.pump();
    expect(find.text('Enviar 2 archivos'), findsOneWidget);
    expect(find.text('2 de 3'), findsOneWidget);
  });

  testWidgets('a returned item offers "Reenviar"', (tester) async {
    await _pump(tester, remote: 2, isResend: true);
    expect(find.text('Reenviar'), findsOneWidget);
    expect(find.textContaining('Enviar 2'), findsNothing);
  });

  testWidgets('the add tile hides at the file limit', (tester) async {
    await _pump(tester, remote: 3);
    expect(find.byKey(const ValueKey('evidence-add-tile')), findsNothing);
  });

  testWidgets('read-only: no add tile, no footer, only the total',
      (tester) async {
    await _pump(tester, remote: 2, canModify: false);

    expect(find.byKey(const ValueKey('evidence-add-tile')), findsNothing);
    expect(find.byType(EvidenceStagingActionBar), findsNothing);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('read-only and empty: says there are no files', (tester) async {
    await _pump(tester, canModify: false);

    expect(find.byKey(const ValueKey('evidence-add-tile')), findsNothing);
    expect(find.text('No hay archivos de evidencia.'), findsOneWidget);
  });

  testWidgets('classic layout keeps the Imagen / PDF buttons and no tile',
      (tester) async {
    await _pump(tester, remote: 1, layout: EvidenceStagingLayout.classic);

    expect(find.byKey(const ValueKey('evidence-add-tile')), findsNothing);
    expect(find.text('Imagen'), findsOneWidget);
    expect(find.text('PDF'), findsWidgets);
    expect(find.text('Enviar a validación'), findsOneWidget);
    expect(find.text('1 de 3 archivos'), findsOneWidget);
  });
}
