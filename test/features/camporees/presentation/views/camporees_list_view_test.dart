import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee.dart';
import 'package:sacdia_app/features/camporees/presentation/providers/camporees_providers.dart';
import 'package:sacdia_app/features/camporees/presentation/views/camporees_list_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../support/riverpod_test_support.dart';

final _today = DateUtils.dateOnly(DateTime.now());

Camporee _camporee({
  required int id,
  required int startIn,
  required int endIn,
  double? cost,
  bool adventurers = false,
  String? localField = 'Asociación Centro de Veracruz',
}) {
  return Camporee(
    camporeeId: id,
    name: 'Camporee $id',
    startDate: _today.add(Duration(days: startIn)),
    endDate: _today.add(Duration(days: endIn)),
    place: 'Campo QA',
    registrationCost: cost,
    includesAdventurers: adventurers,
    includesPathfinders: true,
    includesMasterGuides: false,
    active: true,
    localFieldName: localField,
  );
}

final _camporees = [
  _camporee(id: 1, startIn: 96, endIn: 98, cost: 150),
  _camporee(id: 2, startIn: -1, endIn: 2, cost: 0, adventurers: true),
  _camporee(id: 3, startIn: -5, endIn: 0),
  _camporee(id: 4, startIn: -70, endIn: -68, localField: null),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  String statusOf(WidgetTester tester, int id) => tester
      .widget<SacBadge>(find.byKey(ValueKey('camporee-status-$id')))
      .label;

  testWidgets('each open camporee says where it stands', (tester) async {
    await _pump(tester, const CamporeesListView());

    expect(statusOf(tester, 1), 'En 96 días');
    expect(statusOf(tester, 2), 'En curso · día 2 de 4');
    expect(statusOf(tester, 3), 'Termina hoy');
    // Past camporees stay in the history only.
    expect(find.byKey(const ValueKey('camporee-card-4')), findsNothing);

    expect(find.text('Gratuito'), findsOneWidget);
    expect(find.text(r'$150.00'), findsOneWidget);
    // Club types show as logos; screen readers get their names.
    expect(find.bySemanticsLabel(RegExp('Aventureros')), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(4));
  });

  testWidgets('the history says how long ago it ended, without cost',
      (tester) async {
    await _pump(tester, const CamporeesHistoryView());

    expect(statusOf(tester, 4), 'Terminó hace 2 meses');
    expect(find.byKey(const ValueKey('camporee-card-1')), findsNothing);
    expect(find.byKey(const ValueKey('camporee-cost-4')), findsNothing);
    expect(find.text('Campo QA'), findsOneWidget);
  });
}

Future<void> _pump(WidgetTester tester, Widget home) async {
  await tester.pumpWidget(
    testProviderScope(
      overrides: [
        camporeesProvider.overrideWith((ref) async => _camporees),
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
            home: home,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.pumpAndSettle();
}

class _FileAssetLoader extends AssetLoader {
  const _FileAssetLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async {
    final file = File('$path/${locale.toLanguageTag()}.json');
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }
}
