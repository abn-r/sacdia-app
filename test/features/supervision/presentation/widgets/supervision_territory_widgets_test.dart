/// Tests for the widgets the territory screens (operations, clubs, club
/// summary, reports, annual progress) share.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/sac_tone.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_annual_progress.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_figures_card.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_identity_tiles.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_progress_parts.dart';

Widget _host(Widget child, {double textScale = 1}) => MaterialApp(
      theme: AppTheme.lightTheme,
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: app!,
      ),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  group('monogram and initials', () {
    test('monogram: first two letters of the first word, uppercase', () {
      expect(supervisionMonogramLetters('Pléyades'), 'PL');
      expect(supervisionMonogramLetters('Estrella del Mar'), 'ES');
      expect(supervisionMonogramLetters('  orión '), 'OR');
      expect(supervisionMonogramLetters('A'), 'A');
      expect(supervisionMonogramLetters(''), '·');
    });

    test('initials: first letter of the first two words', () {
      expect(supervisionInitials('Mateo Herrera'), 'MH');
      expect(supervisionInitials('laura méndez ruiz'), 'LM');
      expect(supervisionInitials('Ana'), 'A');
      expect(supervisionInitials('   '), '·');
    });

    testWidgets('a dimmed monogram fades', (tester) async {
      await tester.pumpWidget(
        _host(const SupervisionMonogram(name: 'Caninos', dimmed: true)),
      );

      expect(find.text('CA'), findsOneWidget);
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, lessThan(1));
    });
  });

  group('SupervisionClubTypeLogo', () {
    testWidgets('a known club type shows its logo, labeled with the type', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(const SupervisionClubTypeLogo(typeName: 'Conquistadores')),
      );

      expect(find.byType(Image), findsOneWidget);
      expect(find.bySemanticsLabel('Conquistadores'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('an unknown type falls back to its first letter', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const SupervisionClubTypeLogo(typeName: 'Tropa')),
      );

      expect(find.byType(Image), findsNothing);
      expect(find.text('T'), findsOneWidget);
    });
  });

  group('SupervisionDateTile', () {
    testWidgets('shows the day and the short month', (tester) async {
      await tester.pumpWidget(
        _host(SupervisionDateTile(date: DateTime(2026, 11, 12))),
      );

      expect(find.text('12'), findsOneWidget);
      expect(find.text('NOV'), findsOneWidget);
    });

    testWidgets('no date shows a dash', (tester) async {
      await tester.pumpWidget(_host(const SupervisionDateTile(date: null)));

      expect(find.text('—'), findsOneWidget);
    });
  });

  group('SupervisionFiguresCard', () {
    testWidgets('lays out two figures per row, value over label', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const SupervisionFiguresCard(
            figures: [
              SupervisionFigure(value: '18', suffix: 'de 21', label: 'Clubes'),
              SupervisionFigure(value: '1,240', label: 'Personas'),
              SupervisionFigure(value: '860', label: 'Con cuenta'),
              SupervisionFigure(value: '642', label: 'Inscritos'),
            ],
          ),
        ),
      );

      expect(find.text('18 de 21'), findsOneWidget);
      final first = tester.getTopLeft(find.text('18 de 21'));
      final second = tester.getTopLeft(find.text('1,240'));
      final third = tester.getTopLeft(find.text('860'));
      expect(second.dy, first.dy);
      expect(second.dx, greaterThan(first.dx));
      expect(third.dy, greaterThan(first.dy));
      expect(third.dx, first.dx);
      // The label sits under its value.
      expect(
        tester.getTopLeft(find.text('Clubes')).dy,
        greaterThan(first.dy),
      );
    });

    testWidgets('a figure with onTap is a button; the others are not', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          SupervisionFiguresCard(
            figures: [
              const SupervisionFigure(value: '1', label: 'Plano'),
              SupervisionFigure(
                value: '2',
                label: 'Abre',
                onTap: () => taps++,
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.text('Plano'));
      expect(taps, 0);
      await tester.tap(find.text('Abre'));
      expect(taps, 1);
    });

    testWidgets('an odd count leaves the last cell empty', (tester) async {
      await tester.pumpWidget(
        _host(
          const SupervisionFiguresCard(
            figures: [
              SupervisionFigure(value: '1', label: 'A'),
              SupervisionFigure(value: '2', label: 'B'),
              SupervisionFigure(value: '3', label: 'C'),
            ],
          ),
        ),
      );

      expect(find.text('C'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a warning tone changes the color of the number only', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const SupervisionFiguresCard(
            figures: [
              SupervisionFigure(value: '5', label: 'Plano'),
              SupervisionFigure(
                value: '2',
                label: 'Atención',
                tone: SacTone.warning,
              ),
            ],
          ),
        ),
      );

      Color? colorOf(String value) {
        final text = tester.widget<Text>(find.text(value));
        final span = (text.textSpan! as TextSpan).children!.first as TextSpan;
        return span.style?.color;
      }

      expect(colorOf('2'), isNot(colorOf('5')));
    });

    testWidgets('does not overflow at text scale 2.0 on 320 wide', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _host(
          const SupervisionFiguresCard(
            figures: [
              SupervisionFigure(
                value: '1,234,567',
                suffix: 'de 1,234,567',
                label: 'Clubes operativos del campo local con nombre largo',
              ),
              SupervisionFigure(value: '9', label: 'Personas'),
            ],
          ),
          textScale: 2,
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('tiers', () {
    SupervisionProgressTier tier(String name, [String slug = '']) =>
        SupervisionProgressTier(name: name, slug: slug);

    test('kind comes from the name or slug, in any language', () {
      expect(
          supervisionTierKind(tier('Diamante')), SupervisionTierKind.diamond);
      expect(supervisionTierKind(tier('x', 'diamond')),
          SupervisionTierKind.diamond);
      expect(supervisionTierKind(tier('Oro')), SupervisionTierKind.gold);
      expect(supervisionTierKind(tier('Gold')), SupervisionTierKind.gold);
      expect(supervisionTierKind(tier('Plata')), SupervisionTierKind.silver);
      expect(supervisionTierKind(tier('Silver')), SupervisionTierKind.silver);
      expect(supervisionTierKind(tier('Bronce')), SupervisionTierKind.bronze);
      expect(supervisionTierKind(tier('Otra')), SupervisionTierKind.bronze);
    });

    test('no tier or a blank one is no medal', () {
      expect(supervisionTierKind(null), SupervisionTierKind.none);
      expect(supervisionTierKind(tier('  ')), SupervisionTierKind.none);
    });
  });
}
