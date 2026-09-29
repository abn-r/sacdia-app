import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/features/members/presentation/widgets/members_mode_switcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, dynamic> translations;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    translations = jsonDecode(
      await File('assets/translations/es.json').readAsString(),
    ) as Map<String, dynamic>;
  });

  Future<void> pumpSwitcher(
    WidgetTester tester, {
    required int index,
    required ValueChanged<int> onChanged,
    bool showContinuations = true,
    int pendingRequests = 0,
    int pendingContinuations = 0,
  }) async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('es')],
        path: 'assets/translations',
        fallbackLocale: const Locale('es'),
        assetLoader: _TestAssetLoader(translations),
        child: Builder(
          builder: (context) => MaterialApp(
            locale: context.locale,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            home: Scaffold(
              body: MembersModeSwitcher(
                index: index,
                onChanged: onChanged,
                showContinuations: showContinuations,
                pendingRequests: pendingRequests,
                pendingContinuations: pendingContinuations,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(SacMotion.switcher);
  }

  group('MembersModeSwitcher', () {
    testWidgets('should show three labels when continuations are enabled',
        (tester) async {
      await pumpSwitcher(tester, index: 0, onChanged: (_) {});

      expect(find.text('Miembros'), findsWidgets);
      expect(find.text('Solicitudes'), findsWidgets);
      expect(find.text('No inscritos'), findsWidgets);
    });

    testWidgets('should call onChanged(2) when No inscritos is tapped',
        (tester) async {
      var selected = 0;
      await pumpSwitcher(
        tester,
        index: 0,
        onChanged: (next) => selected = next,
      );

      await tester.tap(find.text('No inscritos').first);
      await tester.pump();

      expect(selected, 2);
    });

    testWidgets('should show continuations badge when count is greater than 0',
        (tester) async {
      await pumpSwitcher(
        tester,
        index: 0,
        onChanged: (_) {},
        pendingContinuations: 4,
      );

      expect(find.text('4'), findsWidgets);
    });
  });
}

class _TestAssetLoader extends AssetLoader {
  const _TestAssetLoader(this.translations);

  final Map<String, dynamic> translations;

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    return translations;
  }
}
