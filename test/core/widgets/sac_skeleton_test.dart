import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';

Widget _host(Widget child, {bool reduceMotion = false}) => MaterialApp(
      theme: AppTheme.lightTheme,
      builder: (context, c) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: c!,
      ),
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('shimmer is static with reduce motion', (tester) async {
    await tester.pumpWidget(
      _host(const SacShimmer(child: SacSkeletonBox(height: 10)),
          reduceMotion: true),
    );
    expect(find.byType(ShaderMask), findsNothing);
    await tester.pumpAndSettle();
    expect(find.byType(SacSkeletonBox), findsOneWidget);
  });

  testWidgets('shimmer animates when motion is allowed', (tester) async {
    await tester.pumpWidget(
      _host(const SacShimmer(child: SacSkeletonBox(height: 10))),
    );
    expect(find.byType(ShaderMask), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(
      _host(
          const SacShimmer(enabled: false, child: SacSkeletonBox(height: 10))),
    );
    expect(find.byType(ShaderMask), findsNothing);
  });

  testWidgets('skeleton list renders itemCount rows inside a RefreshIndicator',
      (tester) async {
    await tester.pumpWidget(
      _host(
        RefreshIndicator(
          onRefresh: () async {},
          child: const SacSkeletonList(itemCount: 3, lines: 2),
        ),
        reduceMotion: true,
      ),
    );
    // 3 rows * (1 avatar + 2 lines)
    expect(find.byType(SacSkeletonBox), findsNWidgets(9));
  });

  testWidgets('skeleton list without leading omits the avatar', (tester) async {
    await tester.pumpWidget(
      _host(const SacSkeletonList(itemCount: 2, leading: false, lines: 1),
          reduceMotion: true),
    );
    expect(find.byType(SacSkeletonBox), findsNWidgets(2));
  });

  testWidgets('skeleton card honors height', (tester) async {
    await tester.pumpWidget(_host(const SacSkeletonCard(height: 90)));
    expect(tester.getSize(find.byType(SacSkeletonCard)).height, 90);
  });
}
