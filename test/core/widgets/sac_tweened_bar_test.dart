import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/widgets/sac_tweened_bar.dart';

void main() {
  group('SacTweenedBar', () {
    testWidgets('should paint the current value on the first frame',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SacTweenedBar(
              value: 0.42,
              color: Color(0xFF1155CC),
              backgroundColor: Color(0xFFE5E7EB),
            ),
          ),
        ),
      );

      expect(_value(tester), 0.42);
    });

    testWidgets('should ease toward a new value', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: _BarHost())),
      );

      expect(_value(tester), 0.2);

      await tester.tap(find.text('sube'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));

      final mid = _value(tester);
      expect(mid, greaterThan(0.2));
      expect(mid, lessThan(0.9));
    });

    testWidgets('should jump when animations are disabled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(body: _BarHost()),
          ),
        ),
      );

      await tester.tap(find.text('sube'));
      await tester.pump();

      expect(_value(tester), 0.9);
    });
  });
}

class _BarHost extends StatefulWidget {
  const _BarHost();

  @override
  State<_BarHost> createState() => _BarHostState();
}

class _BarHostState extends State<_BarHost> {
  double _value = 0.2;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SacTweenedBar(
          value: _value,
          color: const Color(0xFF1155CC),
          backgroundColor: const Color(0xFFE5E7EB),
        ),
        TextButton(
          onPressed: () => setState(() => _value = 0.9),
          child: const Text('sube'),
        ),
      ],
    );
  }
}

double _value(WidgetTester tester) {
  return tester
      .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
      .value!;
}
