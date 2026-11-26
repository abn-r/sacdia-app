/// Widget tests for the setup of a union camporee: order window, products on
/// sale, and the supplies (cutoff, delivery times, products).
library;

import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' as intl;
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/errors/forbidden.dart';
import 'package:sacdia_app/core/utils/money_format.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_filter_chip.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_grouped_section.dart';
import 'package:sacdia_app/features/camporee_orders/domain/entities/camporee_order_offering.dart';
import 'package:sacdia_app/features/camporee_orders/domain/entities/camporee_order_product.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_camporee_orders.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_plain_row.dart';

import 'supervision_camporee_orders_test_harness.dart';
import 'supervision_view_test_harness.dart';

const _forbiddenText = 'No tienes permiso para hacer esto en este camporee.';
const _ordersOnly = [kSupervisionAppView];

final _opens = DateTime(2027, 3, 10, 10, 30);
final _closes = DateTime(2027, 3, 12, 8, 0);

String _moment(DateTime value) =>
    intl.DateFormat.yMMMd('es').add_Hm().format(value);

Finder get _sheet => find.byType(BottomSheet);

Finder _inSheet(Finder matching) =>
    find.descendant(of: _sheet, matching: matching);

Finder get _save => _inSheet(find.byType(SacButton));

Finder _row(String title) => find.widgetWithText(SupervisionPlainRow, title);

Finder _inRow(String title, String text) =>
    find.descendant(of: _row(title), matching: find.text(text));

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _openRow(WidgetTester tester, String title) =>
    _tap(tester, _row(title));

Future<void> _toSupplies(WidgetTester tester) async {
  // On a narrow, scaled surface the second chip sits past the right edge of
  // its horizontal list: scroll the list, not the page.
  final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
  if (tester.getCenter(find.text('Insumos')).dx > width) {
    await tester.drag(find.byType(SacFilterChip).first, const Offset(-300, 0));
    await tester.pumpAndSettle();
  }
  await _tap(tester, find.text('Insumos'));
}

Future<void> _saveSheet(WidgetTester tester) async {
  // The sheet scrolls: on a short surface the button can sit below the fold.
  await tester.ensureVisible(_save);
  await tester.pumpAndSettle();
  await _tap(tester, _save);
}

Future<void> _type(WidgetTester tester, int index, String text) async {
  await tester.enterText(_inSheet(find.byType(TextFormField)).at(index), text);
  await tester.pump();
}

/// Brings [finder] clear of the frosted top bar on a short surface.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.drag(find.byType(CustomScrollView), const Offset(0, 200));
  await tester.pumpAndSettle();
}

/// Taps [day] in the open date picker, confirms, then confirms the time sheet
/// without touching the wheels.
Future<void> _pickDay(WidgetTester tester, int day) async {
  await tester.tap(
    find.descendant(
      of: find.byType(DatePickerDialog),
      matching: find.text('$day'),
    ),
  );
  await tester.pump();
  await tester.tap(find.text('Aceptar'));
  await tester.pumpAndSettle();
  expect(find.text('Seleccionar hora'), findsOneWidget);
  await tester.tap(find.text('Listo'));
  await tester.pumpAndSettle();
}

// Library used by the product tests.
final _gorra = orderProduct('p1', title: 'Gorra');
final _playera = orderProduct(
  'p2',
  title: 'Playera',
  scheme: CamporeeOrderSizeScheme.letter,
  options: [
    sizeOption('s'),
    sizeOption('m'),
    sizeOption('xl', active: false),
  ],
);
final _termo = orderProduct('p3', title: 'Termo');
final _chamarra = orderProduct(
  'p4',
  title: 'Chamarra',
  scheme: CamporeeOrderSizeScheme.letter,
  options: [sizeOption('s', active: false)],
);

/// Gorra and Playera on sale; Termo has only an inactive offering; an active
/// offering of a product that left the library ("old").
FakeOrdersRepo _productsRepo({bool ordersEnabled = false}) => FakeOrdersRepo(
      config: orderConfig(
        ordersEnabled: ordersEnabled,
        products: [_gorra, _playera, _termo, _chamarra],
        offerings: [
          orderOffering(_gorra, priceCentavos: 12050, sortOrder: 0),
          orderOffering(_playera, priceCentavos: 8000, sortOrder: 3),
          orderOffering(
            orderProduct('old', title: 'Viejo'),
            priceCentavos: 100,
            sortOrder: 5,
          ),
          orderOffering(_termo,
              priceCentavos: 999, active: false, sortOrder: 4),
        ],
      ),
    );

void main() {
  setUpAll(initSupervisionViewTests);

  group('general', () {
    testWidgets('a non numeric id shows the error state and calls nothing', (
      tester,
    ) async {
      final repo = await pumpOrdersView(tester, camporeeId: 'abc');

      expect(find.byType(SacErrorState), findsOneWidget);
      expect(find.text('No se pudo cargar la configuración'), findsOneWidget);
      expect(find.text('Revisa tu conexión e inténtalo de nuevo.'),
          findsOneWidget);
      expect(find.text('Pedidos e insumos'), findsOneWidget);
      expect(repo.orderConfigCalls, isEmpty);
      expect(repo.supplyCatalogCalls, isEmpty);
    });

    testWidgets('shows the title with the camporee name as subtitle', (
      tester,
    ) async {
      await pumpOrdersView(tester);

      expect(find.text('Pedidos e insumos'), findsOneWidget);
      expect(find.text('Camporee Unión 2026'), findsOneWidget);
    });

    testWidgets('shows the skeleton while the config loads', (tester) async {
      final gate = Completer<void>();
      final repo = FakeOrdersRepo()
        ..onOrderConfig = (_) async {
          await gate.future;
          return Right(orderConfig());
        };
      await pumpOrdersView(tester, repo: repo, settle: false);

      expect(find.byType(SacSkeletonList), findsOneWidget);
      expect(find.text('Pedidos e insumos'), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(SacSkeletonList), findsNothing);
      expect(find.text('Pedidos habilitados'), findsOneWidget);
    });

    testWidgets(
        'without the supplies capability there are no chips and the '
        'catalog is never requested', (tester) async {
      final repo = await pumpOrdersView(tester, capabilities: _ordersOnly);

      expect(find.byType(SacFilterChip), findsNothing);
      expect(find.text('Insumos'), findsNothing);
      expect(find.text('Pedidos habilitados'), findsOneWidget);
      expect(repo.orderConfigCalls, [7]);
      expect(repo.supplyCatalogCalls, isEmpty);
    });

    testWidgets(
        'with the capability, switching to Insumos requests the '
        'catalog once', (tester) async {
      final repo = await pumpOrdersView(tester);

      expect(find.byType(SacFilterChip), findsNWidgets(2));
      expect(find.text('Pedidos'), findsOneWidget);
      expect(repo.supplyCatalogCalls, isEmpty);

      await _toSupplies(tester);

      expect(repo.supplyCatalogCalls, [7]);
      expect(find.text('Corte de edición'), findsOneWidget);
      expect(find.text('Pedidos habilitados'), findsNothing);
    });

    testWidgets('load error on the orders tab shows retry that reloads', (
      tester,
    ) async {
      final repo = FakeOrdersRepo();
      repo.onOrderConfig = (_) async => repo.orderConfigCalls.length == 1
          ? const Left(kOrdersBoom)
          : Right(
              orderConfig(),
            );
      await pumpOrdersView(tester, repo: repo);

      expect(find.text('No se pudo cargar la configuración'), findsOneWidget);
      expect(find.byType(ForbiddenView), findsNothing);

      await _tap(tester, find.text('Reintentar'));

      expect(repo.orderConfigCalls, [7, 7]);
      expect(find.text('No se pudo cargar la configuración'), findsNothing);
      expect(find.text('Pedidos habilitados'), findsOneWidget);
    });

    testWidgets('load error on the supplies tab shows retry that reloads', (
      tester,
    ) async {
      final repo = FakeOrdersRepo();
      repo.onSupplyCatalog = (_) async => repo.supplyCatalogCalls.length == 1
          ? const Left(kOrdersBoom)
          : Right(supplyCatalog());
      await pumpOrdersView(tester, repo: repo);
      await _toSupplies(tester);

      expect(find.text('No se pudo cargar la configuración'), findsOneWidget);
      // The chips stay so the user can go back.
      expect(find.byType(SacFilterChip), findsNWidgets(2));

      await _tap(tester, find.text('Reintentar'));

      expect(repo.supplyCatalogCalls, [7, 7]);
      expect(find.text('Corte de edición'), findsOneWidget);
    });

    testWidgets('a 403 renders the forbidden state without retry', (
      tester,
    ) async {
      final repo = FakeOrdersRepo()
        ..onOrderConfig = (_) async => const Left(kOrdersForbidden);
      await pumpOrdersView(tester, repo: repo);

      expect(find.byType(ForbiddenView), findsOneWidget);
      expect(find.text('Reintentar'), findsNothing);
      expect(find.text('No se pudo cargar la configuración'), findsNothing);
    });

    testWidgets('a 403 on the supplies tab renders the forbidden state', (
      tester,
    ) async {
      final repo = FakeOrdersRepo()
        ..onSupplyCatalog = (_) async => const Left(kOrdersForbidden);
      await pumpOrdersView(tester, repo: repo);
      await _toSupplies(tester);

      expect(find.byType(ForbiddenView), findsOneWidget);
      expect(find.text('Reintentar'), findsNothing);
    });

    testWidgets('pull to refresh reloads the orders tab only', (tester) async {
      final repo = await pumpOrdersView(tester);

      final done = tester
          .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
          .show();
      await tester.pumpAndSettle();
      await done;

      expect(repo.orderConfigCalls, [7, 7]);
      expect(repo.supplyCatalogCalls, isEmpty);
    });

    testWidgets('pull to refresh reloads the supplies tab only', (
      tester,
    ) async {
      final repo = await pumpOrdersView(tester);
      await _toSupplies(tester);

      final done = tester
          .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
          .show();
      await tester.pumpAndSettle();
      await done;

      expect(repo.supplyCatalogCalls, [7, 7]);
      expect(repo.orderConfigCalls, [7]);
    });

    testWidgets('a real drag arms the refresh on a short surface', (
      tester,
    ) async {
      final repo = await pumpOrdersView(tester, size: const Size(800, 900));

      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();

      expect(repo.orderConfigCalls, [7, 7]);
    });
  });

  group('orders tab: window', () {
    testWidgets('the switch reflects the setting', (tester) async {
      await pumpOrdersView(
        tester,
        repo: FakeOrdersRepo(config: orderConfig(ordersEnabled: true)),
      );
      expect(find.text('VENTANA DE PEDIDOS'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    });

    testWidgets('the switch is off when orders are disabled', (tester) async {
      await pumpOrdersView(tester);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    });

    testWidgets('toggling sends only ordersEnabled, toasts and reloads', (
      tester,
    ) async {
      final repo = FakeOrdersRepo();
      repo.onUpdateSettings = (patch) async {
        repo.config = orderConfig(ordersEnabled: patch.ordersEnabled!);
        return Right(repo.config.settings);
      };
      await pumpOrdersView(tester, repo: repo);

      await _tap(tester, find.byType(Switch));

      expect(repo.settingsCalls, hasLength(1));
      final patch = repo.settingsCalls.single;
      expect(patch.ordersEnabled, isTrue);
      expect(patch.opensAt, isNull);
      expect(patch.deadline, isNull);
      expect(patch.clearOpensAt, isFalse);
      expect(patch.clearDeadline, isFalse);
      expect(find.text('Guardado'), findsOneWidget);
      expect(repo.orderConfigCalls, [7, 7]);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    });

    testWidgets('turning the switch off sends ordersEnabled false', (
      tester,
    ) async {
      final repo = FakeOrdersRepo(config: orderConfig(ordersEnabled: true));
      await pumpOrdersView(tester, repo: repo);

      await _tap(tester, find.byType(Switch));

      expect(
        repo.settingsCalls.single,
        const SupervisionOrderSettingsPatch(ordersEnabled: false),
      );
    });

    testWidgets(
        'a forbidden save shows the error toast and keeps the server '
        'value', (tester) async {
      final repo = FakeOrdersRepo()
        ..onUpdateSettings = (_) async => const Left(kOrdersForbidden);
      await pumpOrdersView(tester, repo: repo);

      await _tap(tester, find.byType(Switch));

      expect(find.text(_forbiddenText), findsOneWidget);
      expect(find.text('Guardado'), findsNothing);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      // Nothing changed on the server: no reload.
      expect(repo.orderConfigCalls, [7]);
    });

    testWidgets('a failed save with a server message shows that message', (
      tester,
    ) async {
      final repo = FakeOrdersRepo()
        ..onUpdateSettings =
            (_) async => Left(codedFailure('SOMETHING_ELSE', 'no se pudo'));
      await pumpOrdersView(tester, repo: repo);

      await _tap(tester, find.byType(Switch));

      expect(find.text('no se pudo'), findsOneWidget);
    });

    testWidgets('the switch is disabled while a save is in flight', (
      tester,
    ) async {
      final gate = Completer<void>();
      final repo = FakeOrdersRepo();
      repo.onUpdateSettings = (_) async {
        await gate.future;
        return Right(repo.config.settings);
      };
      await pumpOrdersView(tester, repo: repo);

      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
      await tester.tap(find.byType(Switch), warnIfMissed: false);
      await tester.pump();
      expect(repo.settingsCalls, hasLength(1));

      gate.complete();
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNotNull);
    });

    testWidgets('rows show "Sin fecha" without dates', (tester) async {
      await pumpOrdersView(tester);

      expect(_inRow('Apertura', 'Sin fecha'), findsOneWidget);
      expect(_inRow('Cierre', 'Sin fecha'), findsOneWidget);
    });

    testWidgets('rows show the formatted local date and time', (tester) async {
      await pumpOrdersView(
        tester,
        repo: FakeOrdersRepo(
          config: orderConfig(opensAt: _opens, deadline: _closes),
        ),
      );

      expect(_inRow('Apertura', _moment(_opens)), findsOneWidget);
      expect(_inRow('Cierre', _moment(_closes)), findsOneWidget);
      expect(find.text('Sin fecha'), findsNothing);
    });

    testWidgets('tapping a row with a date opens the change or remove sheet', (
      tester,
    ) async {
      await pumpOrdersView(
        tester,
        repo: FakeOrdersRepo(config: orderConfig(opensAt: _opens)),
      );

      await _openRow(tester, 'Apertura');

      expect(_inSheet(find.text('Cambiar fecha y hora')), findsOneWidget);
      expect(_inSheet(find.text('Quitar fecha')), findsOneWidget);
      expect(find.byType(DatePickerDialog), findsNothing);
    });

    testWidgets('tapping a row without a date goes straight to the picker', (
      tester,
    ) async {
      await pumpOrdersView(tester);

      await _openRow(tester, 'Cierre');

      expect(find.byType(DatePickerDialog), findsOneWidget);
      expect(find.text('Quitar fecha'), findsNothing);
    });

    testWidgets('"Quitar fecha" on Apertura sends only clearOpensAt', (
      tester,
    ) async {
      final repo = FakeOrdersRepo(
          config: orderConfig(opensAt: _opens, deadline: _closes));
      await pumpOrdersView(tester, repo: repo);

      await _openRow(tester, 'Apertura');
      await _tap(tester, find.text('Quitar fecha'));

      expect(
        repo.settingsCalls.single,
        const SupervisionOrderSettingsPatch(clearOpensAt: true),
      );
      expect(find.text('Guardado'), findsOneWidget);
    });

    testWidgets('"Quitar fecha" on Cierre sends only clearDeadline', (
      tester,
    ) async {
      final repo = FakeOrdersRepo(config: orderConfig(deadline: _closes));
      await pumpOrdersView(tester, repo: repo);

      await _openRow(tester, 'Cierre');
      await _tap(tester, find.text('Quitar fecha'));

      expect(
        repo.settingsCalls.single,
        const SupervisionOrderSettingsPatch(clearDeadline: true),
      );
    });

    testWidgets('picking a new opening sends only opensAt', (tester) async {
      final repo = FakeOrdersRepo(
        config: orderConfig(opensAt: _opens, deadline: DateTime(2027, 3, 25)),
      );
      await pumpOrdersView(tester, repo: repo);

      await _openRow(tester, 'Apertura');
      await _tap(tester, find.text('Cambiar fecha y hora'));
      await _pickDay(tester, 15);

      final patch = repo.settingsCalls.single;
      // The time of the previous value is kept (wheels untouched).
      expect(patch.opensAt, DateTime(2027, 3, 15, 10, 30));
      expect(patch.deadline, isNull);
      expect(patch.ordersEnabled, isNull);
      expect(patch.clearOpensAt, isFalse);
      expect(patch.clearDeadline, isFalse);
      expect(find.text('Guardado'), findsOneWidget);
    });

    testWidgets('picking a new closing sends only deadline', (tester) async {
      final repo = FakeOrdersRepo(
        config: orderConfig(opensAt: DateTime(2027, 1, 5, 8), deadline: _opens),
      );
      await pumpOrdersView(tester, repo: repo);

      await _openRow(tester, 'Cierre');
      await _tap(tester, find.text('Cambiar fecha y hora'));
      await _pickDay(tester, 15);

      final patch = repo.settingsCalls.single;
      expect(patch.deadline, DateTime(2027, 3, 15, 10, 30));
      expect(patch.opensAt, isNull);
      expect(patch.ordersEnabled, isNull);
      expect(patch.clearOpensAt, isFalse);
      expect(patch.clearDeadline, isFalse);
    });

    testWidgets('a date set from nothing sends the picked day and time', (
      tester,
    ) async {
      final repo = FakeOrdersRepo();
      await pumpOrdersView(tester, repo: repo);

      await _openRow(tester, 'Cierre');
      await _pickDay(tester, 15);

      final patch = repo.settingsCalls.single;
      final now = DateTime.now();
      expect(patch.deadline?.day, 15);
      expect(patch.deadline?.month, now.month);
      expect(patch.deadline?.year, now.year);
      expect(patch.opensAt, isNull);
    });

    testWidgets('an opening not before the closing is rejected with a toast', (
      tester,
    ) async {
      final repo = FakeOrdersRepo(
        config: orderConfig(opensAt: _opens, deadline: _closes),
      );
      await pumpOrdersView(tester, repo: repo);

      await _openRow(tester, 'Apertura');
      await _tap(tester, find.text('Cambiar fecha y hora'));
      // 15 March is after the closing of 12 March.
      await _pickDay(tester, 15);

      expect(find.text('La apertura debe ser anterior al cierre.'),
          findsOneWidget);
      expect(repo.settingsCalls, isEmpty);
      expect(find.text('Guardado'), findsNothing);
    });

    testWidgets('an opening equal to the closing is rejected', (tester) async {
      final repo = FakeOrdersRepo(
        config: orderConfig(
          opensAt: DateTime(2027, 3, 10, 10, 30),
          deadline: DateTime(2027, 3, 15, 10, 30),
        ),
      );
      await pumpOrdersView(tester, repo: repo);

      await _openRow(tester, 'Apertura');
      await _tap(tester, find.text('Cambiar fecha y hora'));
      // 15 March at the kept time 10:30 is exactly the closing.
      await _pickDay(tester, 15);

      expect(find.text('La apertura debe ser anterior al cierre.'),
          findsOneWidget);
      expect(repo.settingsCalls, isEmpty);
    });

    testWidgets('a closing not after the opening is rejected too', (
      tester,
    ) async {
      final repo = FakeOrdersRepo(
        config:
            orderConfig(opensAt: DateTime(2027, 3, 20, 8), deadline: _closes),
      );
      await pumpOrdersView(tester, repo: repo);

      await _openRow(tester, 'Cierre');
      await _tap(tester, find.text('Cambiar fecha y hora'));
      await _pickDay(tester, 15);

      expect(find.text('La apertura debe ser anterior al cierre.'),
          findsOneWidget);
      expect(repo.settingsCalls, isEmpty);
    });

    testWidgets('cancelling the date picker sends nothing', (tester) async {
      final repo = FakeOrdersRepo();
      await pumpOrdersView(tester, repo: repo);

      await _openRow(tester, 'Apertura');
      await _tap(tester, find.text('Cancelar'));

      expect(repo.settingsCalls, isEmpty);
      expect(find.byType(DatePickerDialog), findsNothing);
    });

    testWidgets('dragging the hour wheel changes the time that is sent', (
      tester,
    ) async {
      final repo = FakeOrdersRepo(config: orderConfig(opensAt: _opens));
      await pumpOrdersView(tester, repo: repo);

      await _openRow(tester, 'Apertura');
      await _tap(tester, find.text('Cambiar fecha y hora'));
      await tester.tap(
        find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.text('15'),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Aceptar'));
      await tester.pumpAndSettle();
      // Move the hour wheel one item (44 px) forward: 10 -> 11.
      await tester.drag(
        find.byType(CupertinoPicker).first,
        const Offset(0, -44),
      );
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Listo'));

      expect(repo.settingsCalls.single.opensAt, DateTime(2027, 3, 15, 11, 30));
    });
  });

  group('orders tab: products', () {
    testWidgets('lists the group with the count of products on sale', (
      tester,
    ) async {
      await pumpOrdersView(tester, repo: _productsRepo());

      expect(find.text('PRODUCTOS EN VENTA'), findsOneWidget);
      final section = find.ancestor(
        of: find.text('PRODUCTOS EN VENTA'),
        matching: find.byType(SacGroupedSection),
      );
      // 2 on sale (Gorra, Playera) out of 4: the inactive offering and the
      // one outside the library do not count.
      expect(find.descendant(of: section, matching: find.text('2')),
          findsOneWidget);
      expect(
          find.descendant(of: section, matching: find.text('4')), findsNothing);
    });

    testWidgets('row texts follow the offering and the sizes', (tester) async {
      await pumpOrdersView(tester, repo: _productsRepo());

      expect(_inRow('Gorra', 'En venta'), findsOneWidget);
      expect(_inRow('Gorra', SacMoney.fromCentavos(12050)), findsOneWidget);
      expect(_inRow('Playera', 'En venta · tallas activas: 2'), findsOneWidget);
      expect(_inRow('Playera', SacMoney.fromCentavos(8000)), findsOneWidget);
      expect(_inRow('Termo', 'No se ofrece'), findsOneWidget);
      expect(
        _inRow('Chamarra', 'Sin tallas activas: no se puede ofrecer'),
        findsOneWidget,
      );
      // No price for what is not on sale.
      expect(
        find.descendant(
          of: _row('Termo'),
          matching: find.text(SacMoney.fromCentavos(999)),
        ),
        findsNothing,
      );
    });

    testWidgets('an empty library shows the note and no group', (tester) async {
      await pumpOrdersView(tester);

      expect(
        find.text(
          'No hay productos activos en el catálogo de tu territorio. '
          'Se administran en el panel web.',
        ),
        findsOneWidget,
      );
      expect(find.text('PRODUCTOS EN VENTA'), findsNothing);
      expect(find.text('VENTANA DE PEDIDOS'), findsOneWidget);
    });

    testWidgets('tapping a product opens its sheet with the offer switch', (
      tester,
    ) async {
      await pumpOrdersView(tester, repo: _productsRepo());

      await _openRow(tester, 'Termo');

      expect(_inSheet(find.text('Termo')), findsOneWidget);
      expect(_inSheet(find.text('Ofrecer en este camporee')), findsOneWidget);
      expect(
          tester.widget<Switch>(_inSheet(find.byType(Switch))).value, isFalse);
      // The price field only exists while the switch is on.
      expect(_inSheet(find.byType(TextFormField)), findsNothing);

      await _tap(tester, _inSheet(find.byType(Switch)));

      expect(_inSheet(find.byType(TextFormField)), findsOneWidget);
      expect(_inSheet(find.text('Precio')), findsOneWidget);
    });

    testWidgets('the sheet of a product on sale prefills the price', (
      tester,
    ) async {
      await pumpOrdersView(tester, repo: _productsRepo());

      await _openRow(tester, 'Gorra');

      expect(
          tester.widget<Switch>(_inSheet(find.byType(Switch))).value, isTrue);
      expect(
        tester
            .widget<TextFormField>(_inSheet(find.byType(TextFormField)))
            .controller!
            .text,
        '120.50',
      );
    });

    for (final price in ['', '0', '0.00', '.', ',', '9999999.99']) {
      testWidgets(
          'saving with price "$price" shows the price error and sends '
          'nothing', (tester) async {
        final repo = _productsRepo();
        await pumpOrdersView(tester, repo: repo);

        await _openRow(tester, 'Termo');
        await _tap(tester, _inSheet(find.byType(Switch)));
        await _type(tester, 0, price);
        await _saveSheet(tester);

        expect(
            _inSheet(find.text('Escribe un precio válido.')), findsOneWidget);
        expect(repo.replaceCalls, isEmpty);
        expect(_sheet, findsOneWidget);
      });
    }

    testWidgets(
        'a valid price "120.50" replaces the offerings keeping the '
        'others on sale', (tester) async {
      final repo = _productsRepo();
      repo.onReplace = (items) async {
        repo.config = orderConfig(
          products: [_gorra, _playera, _termo, _chamarra],
          offerings: [
            orderOffering(_gorra, priceCentavos: 12050),
            orderOffering(_playera, priceCentavos: 8000, sortOrder: 3),
            orderOffering(_termo, priceCentavos: 12050, sortOrder: 6),
          ],
        );
        return Right(
            CamporeeOrderOfferingsCatalog(settings: repo.config.settings));
      };
      await pumpOrdersView(tester, repo: repo);

      await _openRow(tester, 'Termo');
      await _tap(tester, _inSheet(find.byType(Switch)));
      await _type(tester, 0, '120.50');
      await _saveSheet(tester);

      expect(repo.replaceCalls, hasLength(1));
      expect(repo.replaceCalls.single, const [
        SupervisionOfferingInput(
          productId: 'p1',
          priceCentavos: 12050,
          sortOrder: 0,
        ),
        SupervisionOfferingInput(
          productId: 'p2',
          priceCentavos: 8000,
          sortOrder: 3,
        ),
        // Next sortOrder is the max over every offering the server returned
        // (5, the one outside the library) plus one.
        SupervisionOfferingInput(
          productId: 'p3',
          priceCentavos: 12050,
          sortOrder: 6,
        ),
      ]);
      expect(find.text('Guardado'), findsOneWidget);
      expect(_sheet, findsNothing);
      expect(repo.orderConfigCalls, [7, 7]);
      expect(_inRow('Termo', 'En venta'), findsOneWidget);
      expect(_inRow('Termo', SacMoney.fromCentavos(12050)), findsOneWidget);
    });

    testWidgets('a comma price "120,5" is 12050 centavos', (tester) async {
      final repo = _productsRepo();
      await pumpOrdersView(tester, repo: repo);

      await _openRow(tester, 'Termo');
      await _tap(tester, _inSheet(find.byType(Switch)));
      await _type(tester, 0, '120,5');
      await _saveSheet(tester);

      final added = repo.replaceCalls.single.singleWhere(
        (i) => i.productId == 'p3',
      );
      expect(added.priceCentavos, 12050);
    });

    testWidgets('changing the price of a product on sale keeps its sortOrder', (
      tester,
    ) async {
      final repo = _productsRepo();
      await pumpOrdersView(tester, repo: repo);

      await _openRow(tester, 'Playera');
      await _type(tester, 0, '95');
      await _saveSheet(tester);

      final updated = repo.replaceCalls.single.singleWhere(
        (i) => i.productId == 'p2',
      );
      expect(updated.priceCentavos, 9500);
      expect(updated.sortOrder, 3);
      expect(repo.replaceCalls.single.map((i) => i.productId), ['p1', 'p2']);
    });

    testWidgets('turning the switch off sends a replacement without it', (
      tester,
    ) async {
      final repo = _productsRepo();
      await pumpOrdersView(tester, repo: repo);

      await _openRow(tester, 'Gorra');
      await _tap(tester, _inSheet(find.byType(Switch)));
      expect(_inSheet(find.byType(TextFormField)), findsNothing);
      await _saveSheet(tester);

      expect(repo.replaceCalls.single.map((i) => i.productId), ['p2']);
      expect(find.text('Guardado'), findsOneWidget);
      expect(_sheet, findsNothing);
    });

    testWidgets('off to off for a product not on sale closes with no request', (
      tester,
    ) async {
      final repo = _productsRepo();
      await pumpOrdersView(tester, repo: repo);

      await _openRow(tester, 'Termo');
      await _saveSheet(tester);

      expect(_sheet, findsNothing);
      expect(repo.replaceCalls, isEmpty);
      expect(find.text('Guardado'), findsNothing);
    });

    testWidgets(
        'a product without active sizes has the switch disabled with '
        'the note', (tester) async {
      await pumpOrdersView(tester, repo: _productsRepo());

      await _openRow(tester, 'Chamarra');

      expect(tester.widget<Switch>(_inSheet(find.byType(Switch))).onChanged,
          isNull);
      expect(
        _inSheet(find.text(
          'Agrega tallas activas en el panel web para poder ofrecerlo.',
        )),
        findsOneWidget,
      );
    });

    testWidgets(
        'a product with active sizes has no note and an enabled '
        'switch', (tester) async {
      await pumpOrdersView(tester, repo: _productsRepo());

      await _openRow(tester, 'Playera');

      expect(tester.widget<Switch>(_inSheet(find.byType(Switch))).onChanged,
          isNotNull);
      expect(
        _inSheet(find.textContaining('Agrega tallas activas')),
        findsNothing,
      );
    });

    testWidgets('a sized product on sale that lost its sizes can be taken off',
        (
      tester,
    ) async {
      final lost = orderProduct(
        'p5',
        title: 'Sudadera',
        scheme: CamporeeOrderSizeScheme.letter,
        options: [sizeOption('s', active: false)],
      );
      final repo = FakeOrdersRepo(
        config: orderConfig(
          products: [lost, _gorra],
          offerings: [orderOffering(lost), orderOffering(_gorra, sortOrder: 1)],
        ),
      );
      await pumpOrdersView(tester, repo: repo);

      expect(_inRow('Sudadera', 'Sin tallas activas: no se puede ofrecer'),
          findsOneWidget);
      await _openRow(tester, 'Sudadera');
      expect(
          tester.widget<Switch>(_inSheet(find.byType(Switch))).value, isTrue);
      expect(tester.widget<Switch>(_inSheet(find.byType(Switch))).onChanged,
          isNotNull);
      await _tap(tester, _inSheet(find.byType(Switch)));
      await _saveSheet(tester);

      expect(repo.replaceCalls.single.map((i) => i.productId), ['p1']);
    });

    testWidgets('the sheet shows the product description as subtitle', (
      tester,
    ) async {
      final repo = FakeOrdersRepo(
        config: orderConfig(
          products: [orderProduct('p1', title: 'Gorra', description: 'Azul')],
        ),
      );
      await pumpOrdersView(tester, repo: repo);

      await _openRow(tester, 'Gorra');

      expect(_inSheet(find.text('Azul')), findsOneWidget);
    });

    final saveErrors = <String, (Failure, String)>{
      'offering invalid': (
        codedFailure('CAMPOREE_ORDER_OFFERING_INVALID'),
        'La oferta no es válida. Revisa el producto y el precio.',
      ),
      'option required': (
        codedFailure('CAMPOREE_ORDER_OPTION_REQUIRED'),
        'Este producto necesita al menos una talla activa.',
      ),
      'product scope invalid': (
        codedFailure('CAMPOREE_ORDER_PRODUCT_SCOPE_INVALID'),
        'Este producto está fuera del alcance de tu territorio.',
      ),
      'http 403': (kOrdersForbidden, _forbiddenText),
      'order forbidden code': (
        codedFailure('CAMPOREE_ORDER_FORBIDDEN'),
        _forbiddenText,
      ),
      'unknown code': (
        codedFailure('OTHER_CODE', 'mensaje del servidor'),
        'mensaje del servidor'
      ),
    };
    saveErrors.forEach((name, expected) {
      testWidgets(
          'a failed save ($name) shows the inline error and keeps the '
          'sheet open', (tester) async {
        final repo = _productsRepo()
          ..onReplace = (_) async => Left(expected.$1);
        await pumpOrdersView(tester, repo: repo);

        await _openRow(tester, 'Termo');
        await _tap(tester, _inSheet(find.byType(Switch)));
        await _type(tester, 0, '50');
        await _saveSheet(tester);

        expect(_inSheet(find.text(expected.$2)), findsOneWidget);
        expect(_sheet, findsOneWidget);
        expect(find.text('Guardado'), findsNothing);
        // The button works again.
        expect(tester.widget<SacButton>(_save).onPressed, isNotNull);
        expect(tester.widget<SacButton>(_save).isLoading, isFalse);
      });
    });

    testWidgets('the save button cannot fire twice while busy', (tester) async {
      final gate = Completer<void>();
      final repo = _productsRepo();
      repo.onReplace = (_) async {
        await gate.future;
        return Right(
            CamporeeOrderOfferingsCatalog(settings: repo.config.settings));
      };
      await pumpOrdersView(tester, repo: repo);

      await _openRow(tester, 'Termo');
      await _tap(tester, _inSheet(find.byType(Switch)));
      await _type(tester, 0, '50');
      await tester.tap(_save);
      await tester.pump();
      await tester.pump();

      expect(tester.widget<SacButton>(_save).isLoading, isTrue);
      expect(tester.widget<SacButton>(_save).onPressed, isNull);
      await tester.tap(_save, warnIfMissed: false);
      await tester.pump();
      expect(repo.replaceCalls, hasLength(1));

      gate.complete();
      await tester.pumpAndSettle();
      expect(repo.replaceCalls, hasLength(1));
      expect(_sheet, findsNothing);
    });

    testWidgets('the price field and switch are disabled while busy', (
      tester,
    ) async {
      final gate = Completer<void>();
      final repo = _productsRepo();
      repo.onReplace = (_) async {
        await gate.future;
        return Right(
            CamporeeOrderOfferingsCatalog(settings: repo.config.settings));
      };
      await pumpOrdersView(tester, repo: repo);

      await _openRow(tester, 'Gorra');
      await tester.tap(_save);
      await tester.pump();
      await tester.pump();

      expect(tester.widget<Switch>(_inSheet(find.byType(Switch))).onChanged,
          isNull);
      expect(
        tester.widget<TextField>(_inSheet(find.byType(TextField))).enabled,
        isFalse,
      );
      gate.complete();
      await tester.pumpAndSettle();
    });
  });

  group('supplies tab', () {
    SupervisionSupplyCatalog fullCatalog() => supplyCatalog(
          slots: [
            supplySlot('s1', label: 'Almuerzo'),
            supplySlot('s2', label: 'Cena', time: '19:15', active: false),
          ],
          products: [
            supplyProduct('i1', name: 'Arroz'),
            supplyProduct(
              'i2',
              name: 'Pan',
              uom: SupervisionSupplyUom.unit,
              centavos: 350,
              active: false,
            ),
            supplyProduct(
              'i3',
              name: 'Agua',
              uom: SupervisionSupplyUom.l,
              centavos: 1200,
            ),
            supplyProduct(
              'i4',
              name: 'Sal',
              uom: SupervisionSupplyUom.bag,
              centavos: 800,
            ),
          ],
        );

    Future<FakeOrdersRepo> pumpSupplies(
      WidgetTester tester, {
      SupervisionSupplyCatalog? catalog,
    }) async {
      final repo = FakeOrdersRepo()..catalog = catalog ?? fullCatalog();
      await pumpOrdersView(tester, repo: repo);
      await _toSupplies(tester);
      return repo;
    }

    testWidgets('the cutoff row shows the time and the camporee place', (
      tester,
    ) async {
      await pumpSupplies(tester);

      expect(find.text('EDICIÓN DE PLANES'), findsOneWidget);
      expect(_inRow('Corte de edición', '18:30'), findsOneWidget);
      expect(
        _inRow(
            'Corte de edición', 'Hora local del camporee (Ciudad de México)'),
        findsOneWidget,
      );
    });

    testWidgets('a zone with no name of its own reads as its city', (
      tester,
    ) async {
      await pumpSupplies(
        tester,
        catalog: supplyCatalog(timezone: 'America/Argentina/Buenos_Aires'),
      );

      expect(
        _inRow('Corte de edición', 'Hora local del camporee (Buenos Aires)'),
        findsOneWidget,
      );
    });

    testWidgets('a nested zone with a name of its own is translated', (
      tester,
    ) async {
      await pumpSupplies(
        tester,
        catalog: supplyCatalog(timezone: 'America/Argentina/Cordoba'),
      );

      expect(
        _inRow('Corte de edición', 'Hora local del camporee (Córdoba)'),
        findsOneWidget,
      );
    });

    testWidgets('a blank timezone hides the timezone line', (tester) async {
      await pumpSupplies(tester, catalog: supplyCatalog(timezone: ' '));

      expect(find.textContaining('Hora local del camporee'), findsNothing);
    });

    testWidgets('delivery times show label, time and "Inactivo"', (
      tester,
    ) async {
      await pumpSupplies(tester);

      expect(find.text('HORARIOS DE ENTREGA'), findsOneWidget);
      expect(find.text('Agregar'), findsNWidgets(2));
      expect(_inRow('Almuerzo', '12:00'), findsOneWidget);
      expect(_inRow('Almuerzo', 'Inactivo'), findsNothing);
      expect(_inRow('Cena', '19:15'), findsOneWidget);
      expect(_inRow('Cena', 'Inactivo'), findsOneWidget);
    });

    testWidgets('empty delivery times and products show their notes', (
      tester,
    ) async {
      await pumpSupplies(tester, catalog: supplyCatalog());

      expect(find.text('Aún no hay horarios configurados.'), findsOneWidget);
      expect(find.text('Aún no hay productos en el catálogo.'), findsOneWidget);
      expect(find.text('Agregar'), findsNWidgets(2));
    });

    testWidgets('supply products show unit, "Inactivo" and the unit price', (
      tester,
    ) async {
      await pumpSupplies(tester);

      expect(find.text('PRODUCTOS DE INSUMO'), findsOneWidget);
      expect(_inRow('Arroz', 'Por kg'), findsOneWidget);
      expect(_inRow('Arroz', SacMoney.fromCentavos(2500)), findsOneWidget);
      expect(_inRow('Pan', 'Por pieza · Inactivo'), findsOneWidget);
      expect(_inRow('Pan', SacMoney.fromCentavos(350)), findsOneWidget);
      expect(_inRow('Agua', 'Por L'), findsOneWidget);
      expect(_inRow('Sal', 'Por bolsa'), findsOneWidget);
    });

    group('cutoff', () {
      testWidgets('confirming the same time sends nothing', (tester) async {
        final repo = await pumpSupplies(tester);

        await _openRow(tester, 'Corte de edición');
        expect(find.text('Seleccionar hora'), findsOneWidget);
        await _tap(tester, find.text('Listo'));

        expect(repo.cutoffCalls, isEmpty);
        expect(find.text('Guardado'), findsNothing);
      });

      testWidgets('a changed time updates the cutoff and reloads', (
        tester,
      ) async {
        final repo = await pumpSupplies(tester);

        await _openRow(tester, 'Corte de edición');
        // 18 -> 19.
        await tester.drag(
          find.byType(CupertinoPicker).first,
          const Offset(0, -44),
        );
        await tester.pumpAndSettle();
        await _tap(tester, find.text('Listo'));

        expect(repo.cutoffCalls, ['19:30']);
        expect(find.text('Guardado'), findsOneWidget);
        expect(repo.supplyCatalogCalls, [7, 7]);
      });

      testWidgets('a failed cutoff save shows the mapped toast', (
        tester,
      ) async {
        final repo = await pumpSupplies(tester);
        repo.onCutoff =
            (_) async => Left(codedFailure('CAMPOREE_SUPPLIES_CUTOFF_INVALID'));

        await _openRow(tester, 'Corte de edición');
        await tester.drag(
          find.byType(CupertinoPicker).first,
          const Offset(0, -44),
        );
        await tester.pumpAndSettle();
        await _tap(tester, find.text('Listo'));

        expect(find.text('La hora de corte no es válida.'), findsOneWidget);
        expect(repo.supplyCatalogCalls, [7]);
      });
    });

    group('delivery time sheet', () {
      Future<void> openNew(WidgetTester tester) async {
        await _tap(tester, find.text('Agregar').first);
        expect(_inSheet(find.text('Nuevo horario')), findsOneWidget);
      }

      testWidgets('"Agregar" opens an empty sheet without the Activo switch', (
        tester,
      ) async {
        await pumpSupplies(tester);

        await openNew(tester);

        expect(
          tester
              .widget<TextFormField>(_inSheet(find.byType(TextFormField)))
              .controller!
              .text,
          isEmpty,
        );
        expect(_inSheet(find.byType(Switch)), findsNothing);
        expect(_inSheet(find.text('12:00')), findsOneWidget);
      });

      for (final name in ['', '   ']) {
        testWidgets('saving with the name "$name" shows the name error', (
          tester,
        ) async {
          final repo = await pumpSupplies(tester);

          await openNew(tester);
          await _type(tester, 0, name);
          await _saveSheet(tester);

          expect(_inSheet(find.text('Escribe un nombre para el horario.')),
              findsOneWidget);
          expect(repo.createSlotCalls, isEmpty);
          expect(_sheet, findsOneWidget);
        });
      }

      testWidgets(
          'a valid name creates the slot with the trimmed label and '
          'the default time', (tester) async {
        final repo = await pumpSupplies(tester);

        await openNew(tester);
        await _type(tester, 0, '  Desayuno  ');
        await _saveSheet(tester);

        expect(repo.createSlotCalls, hasLength(1));
        expect(repo.createSlotCalls.single.label, 'Desayuno');
        expect(repo.createSlotCalls.single.deliverTime, '12:00');
        expect(find.text('Guardado'), findsOneWidget);
        expect(_sheet, findsNothing);
        expect(repo.supplyCatalogCalls, [7, 7]);
      });

      testWidgets('the time wheel changes the delivery time that is sent', (
        tester,
      ) async {
        final repo = await pumpSupplies(tester);

        await openNew(tester);
        await _type(tester, 0, 'Desayuno');
        await _tap(tester, _inSheet(find.text('12:00')));
        await tester.drag(
          find.byType(CupertinoPicker).first,
          const Offset(0, -44),
        );
        await tester.pumpAndSettle();
        await _tap(tester, find.text('Listo'));
        expect(_inSheet(find.text('13:00')), findsOneWidget);
        await _saveSheet(tester);

        expect(repo.createSlotCalls.single.deliverTime, '13:00');
      });

      testWidgets('tapping a slot opens "Editar horario" prefilled', (
        tester,
      ) async {
        await pumpSupplies(tester);

        await _openRow(tester, 'Almuerzo');

        expect(_inSheet(find.text('Editar horario')), findsOneWidget);
        expect(
          tester
              .widget<TextFormField>(_inSheet(find.byType(TextFormField)))
              .controller!
              .text,
          'Almuerzo',
        );
        expect(_inSheet(find.text('Activo')), findsOneWidget);
        expect(
            tester.widget<Switch>(_inSheet(find.byType(Switch))).value, isTrue);
      });

      testWidgets('an inactive slot opens with the switch off', (tester) async {
        await pumpSupplies(tester);

        await _openRow(tester, 'Cena');

        expect(tester.widget<Switch>(_inSheet(find.byType(Switch))).value,
            isFalse);
      });

      testWidgets('saving an edit sends the slot id and the changed values', (
        tester,
      ) async {
        final repo = await pumpSupplies(tester);

        await _openRow(tester, 'Almuerzo');
        await _type(tester, 0, 'Almuerzo tardío');
        await _tap(tester, _inSheet(find.byType(Switch)));
        await _saveSheet(tester);

        expect(repo.createSlotCalls, isEmpty);
        final call = repo.updateSlotCalls.single;
        expect(call.slotId, 's1');
        expect(call.label, 'Almuerzo tardío');
        expect(call.deliverTime, '12:00');
        expect(call.active, isFalse);
        expect(find.text('Guardado'), findsOneWidget);
        expect(_sheet, findsNothing);
      });

      testWidgets('a failed slot save shows the inline error', (tester) async {
        final repo = await pumpSupplies(tester);
        repo.onSlot = (_) async => Left(codedFailure('X', 'horario repetido'));

        await _openRow(tester, 'Almuerzo');
        await _saveSheet(tester);

        expect(_inSheet(find.text('horario repetido')), findsOneWidget);
        expect(_sheet, findsOneWidget);
      });

      testWidgets('CAMPOREE_SUPPLIES_FORBIDDEN shows the forbidden text', (
        tester,
      ) async {
        final repo = await pumpSupplies(tester);
        repo.onSlot =
            (_) async => Left(codedFailure('CAMPOREE_SUPPLIES_FORBIDDEN'));

        await _openRow(tester, 'Almuerzo');
        await _saveSheet(tester);

        expect(_inSheet(find.text(_forbiddenText)), findsOneWidget);
      });
    });

    group('supply product sheet', () {
      Future<void> openNew(WidgetTester tester) async {
        await _tap(tester, find.text('Agregar').last);
        expect(_inSheet(find.text('Nuevo producto')), findsOneWidget);
      }

      testWidgets('saving with an empty name shows the name error', (
        tester,
      ) async {
        final repo = await pumpSupplies(tester);

        await openNew(tester);
        await _type(tester, 1, '10');
        await _saveSheet(tester);

        expect(_inSheet(find.text('Escribe el nombre del producto.')),
            findsOneWidget);
        expect(repo.createProductCalls, isEmpty);
      });

      for (final price in ['', '.', ',']) {
        testWidgets('saving with price "$price" shows the price error', (
          tester,
        ) async {
          final repo = await pumpSupplies(tester);

          await openNew(tester);
          await _type(tester, 0, 'Frijol');
          await _type(tester, 1, price);
          await _saveSheet(tester);

          expect(
              _inSheet(find.text('Escribe un precio válido.')), findsOneWidget);
          expect(repo.createProductCalls, isEmpty);
        });
      }

      testWidgets('a price over the limit is invalid', (tester) async {
        final repo = await pumpSupplies(tester);

        await openNew(tester);
        await _type(tester, 0, 'Frijol');
        await _type(tester, 1, '9999999.99');
        await _saveSheet(tester);

        expect(
            _inSheet(find.text('Escribe un precio válido.')), findsOneWidget);
        expect(repo.createProductCalls, isEmpty);
      });

      testWidgets('valid input creates the product with the default unit', (
        tester,
      ) async {
        final repo = await pumpSupplies(tester);

        await openNew(tester);
        await _type(tester, 0, '  Frijol ');
        await _type(tester, 1, '25.5');
        await _saveSheet(tester);

        final call = repo.createProductCalls.single;
        expect(call.name, 'Frijol');
        expect(call.uom, SupervisionSupplyUom.unit);
        expect(call.unitCostCentavos, 2550);
        expect(find.text('Guardado'), findsOneWidget);
        expect(_sheet, findsNothing);
        expect(repo.supplyCatalogCalls, [7, 7]);
      });

      testWidgets('the chosen unit is the one sent', (tester) async {
        final repo = await pumpSupplies(tester);

        await openNew(tester);
        await _type(tester, 0, 'Frijol');
        await _type(tester, 1, '10');
        await _tap(tester, _inSheet(find.text('pieza')));
        await _tap(tester, find.text('kg').last);
        await _saveSheet(tester);

        expect(repo.createProductCalls.single.uom, SupervisionSupplyUom.kg);
      });

      testWidgets('the sheet of a new product has no Activo switch', (
        tester,
      ) async {
        await pumpSupplies(tester);

        await openNew(tester);

        expect(_inSheet(find.byType(Switch)), findsNothing);
      });

      testWidgets('editing with an unchanged price does not send the price', (
        tester,
      ) async {
        final repo = await pumpSupplies(tester);

        await _openRow(tester, 'Arroz');
        expect(
          tester
              .widget<TextFormField>(_inSheet(find.byType(TextFormField)).last)
              .controller!
              .text,
          '25',
        );
        await _type(tester, 0, 'Arroz integral');
        await _saveSheet(tester);

        final call = repo.updateProductCalls.single;
        expect(call.productId, 'i1');
        expect(call.name, 'Arroz integral');
        expect(call.uom, SupervisionSupplyUom.kg);
        expect(call.unitCostCentavos, isNull);
        expect(call.active, isTrue);
        expect(repo.createProductCalls, isEmpty);
      });

      testWidgets('the same price typed differently is still unchanged', (
        tester,
      ) async {
        final repo = await pumpSupplies(tester);

        await _openRow(tester, 'Arroz');
        await _type(tester, 1, '25.00');
        await _saveSheet(tester);

        expect(repo.updateProductCalls.single.unitCostCentavos, isNull);
      });

      testWidgets('editing with a changed price sends it', (tester) async {
        final repo = await pumpSupplies(tester);

        await _openRow(tester, 'Arroz');
        await _type(tester, 1, '30');
        await _tap(tester, _inSheet(find.byType(Switch)));
        await _saveSheet(tester);

        final call = repo.updateProductCalls.single;
        expect(call.unitCostCentavos, 3000);
        expect(call.active, isFalse);
      });

      testWidgets('a product with an unknown unit asks to choose one', (
        tester,
      ) async {
        final repo = await pumpSupplies(
          tester,
          catalog: supplyCatalog(
            products: [
              supplyProduct('i9',
                  name: 'Raro', uom: SupervisionSupplyUom.unknown),
            ],
          ),
        );

        await _openRow(tester, 'Raro');
        await _saveSheet(tester);

        expect(_inSheet(find.text('Elige una unidad.')), findsOneWidget);
        expect(repo.updateProductCalls, isEmpty);
      });

      testWidgets('CAMPOREE_SUPPLIES_PRICE_LOCKED shows the inline message', (
        tester,
      ) async {
        final repo = await pumpSupplies(tester);
        repo.onSupplyProduct =
            (_) async => Left(codedFailure('CAMPOREE_SUPPLIES_PRICE_LOCKED'));

        await _openRow(tester, 'Arroz');
        await _type(tester, 1, '30');
        await _saveSheet(tester);

        expect(
          _inSheet(find.text(
            'El precio ya no se puede cambiar: hay un plan enviado.',
          )),
          findsOneWidget,
        );
        expect(_sheet, findsOneWidget);
        expect(find.text('Guardado'), findsNothing);
      });

      testWidgets('CAMPOREE_SUPPLIES_FORBIDDEN shows the forbidden text', (
        tester,
      ) async {
        final repo = await pumpSupplies(tester);
        repo.onSupplyProduct =
            (_) async => Left(codedFailure('CAMPOREE_SUPPLIES_FORBIDDEN'));

        await _openRow(tester, 'Arroz');
        await _saveSheet(tester);

        expect(_inSheet(find.text(_forbiddenText)), findsOneWidget);
      });

      testWidgets('the save button cannot fire twice while busy', (
        tester,
      ) async {
        final gate = Completer<void>();
        final repo = await pumpSupplies(tester);
        repo.onSupplyProduct = (_) async {
          await gate.future;
          return Right(supplyProduct('i1'));
        };

        await _openRow(tester, 'Arroz');
        await tester.tap(_save);
        await tester.pump();
        await tester.pump();
        await tester.tap(_save, warnIfMissed: false);
        await tester.pump();

        expect(repo.updateProductCalls, hasLength(1));
        gate.complete();
        await tester.pumpAndSettle();
        expect(repo.updateProductCalls, hasLength(1));
      });
    });
  });

  group('layout at 320x640 with text scale 2.0', () {
    const small = Size(320, 640);
    final long = 'Nombre muy largo de producto para probar el desborde '
            'en pantallas pequeñas'
        .substring(0, 70);

    FakeOrdersRepo longOrders() {
      final a = orderProduct(
        'a',
        title: long,
        description: long,
        scheme: CamporeeOrderSizeScheme.letter,
        options: [sizeOption('s')],
      );
      final b = orderProduct('b', title: '$long B');
      return FakeOrdersRepo(
        config: orderConfig(
          ordersEnabled: true,
          opensAt: _opens,
          deadline: _closes,
          products: [a, b],
          offerings: [orderOffering(a, priceCentavos: 12345678)],
        ),
      );
    }

    Future<FakeOrdersRepo> pumpLongOrders(WidgetTester tester) =>
        pumpOrdersView(
          tester,
          repo: longOrders(),
          size: small,
          textScale: 2.0,
        );

    FakeOrdersRepo longSupplies() => FakeOrdersRepo()
      ..catalog = supplyCatalog(
        timezone: 'America/Argentina/ComodRivadavia',
        slots: [supplySlot('s1', label: long, active: false)],
        products: [
          supplyProduct('i1', name: long, active: false, centavos: 123456789),
        ],
      );

    Future<void> pumpLongSupplies(WidgetTester tester) async {
      await pumpOrdersView(
        tester,
        repo: longSupplies(),
        size: small,
        textScale: 2.0,
      );
      await _toSupplies(tester);
    }

    testWidgets('orders tab has no overflow', (tester) async {
      await pumpLongOrders(tester);
      expectNoLayoutException(tester);
      await _scrollTo(tester, _row('$long B'));
      expectNoLayoutException(tester);
    });

    testWidgets('orders tab without dates and empty library has no overflow', (
      tester,
    ) async {
      await pumpOrdersView(tester, size: small, textScale: 2.0);
      expectNoLayoutException(tester);
    });

    testWidgets('supplies tab has no overflow', (tester) async {
      await pumpLongSupplies(tester);
      expectNoLayoutException(tester);
      await _scrollTo(tester, find.text('PRODUCTOS DE INSUMO'));
      expectNoLayoutException(tester);
    });

    testWidgets('error state has no overflow', (tester) async {
      final repo = FakeOrdersRepo()
        ..onOrderConfig = (_) async => const Left(kOrdersBoom);
      await pumpOrdersView(tester, repo: repo, size: small, textScale: 2.0);
      expectNoLayoutException(tester);
    });

    testWidgets('the moment actions sheet has no overflow', (tester) async {
      await pumpLongOrders(tester);

      await _scrollTo(tester, _row('Apertura'));
      await _openRow(tester, 'Apertura');

      expect(_inSheet(find.text('Quitar fecha')), findsOneWidget);
      expectNoLayoutException(tester);
    });

    testWidgets('the offering sheet with the price field has no overflow', (
      tester,
    ) async {
      await pumpLongOrders(tester);

      await _scrollTo(tester, _row(long));
      await _openRow(tester, long);

      expect(_inSheet(find.byType(TextFormField)), findsOneWidget);
      expectNoLayoutException(tester);
    });

    testWidgets('the offering sheet with an inline error has no overflow', (
      tester,
    ) async {
      final repo = longOrders()
        ..onReplace = (_) async => Left(
              codedFailure('CAMPOREE_ORDER_OFFERING_INVALID'),
            );
      await pumpOrdersView(tester, repo: repo, size: small, textScale: 2.0);

      await _scrollTo(tester, _row(long));
      await _openRow(tester, long);
      await _saveSheet(tester);

      expect(
        _inSheet(find
            .text('La oferta no es válida. Revisa el producto y el precio.')),
        findsOneWidget,
      );
      expectNoLayoutException(tester);
    });

    testWidgets(
        'the offering sheet of a product not on sale and without '
        'sizes has no overflow', (tester) async {
      final repo = FakeOrdersRepo(
        config: orderConfig(
          products: [
            orderProduct(
              'c',
              title: long,
              scheme: CamporeeOrderSizeScheme.letter,
            ),
          ],
        ),
      );
      await pumpOrdersView(tester, repo: repo, size: small, textScale: 2.0);

      await _scrollTo(tester, _row(long));
      await _openRow(tester, long);

      expect(
        _inSheet(find.textContaining('Agrega tallas activas')),
        findsOneWidget,
      );
      expectNoLayoutException(tester);
    });

    testWidgets('the offering sheet with the keyboard up has no overflow', (
      tester,
    ) async {
      await pumpLongOrders(tester);

      await _scrollTo(tester, _row(long));
      await _openRow(tester, long);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      expectNoLayoutException(tester);
      // The price field is still reachable.
      await tester.ensureVisible(_inSheet(find.byType(TextFormField)));
      await tester.pumpAndSettle();
      expectNoLayoutException(tester);
    });

    testWidgets('the slot sheet has no overflow', (tester) async {
      await pumpLongSupplies(tester);

      await _scrollTo(tester, _row(long).first);
      await _tap(tester, _row(long).first);

      expect(_inSheet(find.text('Editar horario')), findsOneWidget);
      expectNoLayoutException(tester);
    });

    testWidgets('the new slot sheet with an error has no overflow', (
      tester,
    ) async {
      await pumpLongSupplies(tester);

      await _scrollTo(tester, find.text('Agregar').first);
      await _tap(tester, find.text('Agregar').first);
      await _saveSheet(tester);

      expect(_inSheet(find.text('Escribe un nombre para el horario.')),
          findsOneWidget);
      expectNoLayoutException(tester);
    });

    testWidgets('the supply product sheet has no overflow', (tester) async {
      await pumpLongSupplies(tester);

      await _scrollTo(tester, _row(long).last);
      await _tap(tester, _row(long).last);

      expect(_inSheet(find.text('Editar producto')), findsOneWidget);
      expectNoLayoutException(tester);
    });

    testWidgets(
        'the supply product sheet with the keyboard up has no '
        'overflow', (tester) async {
      await pumpLongSupplies(tester);

      await _scrollTo(tester, find.text('Agregar').last);
      await _tap(tester, find.text('Agregar').last);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      expectNoLayoutException(tester);
    });

    testWidgets('the time picker sheet has no overflow', (tester) async {
      await pumpLongSupplies(tester);

      await _scrollTo(tester, _row('Corte de edición'));
      await _openRow(tester, 'Corte de edición');

      expect(find.text('Seleccionar hora'), findsOneWidget);
      expectNoLayoutException(tester);
    });
  });
}
