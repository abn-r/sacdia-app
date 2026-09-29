import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/sac_filter_chip.dart';
import 'package:sacdia_app/features/materials/domain/entities/material_program.dart';
import 'package:sacdia_app/features/materials/presentation/widgets/materials_program_field.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Future<void> pumpField(
    WidgetTester tester, {
    int? selectedId,
    required ValueChanged<int?> onSelected,
  }) async {
    await tester.pumpWidget(
      EasyLocalization(
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
            home: Scaffold(
              body: MaterialsProgramField(
                programs: const [
                  MaterialProgram(id: 1, label: 'Aventureros'),
                  MaterialProgram(id: 2, label: 'Conquistadores'),
                ],
                selectedId: selectedId,
                onSelected: onSelected,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  group('MaterialsProgramField', () {
    testWidgets('should name the club axis and list clubs as chips',
        (tester) async {
      await pumpField(tester, onSelected: (_) {});

      expect(find.text('Para qué club'), findsOneWidget);
      expect(find.text('Todos los clubes'), findsOneWidget);
      expect(find.text('Aventureros'), findsOneWidget);
      expect(find.text('Programa'), findsNothing);
      expect(find.byType(SacFilterChip), findsNWidgets(3));
    });

    testWidgets('should tint club chips with type color and logo',
        (tester) async {
      await pumpField(tester, selectedId: 1, onSelected: (_) {});

      expect(find.byType(Image), findsNWidgets(2));

      final aventureros = find.ancestor(
        of: find.text('Aventureros'),
        matching: find.byType(SacFilterChip),
      );
      final box = tester.widget<AnimatedContainer>(
        find.descendant(
          of: aventureros,
          matching: find.byType(AnimatedContainer),
        ),
      );
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFFE0F0FA));
      expect((decoration.border as Border).top.color, const Color(0xFF1A6B9C));
    });

    testWidgets('should call onSelected when a club chip is tapped',
        (tester) async {
      int? selected;
      await pumpField(tester, onSelected: (id) => selected = id);

      await tester.tap(find.text('Aventureros'));
      await tester.pump();

      expect(selected, 1);
    });
  });
}

class _FileAssetLoader extends AssetLoader {
  const _FileAssetLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async {
    final file = File('$path/${locale.toLanguageTag()}.json');
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }
}
