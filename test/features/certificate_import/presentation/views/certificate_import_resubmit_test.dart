import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/usecases/cancellation_token.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/features/certificate_import/domain/entities/certificate_import_batch.dart';
import 'package:sacdia_app/features/certificate_import/domain/entities/certificate_import_item.dart';
import 'package:sacdia_app/features/certificate_import/domain/usecases/get_certificate_import_batch.dart';
import 'package:sacdia_app/features/certificate_import/domain/usecases/resubmit_certificate_import_item.dart';
import 'package:sacdia_app/features/certificate_import/domain/usecases/update_certificate_import_item.dart';
import 'package:sacdia_app/features/certificate_import/presentation/providers/certificate_import_providers.dart';
import 'package:sacdia_app/features/certificate_import/presentation/views/certificate_import_status_view.dart';
import 'package:sacdia_app/features/certificate_import/presentation/widgets/certificate_import_item_editor_sheet.dart';

import '../../support/catalog_fakes.dart';
import '../../support/test_app.dart';

const _reason =
    'Debe ser una especialidad de Conquistadores, no de Aventureros';

CertificateImportItem _row(
  CertificateImportItemStatus status, {
  int honorId = 10,
  String name = 'Primeros Auxilios',
}) =>
    CertificateImportItem(
      id: 'row-1',
      batchId: 'batch-1',
      type: CertificateImportItemType.honor,
      honorId: honorId,
      honor: CertificateImportHonorRef(
        id: honorId,
        name: name,
        categoryId: 3,
        categoryName: 'Salud',
      ),
      detectedName: name,
      completedAt: DateTime(2025, 4, 12),
      status: status,
      rejectionReason:
          status == CertificateImportItemStatus.rejected ? _reason : null,
    );

/// The API as the status screen sees it: the row is rejected until a resubmit
/// goes through, and resubmitted afterwards.
class _Api {
  bool resubmitted = false;
  int gets = 0;

  CertificateImportBatch get batch => CertificateImportBatch(
        id: 'batch-1',
        status: 'SUBMITTED',
        items: [
          _row(
            resubmitted
                ? CertificateImportItemStatus.resubmitted
                : CertificateImportItemStatus.rejected,
          ),
        ],
      );
}

class _FakeGet extends Fake implements GetCertificateImportBatch {
  _FakeGet(this.api);
  final _Api api;

  @override
  Future<Either<Failure, CertificateImportBatch>> call(
    String batchId, {
    RequestCancelToken? cancelToken,
  }) async {
    api.gets++;
    return Right(api.batch);
  }
}

class _FakeResubmit extends Fake implements ResubmitCertificateImportItem {
  _FakeResubmit(this.api);
  final _Api api;
  final calls = <ResubmitCertificateImportItemParams>[];

  /// Holds the answer until the test completes it.
  Completer<void>? gate;
  Failure? failWith;

  @override
  Future<Either<Failure, CertificateImportItem>> call(
    ResubmitCertificateImportItemParams params,
  ) async {
    calls.add(params);
    await gate?.future;
    final failure = failWith;
    if (failure != null) {
      // The row was already resent by someone else: the API moved on.
      api.resubmitted = true;
      return Left(failure);
    }
    api.resubmitted = true;
    return Right(_row(CertificateImportItemStatus.resubmitted));
  }
}

/// The review-screen PATCH: a resubmit must never go through it.
class _FakeUpdate extends Fake implements UpdateCertificateImportItem {
  int calls = 0;

  @override
  Future<Either<Failure, CertificateImportItem>> call(
    UpdateCertificateImportItemParams params,
  ) async {
    calls++;
    return Right(_row(CertificateImportItemStatus.needsReview));
  }
}

Future<({_Api api, _FakeResubmit resubmit, _FakeUpdate update})> _show(
  WidgetTester tester,
) async {
  phoneSurface(tester, height: 2400);
  final api = _Api();
  final resubmit = _FakeResubmit(api);
  final update = _FakeUpdate();
  await tester.pumpWidget(
    wrapTestApp(
      const CertificateImportStatusRouteView(batchId: 'batch-1'),
      overrides: [
        ...catalogOverrides(),
        getCertificateImportBatchProvider.overrideWithValue(_FakeGet(api)),
        resubmitCertificateImportItemProvider.overrideWithValue(resubmit),
        updateCertificateImportItemProvider.overrideWithValue(update),
      ],
    ),
  );
  await tester.pumpAndSettle();
  return (api: api, resubmit: resubmit, update: update);
}

Future<void> _openEditor(WidgetTester tester) async {
  await tester.tap(find.text('Corregir y reenviar'));
  await tester.pumpAndSettle();
}

Finder get _resubmitButton => find.widgetWithText(SacButton, 'Reenviar');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initTestLocalization);

  testWidgets('"Corregir y reenviar" opens the editor with the reason', (
    tester,
  ) async {
    final env = await _show(tester);

    await _openEditor(tester);

    expect(find.byType(CertificateImportItemEditorSheet), findsOneWidget);
    // The reason is on the card and, now, at the top of the sheet.
    expect(find.text('Motivo del rechazo'), findsOneWidget);
    expect(find.text(_reason), findsNWidgets(2));
    // Prefilled with the rejected row.
    expect(find.text('Primeros Auxilios'), findsWidgets);
    expect(find.text('Corregir especialidad'), findsOneWidget);
    expect(_resubmitButton, findsOneWidget);
    // Nothing was sent just by opening it, and no way to remove the row.
    expect(env.resubmit.calls, isEmpty);
    expect(find.text('Quitar de la lista'), findsNothing);
    expect(find.text('Guardar'), findsNothing);
  });

  testWidgets('"Reenviar" sends the edited row through resubmit, not PATCH', (
    tester,
  ) async {
    final env = await _show(tester);
    expect(env.api.gets, 1);

    await _openEditor(tester);
    // Change the honor: the reviewer asked for another one.
    await tester.tap(find.text('Primeros Auxilios').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nudos'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(_resubmitButton);
    await tester.tap(_resubmitButton);
    await tester.pumpAndSettle();

    expect(env.update.calls, 0);
    expect(env.resubmit.calls, hasLength(1));
    final call = env.resubmit.calls.single;
    expect(call.batchId, 'batch-1');
    expect(call.itemId, 'row-1');
    final body = call.payload.toJson();
    expect(body['item_type'], 'HONOR');
    expect(body['honor_id'], 11);
    expect(body['completed_at'], '2025-04-12');
    expect(body['mark_as_ready'], true);

    // The sheet closed, the batch was reloaded and the row reads "Reenviada".
    expect(find.byType(CertificateImportItemEditorSheet), findsNothing);
    expect(env.api.gets, 2);
    expect(find.text('Reenviada'), findsOneWidget);
    expect(find.text('Rechazada'), findsNothing);
    expect(find.text('Corregir y reenviar'), findsNothing);
    expect(find.text('Fila reenviada a revisión.'), findsOneWidget);
    expect(
      find.text('Aprobadas: 0 · Rechazadas: 0 · Pendientes: 1'),
      findsOneWidget,
    );
  });

  testWidgets('a row that was already resent says so and refreshes', (
    tester,
  ) async {
    final env = await _show(tester);
    env.resubmit.failWith = const ServerFailure(
      message: 'CERTIFICATE_IMPORT_ITEM_NOT_REJECTED',
      code: 400,
      errorCode: 'CERTIFICATE_IMPORT_ITEM_NOT_REJECTED',
    );

    await _openEditor(tester);
    await tester.ensureVisible(_resubmitButton);
    await tester.tap(_resubmitButton);
    await tester.pumpAndSettle();

    expect(env.resubmit.calls, hasLength(1));
    expect(find.text('Esta fila ya fue reenviada.'), findsOneWidget);
    expect(
      find.text('No pudimos completar la acción. Inténtalo de nuevo.'),
      findsNothing,
    );
    // Nothing left to fix: the sheet closes and the screen shows the new state.
    expect(find.byType(CertificateImportItemEditorSheet), findsNothing);
    expect(env.api.gets, 2);
    expect(find.text('Reenviada'), findsOneWidget);
    expect(find.text('Corregir y reenviar'), findsNothing);
  });

  testWidgets('another failure keeps the sheet open and says what happened', (
    tester,
  ) async {
    final env = await _show(tester);
    env.resubmit.failWith = const ServerFailure(message: 'boom', code: 500);

    await _openEditor(tester);
    await tester.ensureVisible(_resubmitButton);
    await tester.tap(_resubmitButton);
    await tester.pumpAndSettle();

    expect(find.byType(CertificateImportItemEditorSheet), findsOneWidget);
    expect(
      find.text('No pudimos completar la acción. Inténtalo de nuevo.'),
      findsOneWidget,
    );
    // The row is still rejected and can be fixed again.
    expect(tester.widget<SacButton>(_resubmitButton).onPressed, isNotNull);
  });

  testWidgets('a second tap while sending does not send twice', (tester) async {
    final env = await _show(tester);
    final gate = env.resubmit.gate = Completer<void>();

    await _openEditor(tester);
    await tester.ensureVisible(_resubmitButton);
    await tester.tap(_resubmitButton);
    await tester.pump();
    await tester.tap(_resubmitButton.first, warnIfMissed: false);
    await tester.tap(_resubmitButton.first, warnIfMissed: false);
    await tester.pump();

    // While in flight the action is disabled and shows its progress.
    for (final button in tester.widgetList<SacButton>(_resubmitButton)) {
      expect(button.onPressed, isNull);
    }
    expect(env.resubmit.calls, hasLength(1));

    gate.complete();
    await tester.pumpAndSettle();
    expect(env.resubmit.calls, hasLength(1));
    expect(find.byType(CertificateImportItemEditorSheet), findsNothing);
  });
}
