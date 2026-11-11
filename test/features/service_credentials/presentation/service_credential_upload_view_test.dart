import 'dart:async';
import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/consent/consent_evidence.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_notice.dart';
import 'package:sacdia_app/core/widgets/sac_settings.dart';
import 'package:sacdia_app/features/service_credentials/presentation/views/service_credential_upload_view.dart';

import '../service_credentials_test_support.dart';

/// Picker that returns a fixed file instead of opening the OS pickers.
ConsentEvidencePicker pickerFor({
  String name = 'constancia.pdf',
  int size = 4096,
  String mime = 'application/pdf',
}) =>
    ConsentEvidencePicker(
      pickPdf: () async => (path: '/tmp/$name', name: name, size: size),
      pickImage: (_) async => null,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initLocalization);

  late FakeServiceCredentialsRepository repo;
  late GoRouter router;
  setUp(() => repo = FakeServiceCredentialsRepository());

  /// Home at `/` and the upload form pushed on top, so a successful submit
  /// can pop back to a visible screen.
  Future<void> open(
    WidgetTester tester, {
    ConsentEvidencePicker? picker,
    bool settle = true,
  }) async {
    router = await pumpCredentialsApp(
      tester,
      home: const Scaffold(body: Text('home')),
      overrides: credentialOverrides(repo),
      routes: [
        GoRoute(
          path: '/service-credentials/new',
          builder: (_, __) => ServiceCredentialUploadView(
            picker: picker ?? pickerFor(),
            clock: () => DateTime(2026, 6, 15, 9),
          ),
        ),
      ],
    );
    unawaited(router.push('/service-credentials/new'));
    await tester.pumpAndSettle();
  }

  Future<void> pickDate(WidgetTester tester) async {
    await tester.tap(find.text('Elige la fecha'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aceptar'));
    await tester.pumpAndSettle();
  }

  Future<void> pickPdf(WidgetTester tester) async {
    await tester.tap(find.text('Agregar documento'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elegir un PDF'));
    await tester.pumpAndSettle();
  }

  Finder submitButton() => find.widgetWithText(SacButton, 'Enviar a revisión');

  testWidgets('asks only for date and document: no variant or hours UI',
      (tester) async {
    await open(tester);
    expect(find.text('Fecha de conclusión'), findsOneWidget);
    expect(find.text('Elige la fecha'), findsOneWidget);
    expect(find.text('Documento'), findsOneWidget);
    expect(find.text('Tipo de constancia'), findsNothing);
    expect(find.text('Curso de consejeros'), findsNothing);
    expect(find.text('10 horas de consejería'), findsNothing);
    expect(find.text('Horas de consejería'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(
      find.text(
        'Sube la constancia de tu curso de consejería (10 horas). '
        'Una persona la revisará.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('submitting an empty form shows every error and calls nothing',
      (tester) async {
    await open(tester);
    await tester.tap(submitButton());
    await tester.pumpAndSettle();

    expect(find.text('Elige la fecha en que concluiste.'), findsOneWidget);
    expect(find.text('Elige el documento de tu constancia.'), findsOneWidget);
    expect(repo.calls, isNot(contains('submit')));
  });

  testWidgets('the date picker cannot go past today', (tester) async {
    await open(tester);
    await tester.tap(find.text('Elige la fecha'));
    await tester.pumpAndSettle();
    final calendar =
        tester.widget<CalendarDatePicker>(find.byType(CalendarDatePicker));
    expect(calendar.lastDate, DateTime(2026, 6, 15));
    expect(calendar.initialDate, DateTime(2026, 6, 15));
  });

  testWidgets('choosing a PDF shows its name and size', (tester) async {
    await open(tester,
        picker: pickerFor(name: 'mi-constancia.pdf', size: 3072));
    await pickPdf(tester);
    expect(find.text('mi-constancia.pdf'), findsOneWidget);
    expect(find.text('3 KB'), findsOneWidget);
    // The add tile is replaced by the card with a compact «Cambiar» action.
    expect(find.text('Agregar documento'), findsNothing);
    expect(find.widgetWithText(SacButton, 'Cambiar'), findsOneWidget);
    expect(find.text('Cambiar documento'), findsNothing);
  });

  testWidgets('a picker-generated name is replaced by the file kind',
      (tester) async {
    await open(tester,
        picker: pickerFor(name: 'image_picker_EF659504-1111-2222.pdf'));
    await pickPdf(tester);
    expect(find.textContaining('image_picker_'), findsNothing);
    expect(find.text('PDF'), findsOneWidget);
  });

  testWidgets('«Cambiar» opens the source sheet again', (tester) async {
    await open(tester, picker: pickerFor(name: 'primero.pdf'));
    await pickPdf(tester);
    await tester.tap(find.widgetWithText(SacButton, 'Cambiar'));
    await tester.pumpAndSettle();
    expect(find.text('Elegir un PDF'), findsOneWidget);
  });

  testWidgets('shows the add tile with its helper while there is no file',
      (tester) async {
    await open(tester);
    expect(find.text('Agregar documento'), findsOneWidget);
    expect(find.text('PDF, JPG o PNG · hasta 10 MB'), findsOneWidget);
  });

  testWidgets('the chosen date is shown formatted in the picker field',
      (tester) async {
    await open(tester);
    await pickDate(tester);
    expect(find.text('Elige la fecha'), findsNothing);
    expect(find.text('15 jun 2026'), findsOneWidget);
  });

  testWidgets('the primary action lives in the pinned bar', (tester) async {
    await open(tester);
    expect(
      find.descendant(
        of: find.byType(SacPinnedActionBar),
        matching: submitButton(),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a file over 10 MB is rejected before any request',
      (tester) async {
    await open(
      tester,
      picker: pickerFor(size: consentEvidenceMaxBytes + 1),
    );
    await pickPdf(tester);
    await pickDate(tester);
    await tester.tap(submitButton());
    await tester.pumpAndSettle();
    expect(find.text('El archivo supera los 10 MB. Elige uno más pequeño.'),
        findsOneWidget);
    expect(repo.calls, isNot(contains('submit')));
  });

  testWidgets('a WebP is not an accepted constancia type', (tester) async {
    await open(
      tester,
      picker: ConsentEvidencePicker(
        pickPdf: () async => null,
        pickImage: (_) async => XFile.fromData(
          Uint8List(64),
          name: 'foto.webp',
          mimeType: 'image/webp',
        ),
      ),
    );
    await tester.tap(find.text('Agregar documento'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elegir de la galería'));
    await tester.pumpAndSettle();
    await pickDate(tester);
    await tester.tap(submitButton());
    await tester.pumpAndSettle();
    expect(
        find.text('Solo se aceptan archivos PDF, JPG o PNG.'), findsOneWidget);
    expect(repo.calls, isNot(contains('submit')));
  });

  testWidgets('the credential submits, confirms and goes back', (tester) async {
    await open(tester);
    await pickDate(tester);
    await pickPdf(tester);
    await tester.tap(submitButton());
    await tester.pumpAndSettle();

    expect(repo.calls, contains('submit'));
    expect(repo.lastDraft?.completedAt, DateTime(2026, 6, 15));
    expect(repo.lastFile?.name, 'constancia.pdf');
    expect(find.text('Constancia enviada a revisión.'), findsOneWidget);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('a server error is shown by code and the form stays for retry',
      (tester) async {
    repo.submitResult = const Left(ServerFailure(
      message: 'raw server text',
      code: 409,
      errorCode: 'SERVICE_CREDENTIAL_PENDING_EXISTS',
    ));
    await open(tester);
    await pickDate(tester);
    await pickPdf(tester);
    await tester.tap(submitButton());
    await tester.pumpAndSettle();

    expect(
      find.text(
          'Ya tienes una constancia en revisión. Espera su resultado o retírala para subir otra.'),
      findsOneWidget,
    );
    expect(find.text('raw server text'), findsNothing);
    // The failure is a notice inside the pinned bar, above the button.
    expect(
      find.descendant(
        of: find.byType(SacPinnedActionBar),
        matching: find.byType(SacNotice),
      ),
      findsOneWidget,
    );
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.text('constancia.pdf'), findsOneWidget);

    // Retry with the same file succeeds.
    repo.submitResult = Right(credential());
    await tester.tap(find.widgetWithText(SacButton, 'Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('an invalid-file server code is translated', (tester) async {
    repo.submitResult = const Left(ServerFailure(
      message: 'x',
      code: 422,
      errorCode: 'SERVICE_CREDENTIAL_FILE_INVALID',
    ));
    await open(tester);
    await pickDate(tester);
    await pickPdf(tester);
    await tester.tap(submitButton());
    await tester.pumpAndSettle();
    expect(
      find.text(
          'El archivo no es válido. Sube un PDF, JPG o PNG de hasta 10 MB.'),
      findsOneWidget,
    );
  });
}
