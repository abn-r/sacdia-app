import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/sac_filter_chip.dart';

void main() {
  group('SacFilterChip', () {
    testWidgets('should fill primary when selected', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: SacFilterChip(
              label: 'Todos',
              selected: true,
              onTap: null,
            ),
          ),
        ),
      );

      expect(find.text('Todos'), findsOneWidget);
      final box =
          tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.color, SacAccent.logoBlue.color);
    });

    testWidgets('should fire onTap when enabled chip is tapped',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SacFilterChip(
              label: 'Clases',
              selected: false,
              icon: HugeIcons.strokeRoundedGridView,
              onTap: () => taps++,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Clases'));
      expect(taps, 1);
    });

    testWidgets('should stay compact in height', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: SacFilterChip(
              label: 'Todos',
              selected: true,
              icon: HugeIcons.strokeRoundedGridView,
              count: 12,
              onTap: null,
            ),
          ),
        ),
      );

      final pill = tester.getSize(find.byType(AnimatedContainer));
      expect(pill.height, SacFilterChip.minHeight);

      final hit = tester.getSize(find.byType(SacFilterChip));
      expect(hit.height, SacFilterChip.hitExtent);
      expect(hit.width, greaterThanOrEqualTo(SacFilterChip.hitExtent));
    });

    testWidgets('should not fill primary when quiet variant is selected',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: SacFilterChip(
              label: 'Todas',
              selected: true,
              variant: SacFilterChipVariant.quiet,
              onTap: null,
            ),
          ),
        ),
      );

      final box =
          tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.color, SacAccent.logoBlue.light);
      expect((decoration.border as Border).top.color, SacAccent.logoBlue.dark);
    });

    testWidgets('should use accent colors and a logo when provided',
        (tester) async {
      const wash = Color(0xFFE0F0FA);
      const ink = Color(0xFF1A6B9C);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: SacFilterChip(
              label: 'Aventureros',
              selected: true,
              variant: SacFilterChipVariant.quiet,
              accentBackground: wash,
              accentForeground: ink,
              logoAsset: 'assets/img/logo_aventureros.png',
              onTap: null,
            ),
          ),
        ),
      );

      final box =
          tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.color, wash);
      expect((decoration.border as Border).top.color, ink);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('should ease the label color when selection changes',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: _ChipHost()),
        ),
      );

      final before = _labelColor(tester);
      expect(before, const SacColors(Brightness.light).textSecondary);

      await tester.tap(find.text('Avisos'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));

      final mid = _labelColor(tester);
      expect(mid, isNot(before));
      expect(mid, isNot(Colors.white));

      await tester.pumpAndSettle();
      expect(_labelColor(tester), Colors.white);
    });
  });
}

class _ChipHost extends StatefulWidget {
  const _ChipHost();

  @override
  State<_ChipHost> createState() => _ChipHostState();
}

class _ChipHostState extends State<_ChipHost> {
  bool _selected = false;

  @override
  Widget build(BuildContext context) {
    return SacFilterChip(
      label: 'Avisos',
      selected: _selected,
      onTap: () => setState(() => _selected = true),
    );
  }
}

Color _labelColor(WidgetTester tester) {
  final context = tester.element(find.text('Avisos'));
  return DefaultTextStyle.of(context).style.color!;
}
