import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/features/resources/domain/entities/resource.dart';
import 'package:sacdia_app/features/resources/presentation/providers/resources_providers.dart';
import 'package:sacdia_app/features/resources/presentation/widgets/resource_detail_sheet.dart';
import '../../support/riverpod_test_support.dart';
import 'resources_test_support.dart';

const _play = 'resources.audio.play';
const _download = 'resources.action.download';
const _share = 'resources.action.share';

void main() {
  group('ResourceDetailSheet actions', () {
    testWidgets('audio has the player, Descargar and Compartir, no primary',
        (tester) async {
      await _pumpSheet(tester, _resource(type: 'audio'));

      expect(find.bySemanticsLabel(_play), findsOneWidget);
      expect(find.text(_download), findsOneWidget);
      expect(find.text(_share), findsOneWidget);
      expect(find.text('resources.action.open_pdf'), findsNothing);
      expect(find.text('resources.action.view_image'), findsNothing);
    });

    testWidgets('image: Ver imagen is primary, Descargar/Compartir secondary',
        (tester) async {
      await _pumpSheet(tester, _resource(type: 'image'));

      expect(find.text('resources.action.view_image'), findsOneWidget);
      expect(find.text(_download), findsOneWidget);
      expect(find.text(_share), findsOneWidget);
    });

    testWidgets('pdf: Abrir PDF is primary, Descargar/Compartir side by side',
        (tester) async {
      await _pumpSheet(
        tester,
        _resource(
            type: 'document', fileName: 'manual.pdf', mime: 'application/pdf'),
      );

      final open = tester.getCenter(find.text('resources.action.open_pdf'));
      final download = tester.getCenter(find.text(_download));
      final share = tester.getCenter(find.text(_share));
      expect(download.dy, share.dy);
      expect(download.dx, lessThan(share.dx));
      expect(open.dy, lessThan(download.dy));
    });

    testWidgets('a document with no viewer makes Descargar the primary action',
        (tester) async {
      await _pumpSheet(
        tester,
        _resource(type: 'document', fileName: 'plan.docx'),
      );

      expect(find.text('resources.action.open_pdf'), findsNothing);
      expect(find.text(_download), findsOneWidget);
      expect(find.text(_share), findsOneWidget);
    });

    testWidgets('a YouTube video opens outside and says so', (tester) async {
      await _pumpSheet(
        tester,
        _resource(
          type: 'video_link',
          externalUrl: 'https://youtu.be/abc123',
          fileName: null,
        ),
      );

      expect(find.text('resources.action.open_youtube'), findsOneWidget);
      expect(find.text('resources.video.opens_outside'), findsOneWidget);
      expect(find.text(_download), findsNothing);
    });

    testWidgets('a non-YouTube video link is labelled as a generic link',
        (tester) async {
      await _pumpSheet(
        tester,
        _resource(type: 'video_link', externalUrl: 'https://vimeo.com/123'),
      );

      expect(find.text('resources.action.open_link'), findsOneWidget);
      expect(find.text('resources.video.opens_outside'), findsOneWidget);
    });

    testWidgets('a video without a usable URL shows no leaving-the-app note',
        (tester) async {
      await _pumpSheet(tester, _resource(type: 'video_link'));

      expect(find.text('resources.video.opens_outside'), findsNothing);
      expect(find.text('resources.action.watch_video'), findsOneWidget);
    });

    testWidgets('text resources show the content and no actions',
        (tester) async {
      await _pumpSheet(
        tester,
        _resource(type: 'text', content: 'Lema del año'),
      );

      expect(find.text('Lema del año'), findsWidgets);
      expect(find.text(_download), findsNothing);
      expect(find.text(_share), findsNothing);
    });

    testWidgets('Compartir sends the title and the file link', (tester) async {
      final shared = <({String text, String subject})>[];
      await _pumpSheet(
        tester,
        _resource(type: 'image', signedUrl: 'https://files.example/pic.png'),
        sharer: ({required text, required subject}) async =>
            shared.add((text: text, subject: subject)),
      );

      await tester.tap(find.text(_share));
      await tester.pumpAndSettle();

      expect(shared, hasLength(1));
      expect(shared.single.subject, 'Recurso image');
      expect(shared.single.text, contains('https://files.example/pic.png'));
    });

    testWidgets('Compartir sends the video URL for video links',
        (tester) async {
      final shared = <String>[];
      await _pumpSheet(
        tester,
        _resource(type: 'video_link', externalUrl: 'https://youtu.be/abc123'),
        sharer: ({required text, required subject}) async => shared.add(text),
      );

      // Video has no secondary row: nothing to share from the footer.
      expect(find.text(_share), findsNothing);
      expect(shared, isEmpty);
    });
  });

  group('ResourceDetailSheet info', () {
    testWidgets('shows type, size and date on one line, once', (tester) async {
      await _pumpSheet(
        tester,
        _resource(type: 'document', fileName: 'm.pdf', mime: 'application/pdf'),
      );

      expect(find.text('resources.type_label.pdf · 2.0 KB · Nov 12, 2026'),
          findsOneWidget);
      // The duplicated type chip is gone.
      expect(find.byType(SacBadge), findsNothing);
    });

    testWidgets('lists category, club (with logo) and publisher',
        (tester) async {
      await _pumpSheet(
        tester,
        _resource(
          type: 'document',
          categoryName: 'Clases',
          clubTypeName: 'Conquistadores',
          scopeLevel: 'local_field',
        ),
      );

      expect(find.text('resources.detail.category'), findsOneWidget);
      expect(find.text('Clases'), findsOneWidget);
      expect(find.text('resources.detail.for'), findsOneWidget);
      expect(find.text('Conquistadores'), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) =>
            w is Image &&
            w.image is ResizeImage &&
            ((w.image as ResizeImage).imageProvider as AssetImage).assetName ==
                'assets/img/logo_conquistadores.png'),
        findsOneWidget,
      );
      expect(find.text('resources.detail.published_by'), findsOneWidget);
      expect(find.text('resources.scope.local_field'), findsOneWidget);
    });

    testWidgets('omits rows that have no data', (tester) async {
      await _pumpSheet(
        tester,
        _resource(type: 'document', scopeLevel: 'something_new'),
      );

      expect(find.text('resources.detail.category'), findsNothing);
      expect(find.text('resources.detail.for'), findsNothing);
      expect(find.text('resources.detail.published_by'), findsNothing);
    });
  });
}

Future<void> _pumpSheet(
  WidgetTester tester,
  Resource resource, {
  ResourceSharer? sharer,
}) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    testProviderScope(
      overrides: [
        if (sharer != null) resourceSharerProvider.overrideWithValue(sharer),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: ResourceDetailSheet(resource: resource)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Resource _resource({
  required String type,
  String? fileName,
  String? mime,
  String? categoryName,
  String? clubTypeName,
  String scopeLevel = 'system',
  String? externalUrl,
  String? signedUrl,
  String? content,
}) {
  return testResource(
    id: 'res-$type',
    title: 'Recurso $type',
    type: type,
    categoryName: categoryName,
    clubTypeName: clubTypeName,
    scopeLevel: scopeLevel,
    fileName: fileName ?? '$type.bin',
    mime: mime,
    externalUrl: externalUrl,
    signedUrl: signedUrl,
    content: content,
  );
}
