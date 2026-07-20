import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/features/achievements/domain/entities/achievement.dart';
import 'package:sacdia_app/features/achievements/domain/entities/user_achievement.dart';
import 'package:sacdia_app/features/achievements/presentation/widgets/achievement_badge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      _pathProviderChannel,
      (_) async => '/tmp',
    );
    CachedNetworkImageProvider.defaultCacheManager = _BadgeCacheManager();
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, null);
  });

  group('AchievementBadge motion accessibility', () {
    testWidgets(
      'keeps an unlocked diamond badge and star stable under reduced motion',
      (tester) async {
        await tester.pumpWidget(
          _badgeApp(
            reduceMotion: true,
            tier: AchievementTier.diamond,
          ),
        );
        await _finishImageDecode(tester);

        await tester.pumpAndSettle();

        expect(find.byType(AchievementBadge), findsOneWidget);
        expect(find.byType(ClipOval), findsOneWidget);
        expect(_starFinder, findsOneWidget);
        expect(_starScale(tester), 1.0);
        expect(tester.binding.hasScheduledFrame, isFalse);
      },
    );

    testWidgets(
      'stops and resumes eligible loops when reduced motion toggles',
      (tester) async {
        var reduceMotion = false;
        late StateSetter setHarnessState;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (_, setState) {
              setHarnessState = setState;
              return _badgeApp(
                reduceMotion: reduceMotion,
                tier: AchievementTier.diamond,
              );
            },
          ),
        );
        await _finishImageDecode(tester);

        await tester.pump(const Duration(milliseconds: 300));
        expect(_starScale(tester), greaterThan(1.0));
        expect(tester.binding.hasScheduledFrame, isTrue);

        await tester.pump(const Duration(milliseconds: 900));
        final peakScale = _starScale(tester);
        expect(peakScale, closeTo(1.3, 0.001));

        await tester.pump(const Duration(milliseconds: 600));
        expect(
            _starScale(tester), allOf(greaterThan(1.0), lessThan(peakScale)));

        setHarnessState(() => reduceMotion = true);
        await tester.pump();
        await tester.pumpAndSettle();

        expect(_starScale(tester), 1.0);
        expect(tester.binding.hasScheduledFrame, isFalse);

        setHarnessState(() => reduceMotion = false);
        await tester.pump();

        expect(tester.binding.hasScheduledFrame, isTrue);
        await tester.pump(const Duration(milliseconds: 300));
        expect(_starScale(tester), greaterThan(1.0));
      },
    );

    testWidgets('stops loops across state and tier eligibility changes', (
      tester,
    ) async {
      var reduceMotion = false;
      var tier = AchievementTier.diamond;
      var visualState = AchievementVisualState.unlocked;
      late StateSetter setHarnessState;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (_, setState) {
            setHarnessState = setState;
            return _badgeApp(
              reduceMotion: reduceMotion,
              tier: tier,
              visualState: visualState,
            );
          },
        ),
      );
      await _finishImageDecode(tester);

      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.binding.hasScheduledFrame, isTrue);

      setHarnessState(() => visualState = AchievementVisualState.locked);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(_starFinder, findsNothing);
      expect(tester.binding.hasScheduledFrame, isFalse);

      setHarnessState(() {
        visualState = AchievementVisualState.unlocked;
        tier = AchievementTier.platinum;
      });
      await tester.pump();

      expect(find.byType(ShaderMask), findsOneWidget);
      expect(_starFinder, findsNothing);
      expect(tester.binding.hasScheduledFrame, isTrue);

      setHarnessState(() => tier = AchievementTier.gold);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(_starFinder, findsNothing);
      expect(tester.binding.hasScheduledFrame, isFalse);

      setHarnessState(() {
        reduceMotion = true;
        tier = AchievementTier.diamond;
      });
      await tester.pump();
      await tester.pumpAndSettle();

      expect(_starFinder, findsOneWidget);
      expect(_starScale(tester), 1.0);
      expect(tester.binding.hasScheduledFrame, isFalse);

      setHarnessState(() => tier = AchievementTier.gold);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(_starFinder, findsNothing);
      expect(tester.binding.hasScheduledFrame, isFalse);

      setHarnessState(() => reduceMotion = false);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(_starFinder, findsNothing);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });
}

Widget _badgeApp({
  required bool reduceMotion,
  required AchievementTier tier,
  AchievementVisualState visualState = AchievementVisualState.unlocked,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Scaffold(
        body: Center(
          child: AchievementBadge(
            badgeImageUrl: null,
            tier: tier,
            visualState: visualState,
          ),
        ),
      ),
    ),
  );
}

Finder get _starFinder => find.byWidgetPredicate(
      (widget) =>
          widget is HugeIcon && widget.icon == HugeIcons.strokeRoundedStar,
    );

double _starScale(WidgetTester tester) {
  final transform = tester.widget<Transform>(
    find.ancestor(of: _starFinder, matching: find.byType(Transform)),
  );
  return transform.transform.getMaxScaleOnAxis();
}

Future<void> _finishImageDecode(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pump();
}

class _BadgeCacheManager extends Fake implements BaseCacheManager {
  _BadgeCacheManager() {
    final fileSystem = MemoryFileSystem();
    _badgeFile = fileSystem.file('/badge.png')
      ..writeAsBytesSync(base64Decode(_transparentPng));
  }

  late final File _badgeFile;

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) {
    return Stream.value(
      FileInfo(
        _badgeFile,
        FileSource.Cache,
        DateTime.now().add(const Duration(days: 1)),
        url,
      ),
    );
  }
}

const _transparentPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8A'
    'AQUBAScY42YAAAAASUVORK5CYII=';

const _pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
