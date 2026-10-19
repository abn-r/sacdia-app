import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/auth/presentation/providers/acting_providers.dart';
import 'package:sacdia_app/features/auth/presentation/widgets/acting_notice_listener.dart';

Widget _app(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(0.5),
        ),
        child: ActingNoticeListener(child: child!),
      ),
      home: const Scaffold(body: Text('home')),
    ),
  );
}

void main() {
  testWidgets('shows the access-revoked message once and clears the notice',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    expect(find.byType(SnackBar), findsNothing);

    container.read(actingNoticeProvider.notifier).state =
        ActingNotice.accessRevoked;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(SnackBar), findsOneWidget);
    expect(
      find.text(ActingNoticeListener.messageFor(ActingNotice.accessRevoked)),
      findsOneWidget,
    );
    expect(container.read(actingNoticeProvider), isNull);

    // Repintar no vuelve a mostrarlo.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('renders its child untouched when there is no notice',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));

    expect(find.text('home'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });
}
