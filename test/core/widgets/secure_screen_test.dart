import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/widgets/secure_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('secure_application');
  late List<String> nativeCalls;

  setUp(() {
    nativeCalls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      nativeCalls.add(call.method);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('clears stale native blur before securing on mount',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SecureScreen(child: SizedBox.shrink()),
      ),
    );
    await tester.pump();

    expect(nativeCalls.take(2), <String>['unlock', 'secure']);
  });

  testWidgets('removes the native privacy blur when the app resumes',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SecureScreen(child: SizedBox.shrink()),
      ),
    );
    await tester.pump();

    nativeCalls.clear();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(nativeCalls, contains('unlock'));
  });

  testWidgets('removes any native blur when the secure screen is disposed',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SecureScreen(child: SizedBox.shrink()),
      ),
    );
    await tester.pump();

    nativeCalls.clear();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(nativeCalls, contains('unlock'));
    expect(nativeCalls, contains('open'));
  });
}
