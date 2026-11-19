import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/family/domain/entities/dependent.dart';
import 'package:sacdia_app/features/family/presentation/providers/family_providers.dart';
import 'package:sacdia_app/features/profile/domain/entities/data_export.dart';
import 'package:sacdia_app/features/profile/presentation/providers/data_export_providers.dart';
import 'package:sacdia_app/features/profile/presentation/utils/delete_account_flow.dart';
import 'package:sacdia_app/features/profile/presentation/views/my_data_view.dart';
import 'package:sacdia_app/providers/storage_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../family/family_test_harness.dart';

/// Copias en memoria; pedir una añade una en preparación.
class _FakeExports extends DataExportNotifier {
  _FakeExports(this.initial);

  final List<DataExport> initial;
  int requests = 0;

  @override
  Future<List<DataExport>> build() async => initial;

  @override
  Future<String?> requestExport() async {
    requests++;
    state = AsyncData([
      DataExport(
        exportId: 'new',
        status: DataExportStatus.processing,
        format: 'json',
        createdAt: DateTime.now(),
      ),
      ...state.value!,
    ]);
    return null;
  }
}

DataExport _export(
  String id,
  DataExportStatus status, {
  Duration age = const Duration(days: 3),
  Duration? expiresIn,
}) {
  final now = DateTime.now();
  return DataExport(
    exportId: id,
    status: status,
    format: 'json',
    fileSizeBytes: status == DataExportStatus.ready ? 2048 : null,
    createdAt: now.subtract(age),
    expiresAt: expiresIn == null ? null : now.add(expiresIn),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initLocalization);

  final deleteCalls = <({bool skip, DependentsAck? ack})>[];

  Future<void> fakeRunner(
    BuildContext context,
    WidgetRef ref, {
    bool skipFirstConfirm = false,
    DependentsAck? initialDependentsAck,
  }) async {
    deleteCalls.add((skip: skipFirstConfirm, ack: initialDependentsAck));
  }

  late _FakeExports exports;

  Future<void> pump(
    WidgetTester tester, {
    List<DataExport> list = const [],
    Future<List<DeletionImpactEntry>> Function()? impact,
  }) async {
    deleteCalls.clear();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    exports = _FakeExports(list);
    await pumpFamilyApp(
      tester,
      overrides: [
        authNotifierProvider.overrideWith(FakeAuthNotifier.new),
        sharedPreferencesProvider.overrideWithValue(prefs),
        dataExportProvider.overrideWith(() => exports),
        deletionImpactProvider.overrideWith(
          (ref) => impact == null ? Future.value(const []) : impact(),
        ),
      ],
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => MyDataView(deleteAccountRunner: fakeRunner),
        ),
      ],
    );
    await tester.pumpAndSettle();
  }

  // The polling timer of a copy in progress dies with the view.
  Future<void> leave(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
  }

  SacButton requestButton(WidgetTester tester) =>
      tester.widget<SacButton>(find.byKey(const ValueKey('my-data-request')));

  testWidgets('none yet: what the copy includes, empty history, can request',
      (tester) async {
    await pump(tester);

    expect(find.text('settings.my_data.none_title'.tr()), findsOneWidget);
    expect(find.text('settings.my_data.none_message'.tr()), findsOneWidget);
    expect(find.text('settings.my_data.history_empty'.tr()), findsOneWidget);
    expect(find.byKey(const ValueKey('my-data-cooldown')), findsNothing);
    expect(requestButton(tester).onPressed, isNotNull);
    // The account group closes the screen.
    expect(find.text('settings.my_data.delete_title'.tr()), findsOneWidget);
  });

  testWidgets('requesting swaps the panel to "Preparando tu copia"',
      (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const ValueKey('my-data-request')));
    await tester.pumpAndSettle();

    expect(exports.requests, 1);
    expect(find.text('settings.my_data.none_title'.tr()), findsNothing);
    expect(find.text('settings.my_data.preparing_title'.tr()), findsOneWidget);
    // One copy in progress: the button waits and the history lists it.
    expect(find.text('settings.my_data.in_progress'.tr()), findsOneWidget);
    expect(requestButton(tester).onPressed, isNull);
    expect(find.text('settings.my_data.status_preparing'.tr()), findsOneWidget);
    await leave(tester);
  });

  testWidgets('preparing: panel with the current state only', (tester) async {
    await pump(tester, list: [_export('a', DataExportStatus.processing)]);

    expect(find.text('settings.my_data.preparing_title'.tr()), findsOneWidget);
    expect(find.text('settings.my_data.none_title'.tr()), findsNothing);
    expect(requestButton(tester).onPressed, isNull);
    await leave(tester);
  });

  testWidgets('ready: availability window, download row and cooldown note',
      (tester) async {
    await pump(tester, list: [
      _export(
        'a',
        DataExportStatus.ready,
        age: const Duration(hours: 5),
        expiresIn: const Duration(hours: 30, minutes: 30),
      ),
    ]);

    expect(find.text('settings.my_data.ready_title'.tr()), findsOneWidget);
    expect(find.text('Disponible 31 h más.'), findsOneWidget);
    expect(find.byKey(const ValueKey('export-a')), findsOneWidget);
    expect(find.textContaining('Lista · disponible 31 h más'), findsOneWidget);
    // 24 h cooldown from the copy: 19 h left.
    expect(find.text('Puedes pedir otra copia en 19 h.'), findsOneWidget);
    expect(requestButton(tester).onPressed, isNull);
  });

  testWidgets('ready but older than the cooldown: can request again',
      (tester) async {
    await pump(tester, list: [
      _export('a', DataExportStatus.ready,
          age: const Duration(hours: 30), expiresIn: const Duration(hours: 5)),
    ]);

    expect(find.byKey(const ValueKey('my-data-cooldown')), findsNothing);
    expect(requestButton(tester).onPressed, isNotNull);
  });

  testWidgets('failed shows its own state and lets you ask again',
      (tester) async {
    await pump(tester, list: [_export('a', DataExportStatus.failed)]);

    expect(find.text('settings.my_data.failed_title'.tr()), findsOneWidget);
    expect(requestButton(tester).onPressed, isNotNull);
  });

  testWidgets('expired shows its own state', (tester) async {
    await pump(tester, list: [_export('b', DataExportStatus.expired)]);

    expect(find.text('settings.my_data.expired_title'.tr()), findsOneWidget);
    expect(find.text('settings.my_data.status_expired'.tr()), findsOneWidget);
  });

  group('delete account', () {
    const lucia = DeletionImpactEntry(
      userId: 'lucia-1',
      displayName: 'Lucía',
      outcome: DependentOutcome.otherGuardian,
    );

    Future<void> openSheet(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('my-data-delete')));
      await tester.pumpAndSettle();
    }

    testWidgets('shows what is lost and what happens to each minor',
        (tester) async {
      await pump(tester, impact: () async => const [lucia]);
      await openSheet(tester);

      expect(find.text('settings.delete_sheet.title'.tr()), findsOneWidget);
      expect(find.text('settings.delete_sheet.subtitle'.tr()), findsOneWidget);
      expect(find.byKey(const ValueKey('delete-loss-profile')), findsOneWidget);
      expect(
          find.byKey(const ValueKey('delete-loss-progress')), findsOneWidget);
      expect(find.byKey(const ValueKey('delete-dependent-lucia-1')),
          findsOneWidget);
      expect(find.textContaining('Lucía'), findsOneWidget);
      // Nothing started yet.
      expect(deleteCalls, isEmpty);
    });

    testWidgets('Continuar runs the delete flow without its first confirm',
        (tester) async {
      await pump(tester, impact: () async => const [lucia]);
      await openSheet(tester);

      await tester.tap(find.byKey(const ValueKey('delete-sheet-continue')));
      await tester.pumpAndSettle();

      expect(deleteCalls, hasLength(1));
      expect(deleteCalls.single.skip, isTrue);
      // The sheet listed the minor: it counts as the acknowledgement.
      expect(deleteCalls.single.ack, DependentsAck.acknowledged);
      expect(find.text('settings.delete_sheet.title'.tr()), findsNothing);
    });

    testWidgets('without minors the flow is told there was nothing to list',
        (tester) async {
      await pump(tester);
      await openSheet(tester);

      await tester.tap(find.byKey(const ValueKey('delete-sheet-continue')));
      await tester.pumpAndSettle();

      expect(deleteCalls.single.ack, DependentsAck.none);
    });

    testWidgets('an impact that fails to load does not block', (tester) async {
      await pump(tester, impact: () async => throw Exception('boom'));
      await openSheet(tester);

      final button = tester.widget<SacButton>(
        find.byKey(const ValueKey('delete-sheet-continue')),
      );
      expect(button.onPressed, isNotNull);
      await tester.tap(find.byKey(const ValueKey('delete-sheet-continue')));
      await tester.pumpAndSettle();

      expect(deleteCalls.single.ack, DependentsAck.none);
    });

    testWidgets('Descargar mis datos closes the sheet and does not delete',
        (tester) async {
      await pump(tester, impact: () async => const [lucia]);
      await openSheet(tester);

      await tester.tap(find.byKey(const ValueKey('delete-sheet-download')));
      await tester.pumpAndSettle();

      expect(deleteCalls, isEmpty);
      expect(find.text('settings.delete_sheet.title'.tr()), findsNothing);
      // Still on Mis datos.
      expect(find.byType(MyDataView), findsOneWidget);
    });
  });
}
