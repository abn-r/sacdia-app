import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/sac_sheet_header.dart';

void main() {
  testWidgets('renders grabber, title and close', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: SacSheetHeader(
            title: 'Ubicación',
            subtitle: 'Parque Central',
            showClose: true,
          ),
        ),
      ),
    );

    expect(find.byType(SacSheetGrabber), findsOneWidget);
    expect(find.text('Ubicación'), findsOneWidget);
    expect(find.text('Parque Central'), findsOneWidget);
    expect(find.byType(IconButton), findsOneWidget);

    final box = tester.getSize(
      find.descendant(
        of: find.byType(SacSheetGrabber),
        matching: find.byType(Container),
      ),
    );
    expect(box.width, SacSheetGrabber.pillWidth);
    expect(box.height, SacSheetGrabber.pillHeight);
  });

  testWidgets('omits grabber when showGrabber is false', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SacSheetHeader(
            title: 'Filtros',
            showGrabber: false,
          ),
        ),
      ),
    );

    expect(find.byType(SacSheetGrabber), findsNothing);
    expect(find.text('Filtros'), findsOneWidget);
  });
}
