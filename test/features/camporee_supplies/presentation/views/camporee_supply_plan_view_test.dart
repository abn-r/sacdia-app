import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_text_field.dart';
import 'package:sacdia_app/features/camporee_orders/domain/entities/camporee_order.dart';
import 'package:sacdia_app/features/camporee_supplies/domain/entities/camporee_supply_plan.dart';
import 'package:sacdia_app/features/camporee_supplies/presentation/providers/camporee_supplies_providers.dart';
import 'package:sacdia_app/features/camporee_supplies/presentation/views/camporee_supply_plan_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    await initializeDateFormatting('es');
  });

  group('CamporeeSupplyPlanView', () {
    testWidgets('should show the payment order before day groups',
        (tester) async {
      await _pumpPlan(tester);

      expect(find.text('Corte para el día siguiente: 21:00'), findsOneWidget);
      expect(find.byKey(const Key('camporee-supply-payment')), findsOneWidget);
      expect(find.text('Orden de pago'), findsOneWidget);
      expect(find.text('Estimado'), findsOneWidget);
      expect(find.text('Día 1'), findsOneWidget);
      expect(find.text('Día 2'), findsOneWidget);

      final payment = tester.getTopLeft(
        find.byKey(const Key('camporee-supply-payment')),
      );
      final add = tester.getTopLeft(
        find.byKey(const Key('camporee-supply-add')),
      );
      final dayOne = tester.getTopLeft(
        find.byKey(const Key('camporee-supply-day-2026-08-21')),
      );
      expect(payment.dy, lessThan(add.dy));
      expect(add.dy, lessThan(dayOne.dy));
    });

    testWidgets('should keep the add form out of the main list',
        (tester) async {
      await _pumpPlan(tester);

      expect(find.byType(SacTextField), findsNothing);
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      expect(find.text('Día'), findsNothing);
      expect(find.byKey(const Key('camporee-supply-add')), findsOneWidget);
      expect(find.text('Agregar insumo'), findsOneWidget);
      expect(find.text('Elige día, horario y producto'), findsOneWidget);
      expect(find.byKey(const Key('camporee-supply-add-nav')), findsNothing);
      expect(find.widgetWithText(SacButton, 'Agregar insumo'), findsNothing);
    });

    testWidgets('should add a line from the sheet into the morning group',
        (tester) async {
      await _pumpPlan(tester);

      expect(find.text('Aún no hay líneas en el plan'), findsOneWidget);
      expect(find.text('Sin insumos este día'), findsNWidgets(2));

      await tester.ensureVisible(find.byKey(const Key('camporee-supply-add')));
      await tester.tap(find.byKey(const Key('camporee-supply-add')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byType(SacTextField), findsNWidgets(4));
      expect(find.text('Horario'), findsOneWidget);
      expect(find.text('Producto'), findsOneWidget);
      expect(find.text('Cantidad'), findsOneWidget);

      await tester.tap(find.byKey(const Key('camporee-supply-add-confirm')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Aún no hay líneas en el plan'), findsNothing);
      expect(find.text('Bolsa de hielo'), findsWidgets);
      expect(
        find.byKey(const Key('camporee-supply-slot-2026-08-21-slot-am')),
        findsOneWidget,
      );
    });

    testWidgets('should group existing lines by day then delivery slot',
        (tester) async {
      await _pumpPlan(tester, envelope: _groupedEnvelope);

      expect(find.text('Bolsa de hielo'), findsOneWidget);
      expect(find.text('Garrafón de agua'), findsWidgets);
      expect(find.text('Leche'), findsOneWidget);

      final morning = tester.getTopLeft(
        find.byKey(const Key('camporee-supply-slot-2026-08-21-slot-am')),
      );
      final night = tester.getTopLeft(
        find.byKey(const Key('camporee-supply-slot-2026-08-21-slot-pm')),
      );
      final ice = tester.getTopLeft(find.text('Bolsa de hielo'));
      final milk = tester.getTopLeft(find.text('Leche'));
      expect(morning.dy, lessThan(night.dy));
      expect(ice.dy, lessThan(milk.dy));
      expect(ice.dy, greaterThan(morning.dy));
      expect(milk.dy, greaterThan(night.dy));
      expect(
        find.byKey(
          const Key('camporee-supply-icon-2026-08-21-slot-am-prod-ice'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const Key('camporee-supply-icon-2026-08-21-slot-pm-prod-milk'),
        ),
        findsOneWidget,
      );
      expect(
        tester.getSize(find.text('Bolsa de hielo')).height,
        lessThan(24),
      );
    });

    testWidgets('should open a sheet with human-readable days', (tester) async {
      await _pumpPlan(tester);

      await tester.ensureVisible(find.byKey(const Key('camporee-supply-add')));
      await tester.tap(find.byKey(const Key('camporee-supply-add')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      await tester.tap(find.byKey(const Key('camporee-supply-field-date')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byKey(const Key('camporee-supply-option-2026-08-21')),
          findsOneWidget);
      expect(find.text('2026-08-21'), findsNothing);
    });
  });
}

Future<void> _pumpPlan(
  WidgetTester tester, {
  CamporeeSupplyPlanEnvelope envelope = _envelope,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        camporeeSupplyPlanProvider.overrideWith((ref, scope) async => envelope),
      ],
      child: EasyLocalization(
        supportedLocales: const [Locale('es')],
        path: 'assets/translations',
        assetLoader: const _FileAssetLoader(),
        fallbackLocale: const Locale('es'),
        startLocale: const Locale('es'),
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.lightTheme,
            locale: context.locale,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            home: const CamporeeSupplyPlanView(camporeeId: 41),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

const _catalog = CamporeeSupplyCatalog(
  cutoff: '21:00',
  timezone: 'America/Mexico_City',
  startDate: '2026-08-21',
  endDate: '2026-08-22',
  slots: [
    CamporeeSupplySlot(
      slotId: 'slot-am',
      label: 'Entrega insumos mañana',
      deliverTime: '07:00',
      sortOrder: 1,
    ),
    CamporeeSupplySlot(
      slotId: 'slot-pm',
      label: 'Entrega insumos noche',
      deliverTime: '19:00',
      sortOrder: 3,
    ),
  ],
  products: [
    CamporeeSupplyProduct(
      productId: 'prod-ice',
      name: 'Bolsa de hielo',
      uom: 'BAG',
      unitCostCentavos: 4500,
    ),
    CamporeeSupplyProduct(
      productId: 'prod-water',
      name: 'Garrafón de agua',
      uom: 'UNIT',
      unitCostCentavos: 2800,
    ),
    CamporeeSupplyProduct(
      productId: 'prod-milk',
      name: 'Leche',
      uom: 'L',
      unitCostCentavos: 2200,
    ),
  ],
);

const _envelope = CamporeeSupplyPlanEnvelope(
  camporeeId: 41,
  camporeeType: CamporeeKind.local,
  catalog: _catalog,
);

final _groupedEnvelope = CamporeeSupplyPlanEnvelope(
  camporeeId: 41,
  camporeeType: CamporeeKind.local,
  catalog: _catalog,
  plan: CamporeeSupplyPlan(
    planId: 'plan-1',
    status: 'DRAFT',
    committedTotalCentavos: 0,
    netCentavos: 0,
    cutoff: '21:00',
    timezone: 'America/Mexico_City',
    lines: const [
      CamporeeSupplyLine(
        lineId: 'l-ice',
        date: '2026-08-21',
        slotId: 'slot-am',
        slotLabel: 'Entrega insumos mañana',
        deliverTime: '07:00',
        productId: 'prod-ice',
        productName: 'Bolsa de hielo',
        uom: 'BAG',
        qty: '2',
        deliveredQty: '0',
        unitCostCentavos: 4500,
        lineTotalCentavos: 9000,
      ),
      CamporeeSupplyLine(
        lineId: 'l-water',
        date: '2026-08-21',
        slotId: 'slot-am',
        slotLabel: 'Entrega insumos mañana',
        deliverTime: '07:00',
        productId: 'prod-water',
        productName: 'Garrafón de agua',
        uom: 'UNIT',
        qty: '6',
        deliveredQty: '0',
        unitCostCentavos: 2800,
        lineTotalCentavos: 16800,
      ),
      CamporeeSupplyLine(
        lineId: 'l-milk',
        date: '2026-08-21',
        slotId: 'slot-pm',
        slotLabel: 'Entrega insumos noche',
        deliverTime: '19:00',
        productId: 'prod-milk',
        productName: 'Leche',
        uom: 'L',
        qty: '2',
        deliveredQty: '0',
        unitCostCentavos: 2200,
        lineTotalCentavos: 4400,
      ),
      CamporeeSupplyLine(
        lineId: 'l-water-2',
        date: '2026-08-22',
        slotId: 'slot-am',
        slotLabel: 'Entrega insumos mañana',
        deliverTime: '07:00',
        productId: 'prod-water',
        productName: 'Garrafón de agua',
        uom: 'UNIT',
        qty: '4',
        deliveredQty: '0',
        unitCostCentavos: 2800,
        lineTotalCentavos: 11200,
      ),
    ],
    payments: const [],
  ),
);

class _FileAssetLoader extends AssetLoader {
  const _FileAssetLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async {
    final file = File('$path/${locale.toLanguageTag()}.json');
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }
}
