import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/resources/domain/entities/resource.dart';
import 'package:sacdia_app/features/resources/presentation/widgets/resource_detail_sheet.dart';

void main() {
  group('ResourceDetailSheet media actions', () {
    testWidgets('audio resources expose play and download actions',
        (tester) async {
      await _pumpSheet(tester, _resource(resourceType: 'audio'));

      expect(find.text('resources.audio.player_title'), findsOneWidget);
      expect(find.text('resources.action.play_audio'), findsOneWidget);
      expect(find.text('resources.action.download'), findsOneWidget);
    });

    testWidgets('image resources expose view and download actions',
        (tester) async {
      await _pumpSheet(tester, _resource(resourceType: 'image'));

      expect(find.text('resources.action.view_image'), findsOneWidget);
      expect(find.text('resources.action.download'), findsOneWidget);
    });

    testWidgets('pdf documents expose in-app view and download actions',
        (tester) async {
      await _pumpSheet(
        tester,
        _resource(
          resourceType: 'document',
          fileName: 'manual.pdf',
          fileMimeType: 'application/pdf',
        ),
      );

      expect(find.text('resources.action.view_pdf'), findsOneWidget);
      expect(find.text('resources.action.download'), findsOneWidget);
    });
  });
}

Future<void> _pumpSheet(WidgetTester tester, Resource resource) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: ResourceDetailSheet(resource: resource),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Resource _resource({
  required String resourceType,
  String? fileName,
  String? fileMimeType,
}) {
  return Resource(
    resourceId: 'res-$resourceType',
    title: 'Recurso $resourceType',
    resourceType: resourceType,
    scopeLevel: 'system',
    fileName: fileName ?? '$resourceType.bin',
    fileMimeType: fileMimeType,
    fileSize: 1024,
    createdAt: DateTime(2026, 5, 28),
  );
}
