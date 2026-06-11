import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/virtual_card/presentation/widgets/credencial/credential_parallax.dart';

void main() {
  testWidgets('tilts while dragged and resets after release', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: CredentialParallax(
              child: SizedBox(width: 240, height: 160),
            ),
          ),
        ),
      ),
    );

    Matrix4 currentMatrix() {
      final animated = tester.widget<AnimatedContainer>(
        find.byKey(credentialParallaxTransformKey),
      );
      return animated.transform!;
    }

    expect(currentMatrix(), Matrix4.identity());

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(CredentialParallax)),
    );
    await gesture.moveBy(const Offset(80, 40));
    await tester.pump();

    expect(currentMatrix(), isNot(Matrix4.identity()));

    await gesture.up();
    await tester.pumpAndSettle();

    expect(currentMatrix(), Matrix4.identity());
  });

  testWidgets('does not animate when reduced motion is enabled',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: Center(
              child: CredentialParallax(
                child: SizedBox(width: 240, height: 160),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(credentialParallaxTransformKey), findsNothing);
    expect(find.byType(SizedBox), findsOneWidget);
  });
}
