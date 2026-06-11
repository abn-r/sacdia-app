import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/onboarding/sac_onboarding.dart';

void main() {
  testWidgets('SacOnboardingAnchor renders without a scope', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SacOnboardingAnchor(
            id: 'profile-card',
            child: Text('Perfil'),
          ),
        ),
      ),
    );

    expect(find.text('Perfil'), findsOneWidget);
  });

  testWidgets('SacOnboardingScope supports showing an anchored helper',
      (tester) async {
    var acknowledged = false;

    await tester.pumpWidget(
      MaterialApp(
        home: SacOnboardingScope(
          child: Scaffold(
            body: Builder(
              builder: (context) {
                return Column(
                  children: [
                    const SacOnboardingAnchor(
                      id: 'main-action',
                      child: Text('Acción principal'),
                    ),
                    TextButton(
                      onPressed: () {
                        SacOnboarding.showAnchoredHelper(
                          context,
                          anchorId: 'main-action',
                          title: 'Título',
                          description: 'Descripción',
                          primaryActionLabel: 'Entendido',
                          onPrimaryAction: () => acknowledged = true,
                        );
                      },
                      child: const Text('Mostrar ayuda'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mostrar ayuda'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 1600));

    expect(find.text('Título'), findsOneWidget);
    expect(find.text('Descripción'), findsOneWidget);

    await tester.tap(find.text('Entendido'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1600));

    expect(acknowledged, isTrue);
  });
}
