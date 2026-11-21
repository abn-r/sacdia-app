import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/widgets/badge_grid/sac_badge_card.dart';
import 'package:sacdia_app/core/widgets/badge_grid/sac_badge_grid.dart';
import 'package:sacdia_app/core/widgets/badge_grid/sac_badge_tint.dart';

Widget _host(
  Widget child, {
  bool reduceMotion = false,
  double textScale = 1,
  double width = 390,
}) {
  return MediaQuery(
    data: MediaQueryData(
      disableAnimations: reduceMotion,
      textScaler: TextScaler.linear(textScale),
    ),
    child: MaterialApp(
      home: Scaffold(
        body: Center(child: SizedBox(width: width, child: child)),
      ),
    ),
  );
}

const _art =
    SizedBox(width: 60, height: 60, child: ColoredBox(color: Colors.red));

SacBadgeCard _card({
  String name = 'Primer Paso',
  SacBadgeTone tone = SacBadgeTone.muted,
  SacBadgeMeta meta = const SacBadgeMeta.none(),
}) {
  return SacBadgeCard(name: name, art: _art, tone: tone, meta: meta);
}

/// Biggest scale applied by any [Transform] inside the card.
double _maxScale(WidgetTester tester) {
  var max = 1.0;
  for (final transform in tester.widgetList<Transform>(
    find.descendant(
      of: find.byType(SacBadgeCard),
      matching: find.byType(Transform),
    ),
  )) {
    final scale = transform.transform.getMaxScaleOnAxis();
    if (scale > max) max = scale;
  }
  return max;
}

Finder get _halo => find.byWidgetPredicate((widget) {
      if (widget is! DecoratedBox) return false;
      final decoration = widget.decoration;
      return decoration is BoxDecoration &&
          decoration.shape == BoxShape.circle &&
          (decoration.boxShadow?.isNotEmpty ?? false);
    });

Finder get _grayFilter => find.descendant(
      of: find.byType(SacBadgeCard),
      matching: find.byType(ColorFiltered),
    );

void main() {
  group('meta line', () {
    testWidgets('obtained shows the label and no bar', (tester) async {
      await tester.pumpWidget(_host(_card(
        tone: SacBadgeTone.color,
        meta: const SacBadgeMeta.obtained('14 sep'),
      )));

      expect(find.text('14 sep'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('progress shows a bar at the fraction and the count',
        (tester) async {
      await tester.pumpWidget(_host(_card(
        meta: const SacBadgeMeta.progress(fraction: 0.6, label: '6 de 10'),
      )));

      expect(find.text('6 de 10'), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, closeTo(0.6, 0.001));
    });

    testWidgets('warning shows its label', (tester) async {
      await tester.pumpWidget(_host(_card(
        tone: SacBadgeTone.color,
        meta: const SacBadgeMeta.warning('No vigente'),
      )));

      expect(find.text('No vigente'), findsOneWidget);
    });

    testWidgets('none shows only the name', (tester) async {
      await tester.pumpWidget(_host(_card()));

      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byType(Text), findsOneWidget);
    });
  });

  group('look', () {
    testWidgets('muted art is greyed, colour art is not', (tester) async {
      await tester.pumpWidget(_host(_card()));
      expect(_grayFilter, findsOneWidget);

      // Changing the tone in place plays the transition; let it finish.
      await tester.pumpWidget(_host(_card(tone: SacBadgeTone.color)));
      await tester.pump(const Duration(seconds: 2));
      expect(_grayFilter, findsNothing);
    });

    testWidgets('dimmed art keeps its colour and is faded', (tester) async {
      await tester.pumpWidget(_host(_card(tone: SacBadgeTone.dimmed)));

      expect(_grayFilter, findsNothing);
      final opacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(SacBadgeCard),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, SacBadgeTone.dimmed.opacity);
    });

    testWidgets('shows the full name up to three lines', (tester) async {
      const long =
          'Conquistador Avanzado de las Grandes Montañas Doradas del Sur';
      await tester.pumpWidget(_host(_card(name: long), width: 110));

      final text = tester.widget<Text>(find.text(long));
      expect(text.maxLines, 3);
      expect(text.textAlign, TextAlign.center);
    });
  });

  group('grid layout', () {
    Widget grid(List<String> names) => SacBadgeGrid(
          itemCount: names.length,
          keyOf: (i) => ValueKey(i),
          itemBuilder: (_, i) => _card(name: names[i]),
        );

    for (final scale in [1.0, 1.3]) {
      testWidgets('rows have equal heights and nothing overflows at x$scale',
          (tester) async {
        await tester.pumpWidget(_host(
          SizedBox(
            height: 800,
            child: grid([
              'Primer Paso',
              'Conquistador Avanzado de las Grandes Montañas Doradas del Sur',
              'Fiel',
              'Participante Activo',
              'Explorador de Categorías',
              'Coleccionista',
            ]),
          ),
          reduceMotion: true,
          textScale: scale,
        ));

        expect(tester.takeException(), isNull);
        final heights = {
          for (final card in tester.widgetList(find.byType(SacBadgeCard)))
            tester.getSize(find.byWidget(card)).height,
        };
        expect(heights, hasLength(1));
      });
    }
  });

  group('grey to colour transition', () {
    Future<void> flip(WidgetTester tester, {required bool reduceMotion}) async {
      await tester.pumpWidget(_host(
        _card(
          meta: const SacBadgeMeta.progress(fraction: 0.9, label: '9 de 10'),
        ),
        reduceMotion: reduceMotion,
      ));
      await tester.pumpWidget(_host(
        _card(
          tone: SacBadgeTone.color,
          meta: const SacBadgeMeta.obtained('hoy'),
        ),
        reduceMotion: reduceMotion,
      ));
    }

    testWidgets('overshoots, plays a halo and cross-fades the meta',
        (tester) async {
      await flip(tester, reduceMotion: false);

      await tester.pump(const Duration(milliseconds: 100));
      expect(_halo, findsOneWidget);
      expect(_grayFilter, findsOneWidget, reason: 'still turning to colour');
      // Both meta lines are on screen while they cross-fade.
      expect(find.text('9 de 10'), findsOneWidget);
      expect(find.text('hoy'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 200));
      expect(_maxScale(tester), greaterThan(1.04));

      await tester.pump(const Duration(milliseconds: 300));
      expect(_maxScale(tester), lessThan(1.01));
      expect(_grayFilter, findsNothing);
      expect(_halo, findsOneWidget, reason: 'the halo outlasts the reveal');

      await tester.pump(const Duration(milliseconds: 1000));
      expect(_halo, findsNothing);
      expect(find.text('9 de 10'), findsNothing);
      expect(find.text('hoy'), findsOneWidget);
    });

    testWidgets('with reduced motion it only cross-fades', (tester) async {
      await flip(tester, reduceMotion: true);

      await tester.pump(const Duration(milliseconds: 80));
      expect(_halo, findsNothing);
      expect(_maxScale(tester), lessThan(1.01));
      expect(_grayFilter, findsOneWidget, reason: 'still fading to colour');

      await tester.pump(const Duration(milliseconds: 200));
      expect(_grayFilter, findsNothing);
      expect(find.text('hoy'), findsOneWidget);
    });

    testWidgets('a card that is built already obtained does not animate',
        (tester) async {
      await tester.pumpWidget(_host(_card(tone: SacBadgeTone.color)));
      await tester.pump(const Duration(milliseconds: 100));

      expect(_halo, findsNothing);
      expect(_maxScale(tester), lessThan(1.01));
    });
  });

  group('entrance', () {
    int fadeAncestors(WidgetTester tester, String text) => find
        .ancestor(of: find.text(text), matching: find.byType(FadeTransition))
        .evaluate()
        .length;

    testWidgets('plays on first load only, not for cards added later',
        (tester) async {
      Widget grid(int count) => SizedBox(
            height: 800,
            child: SacBadgeGrid(
              itemCount: count,
              keyOf: (i) => ValueKey(i),
              itemBuilder: (_, i) => _card(name: 'Logro $i'),
            ),
          );

      await tester.pumpWidget(_host(grid(3)));
      final firstLoad = fadeAncestors(tester, 'Logro 0');

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpWidget(_host(grid(4)));
      await tester.pump();

      expect(
        fadeAncestors(tester, 'Logro 3'),
        lessThan(firstLoad),
        reason: 'a card built after the window closed has no entrance',
      );
      expect(
        fadeAncestors(tester, 'Logro 0'),
        firstLoad,
        reason: 'cards already on screen keep their wrapper (and state)',
      );
    });

    testWidgets('reduced motion shows every card at once', (tester) async {
      await tester.pumpWidget(_host(
        SizedBox(
          height: 800,
          child: SacBadgeGrid(
            itemCount: 3,
            keyOf: (i) => ValueKey(i),
            itemBuilder: (_, i) => _card(name: 'Logro $i'),
          ),
        ),
        reduceMotion: true,
      ));

      expect(
        fadeAncestors(tester, 'Logro 0'),
        fadeAncestors(tester, 'Logro 2'),
      );
      expect(find.text('Logro 2'), findsOneWidget);
    });
  });
}
