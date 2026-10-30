import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/features/materials/domain/entities/material_delivery.dart';
import 'package:sacdia_app/features/materials/domain/entities/material_status.dart';
import 'package:sacdia_app/features/materials/domain/entities/order.dart';
import 'package:sacdia_app/features/materials/presentation/providers/history_provider.dart';
import 'package:sacdia_app/features/materials/presentation/views/order_history_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../support/riverpod_test_support.dart';

class _FileAssetLoader extends AssetLoader {
  const _FileAssetLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async {
    final file = File('$path/${locale.toLanguageTag()}.json');
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }
}

Order _order() => Order(
      id: 'order-1',
      folioReferencia: 'SOL20260003',
      status: MaterialStatus.enRevision,
      clubSectionId: 5,
      createdBy: 'user-1',
      subtotalCentavos: 7000,
      envioCentavos: 0,
      totalCentavos: 7000,
      delivery: MaterialDelivery.recoger,
      createdAt: DateTime(2026, 1, 1),
      lines: const [],
      receipts: const [],
    );

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Future<void> pumpHistory(
      WidgetTester tester, List<Order> orders, void Function() onFetch) async {
    await tester.pumpWidget(
      testProviderScope(
        overrides: [
          historyProvider.overrideWith((ref) async {
            onFetch();
            return orders;
          }),
        ],
        child: EasyLocalization(
          supportedLocales: const [Locale('es')],
          path: 'assets/translations',
          assetLoader: const _FileAssetLoader(),
          fallbackLocale: const Locale('es'),
          startLocale: const Locale('es'),
          child: Builder(
            builder: (context) => MaterialApp(
              // iOS physics: a short list cannot overscroll unless it is
              // explicitly always-scrollable.
              theme: AppTheme.lightTheme.copyWith(platform: TargetPlatform.iOS),
              locale: context.locale,
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              home: const OrderHistoryView(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('pull-to-refresh refetches the history even with a short list',
      (tester) async {
    var fetches = 0;
    await pumpHistory(tester, [_order()], () => fetches++);

    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(find.text('SOL20260003'), findsOneWidget);
    expect(fetches, 1);

    await tester.fling(find.text('SOL20260003'), const Offset(0, 400), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(fetches, 2);
  });

  testWidgets('pull-to-refresh also works on the empty state', (tester) async {
    var fetches = 0;
    await pumpHistory(tester, const [], () => fetches++);

    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(find.text('No hay pedidos'), findsOneWidget);

    await tester.fling(find.text('No hay pedidos'), const Offset(0, 400), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(fetches, 2);
  });
}
