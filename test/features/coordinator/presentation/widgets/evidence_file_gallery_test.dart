import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/coordinator/domain/entities/evidence_review_item.dart';
import 'package:sacdia_app/features/coordinator/presentation/widgets/evidence_file_gallery.dart';

import '../../coordinator_test_harness.dart';

void main() {
  setUpAll(initCoordinatorTestLocalization);

  testWidgets('image tiles paint their border over the image', (tester) async {
    await tester.pumpWidget(
      localized(
        (context) => localizedApp(
          context,
          const Scaffold(
            body: SingleChildScrollView(
              child: EvidenceFileGallery(
                files: [
                  EvidenceFile(
                    id: '1',
                    url: 'https://files.test/notifications.png',
                    name: 'notifications.png',
                    mimeType: 'image/png',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final bordered = tester.widgetList<DecoratedBox>(
      find.ancestor(
        of: find.byType(Image),
        matching: find.byType(DecoratedBox),
      ),
    );
    // A white screenshot must not hide the tile outline: the border sits in
    // the foreground, above the image.
    expect(
      bordered.any(
        (box) =>
            box.position == DecorationPosition.foreground &&
            (box.decoration as BoxDecoration).border != null,
      ),
      isTrue,
    );
  });
}
