import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';

void main() {
  group('SacTopBar', () {
    testWidgets('should include TabBar height in preferredSize',
        (tester) async {
      const tabs = TabBar(
        tabs: [
          Tab(text: 'Local'),
          Tab(text: 'Unión'),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: DefaultTabController(
            length: 2,
            child: Scaffold(
              appBar: const SacTopBar(
                title: 'Aprobaciones',
                automaticallyImplyLeading: false,
                bottom: tabs,
              ),
            ),
          ),
        ),
      );

      final bar = tester.widget<SacTopBar>(find.byType(SacTopBar));
      expect(
        bar.preferredSize.height,
        SacTopBar.compactHeight + tabs.preferredSize.height,
      );
      expect(find.text('Local'), findsOneWidget);
      expect(find.text('Unión'), findsOneWidget);
    });

    testWidgets('frosted bar keeps dark status icons on a light surface',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            extendBodyBehindAppBar: true,
            appBar: SacTopBar(title: 'Credencial', frosted: true),
            body: SizedBox.shrink(),
          ),
        ),
      );

      final style =
          tester.widget<AppBar>(find.byType(AppBar)).systemOverlayStyle;
      expect(style?.statusBarIconBrightness, Brightness.dark);
      expect(style?.statusBarBrightness, Brightness.light);
    });

    testWidgets('frosted scroll inset is not doubled by SafeArea',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            extendBodyBehindAppBar: true,
            appBar: const SacTopBar(title: 'Notificaciones', frosted: true),
            body: SacFrostedVeil(
              child: Builder(
                builder: (context) => SafeArea(
                  top: false,
                  child: ListView(
                    padding: EdgeInsets.only(
                      top: SacTopBar.frostedInset(context),
                    ),
                    children: const [
                      SizedBox(key: Key('card'), height: 80),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final bar = tester.getRect(find.byType(AppBar));
      final card = tester.getRect(find.byKey(const Key('card')));
      expect(card.top, bar.bottom);
    });
  });
}
