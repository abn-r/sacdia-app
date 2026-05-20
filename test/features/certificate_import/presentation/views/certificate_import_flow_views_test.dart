import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/config/router.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/features/certificate_import/domain/entities/certificate_import_batch.dart';
import 'package:sacdia_app/features/certificate_import/domain/entities/certificate_import_file.dart';
import 'package:sacdia_app/features/certificate_import/domain/entities/certificate_import_item.dart';
import 'package:sacdia_app/features/certificate_import/presentation/views/certificate_import_processing_view.dart';
import 'package:sacdia_app/features/certificate_import/presentation/views/certificate_import_review_view.dart';
import 'package:sacdia_app/features/certificate_import/presentation/views/certificate_import_status_view.dart';
import 'package:sacdia_app/features/certificate_import/presentation/views/certificate_import_upload_view.dart';
import 'package:sacdia_app/features/certificate_import/presentation/widgets/certificate_import_proof_card.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: child,
    );

CertificateImportBatch _batch({bool complete = false, bool rejected = false}) {
  return CertificateImportBatch(
    id: 'batch-1',
    status: rejected ? 'REJECTED' : 'DRAFT',
    files: const [
      CertificateImportFile(
        id: 'file-1',
        url: 'mock://receipt.jpg',
        name: 'Acampada Sinaí 2026',
        type: 'image/jpeg',
      ),
    ],
    items: [
      CertificateImportItem(
        id: 'honor-1',
        type: CertificateImportItemType.honor,
        honorId: complete ? 10 : null,
        detectedName: 'Primeros Auxilios',
        completedAt: complete ? DateTime(2026, 4, 12) : null,
        ocrConfidence: 0.82,
        status: complete
            ? CertificateImportItemStatus.ready
            : CertificateImportItemStatus.needsReview,
        rejectionReason:
            rejected ? 'La fecha no coincide con el comprobante' : null,
      ),
      CertificateImportItem(
        id: 'class-1',
        type: CertificateImportItemType.clazz,
        classId: 3,
        detectedName: 'Amigo',
        completedAt: DateTime(2026, 4, 12),
        ocrConfidence: 0.91,
        status: CertificateImportItemStatus.ready,
      ),
    ],
  );
}

void main() {
  group('Certificate import routing', () {
    test(
        'declares route names for upload, processing, review and imported proof',
        () {
      expect(RouteNames.certificateImportUpload, '/certificate-import');
      expect(RouteNames.certificateImportProcessingPath('batch-1'),
          '/certificate-import/batch-1/processing');
      expect(RouteNames.certificateImportReviewPath('batch-1'),
          '/certificate-import/batch-1/review');
      expect(RouteNames.certificateImportProofPath('item-1'),
          '/certificate-import/item/item-1/proof');
      expect(routerProvider, isNotNull);
    });
  });

  group('CertificateImportUploadView', () {
    testWidgets('shows upload, camera and file actions with accessible labels',
        (tester) async {
      var uploadCalls = 0;
      await tester.pumpWidget(_wrap(CertificateImportUploadView(
        onCreateMockUpload: () async => uploadCalls++,
      )));

      expect(find.text('Subir comprobante'), findsOneWidget);
      expect(find.text('Tomar foto'), findsOneWidget);
      expect(find.text('Elegir archivo'), findsOneWidget);

      await tester.tap(find.text('Subir comprobante'));
      await tester.pump();

      expect(uploadCalls, 1);
    });
  });

  group('CertificateImportProcessingView', () {
    testWidgets('shows OCR steps and a manual fallback action', (tester) async {
      var fallbackCalls = 0;
      await tester.pumpWidget(_wrap(CertificateImportProcessingView(
        batchId: 'batch-1',
        autoStart: false,
        onManualFallback: () => fallbackCalls++,
      )));

      expect(find.text('Leyendo comprobante'), findsOneWidget);
      expect(find.text('Subiendo archivo'), findsOneWidget);
      expect(find.text('Leyendo texto'), findsOneWidget);
      expect(find.text('Completar manualmente'), findsOneWidget);

      await tester.tap(find.text('Completar manualmente'));
      await tester.pump();
      expect(fallbackCalls, 1);
    });
  });

  group('CertificateImportReviewView', () {
    testWidgets(
        'renders mixed HONOR/CLASS cards, counters and disabled submit when data is missing',
        (tester) async {
      await tester.pumpWidget(_wrap(CertificateImportReviewView(
        initialBatch: _batch(),
      )));

      expect(find.text('1 especialidad y 1 clase'), findsOneWidget);
      expect(find.text('HONOR'), findsOneWidget);
      expect(find.text('CLASE'), findsOneWidget);
      expect(find.text('Primeros Auxilios'), findsOneWidget);
      expect(find.text('Amigo'), findsOneWidget);

      final submit = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Enviar a revisión'),
      );
      expect(submit.onPressed, isNull);
    });

    testWidgets('opens editor and enables submit after item correction',
        (tester) async {
      CertificateImportItem? updated;
      await tester.pumpWidget(_wrap(CertificateImportReviewView(
        initialBatch: _batch(),
        onUpdateItem: (item) async => updated = item,
      )));

      await tester.tap(find.text('Corregir').first);
      await tester.pumpAndSettle();

      await tester.enterText(find.bySemanticsLabel('ID catálogo'), '10');
      await tester.enterText(
          find.bySemanticsLabel('Fecha completada'), '2026-04-12');
      await tester.tap(find.text('Guardar corrección'));
      await tester.pumpAndSettle();

      expect(updated?.honorId, 10);
      expect(updated?.completedAt, DateTime(2026, 4, 12));

      final submit = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Enviar a revisión'),
      );
      expect(submit.onPressed, isNotNull);
    });
  });

  group('CertificateImportStatusView', () {
    testWidgets('shows rejected correction and resubmit affordance',
        (tester) async {
      var resubmitCalls = 0;
      await tester.pumpWidget(_wrap(CertificateImportStatusView(
        batch: _batch(rejected: true),
        onResubmitItem: (_) async => resubmitCalls++,
      )));

      expect(find.text('Hay correcciones pendientes'), findsOneWidget);
      expect(
          find.text('La fecha no coincide con el comprobante'), findsOneWidget);

      await tester.tap(find.text('Corregir y reenviar').first);
      await tester.pump();
      expect(resubmitCalls, 1);
    });
  });

  group('CertificateImportProofCard', () {
    testWidgets('renders simplified imported proof from item props',
        (tester) async {
      await tester.pumpWidget(_wrap(Scaffold(
        body: CertificateImportProofCard(
            item: _batch(complete: true).items.first),
      )));

      expect(find.text('Registro importado'), findsOneWidget);
      expect(find.text('Primeros Auxilios'), findsOneWidget);
      expect(find.text('12/04/2026'), findsOneWidget);
    });
  });
}
