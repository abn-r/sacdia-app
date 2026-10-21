import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/coordinator/data/models/consent_pending_page_model.dart';
import 'package:sacdia_app/features/members/domain/entities/join_request.dart';

import '../../coordinator_test_support.dart';

void main() {
  group('ConsentPendingPageModel.fromJson', () {
    test('reads the page envelope: total, limit, offset', () {
      final page = ConsentPendingPageModel.fromJson(
        pendingPageJson(
          items: [pendingItemJson(id: 'a1', sectionId: 7)],
          total: 120,
          limit: 50,
          offset: 50,
        ),
      );

      expect(page.total, 120);
      expect(page.limit, 50);
      expect(page.offset, 50);
      expect(page.items, hasLength(1));
    });

    test('an item is a join request openable by the verification view', () {
      final page = ConsentPendingPageModel.fromJson(
        pendingPageJson(
          items: [pendingItemJson(id: 'a1', sectionId: 7, name: 'Ana')],
        ),
      );

      final request = page.items.single.request;
      // The verification view addresses `<section>/membership-requests/<id>`.
      expect(request.assignmentId, '7/membership-requests/a1');
      expect(request.clubSectionId, 7);
      expect(request.fullName, 'Ana Pérez Soto');
      expect(request.status, JoinRequestStatus.pending);
      expect(request.consentPending, isTrue);
      expect(request.consent?.guardianshipId, 'gs-a1');
      expect(request.consent?.evidenceUploaded, isTrue);
      expect(request.consent?.viewerCanVerify, isTrue);
      expect(request.consent?.viewerVerifyBlock, isNull);
    });

    test('keeps the club, type, district and form date of each item', () {
      final page = ConsentPendingPageModel.fromJson(
        pendingPageJson(
          items: [
            pendingItemJson(
              id: 'a1',
              sectionId: 7,
              club: 'Club Águilas',
              type: 'Aventureros',
              district: 'Distrito Sur',
              uploadedAt: '2026-10-10T12:00:00.000Z',
            ),
            pendingItemJson(id: 'a2', sectionId: 8, district: null),
          ],
        ),
      );

      final first = page.items.first;
      expect(first.clubSectionId, 7);
      expect(first.clubName, 'Club Águilas');
      expect(first.clubTypeName, 'Aventureros');
      expect(first.districtName, 'Distrito Sur');
      expect(first.formUploadedAt, DateTime.utc(2026, 10, 10, 12));
      expect(first.caption, 'Club Águilas · Aventureros · Distrito Sur');
      // A null district is simply left out of the caption.
      expect(page.items.last.districtName, isNull);
      expect(page.items.last.caption, 'Club Águilas · Conquistadores');
    });

    test('keeps the server order of the items', () {
      final page = ConsentPendingPageModel.fromJson(
        pendingPageJson(
          items: [
            pendingItemJson(id: 'old', sectionId: 1),
            pendingItemJson(id: 'new', sectionId: 2),
          ],
        ),
      );

      expect(page.items.map((i) => i.request.assignmentId), [
        '1/membership-requests/old',
        '2/membership-requests/new',
      ]);
    });

    test('reads the per-section counts', () {
      final page = ConsentPendingPageModel.fromJson(
        pendingPageJson(
          items: [pendingItemJson(id: 'a1', sectionId: 7)],
          total: 3,
          bySection: [
            pendingSectionJson(sectionId: 7, count: 2),
            pendingSectionJson(
              sectionId: 9,
              count: 1,
              club: 'Club Leones',
              type: 'Guías Mayores',
              district: null,
            ),
          ],
        ),
      );

      expect(page.bySection, hasLength(2));
      final first = page.bySection.first;
      expect(first.clubSectionId, 7);
      expect(first.clubName, 'Club Águilas');
      expect(first.clubTypeName, 'Conquistadores');
      expect(first.districtName, 'Distrito Norte');
      expect(first.pendingConsentCount, 2);
      expect(page.bySection.last.districtName, isNull);
      expect(page.bySection.last.pendingConsentCount, 1);
    });

    test('an empty queue parses to nothing, not an error', () {
      final page = ConsentPendingPageModel.fromJson(
        pendingPageJson(items: const []),
      );

      expect(page.items, isEmpty);
      expect(page.total, 0);
      expect(page.bySection, isEmpty);
    });

    test('tolerates a missing list and counts as empty / zero', () {
      final page = ConsentPendingPageModel.fromJson(const <String, dynamic>{});

      expect(page.items, isEmpty);
      expect(page.bySection, isEmpty);
      expect(page.total, 0);
    });
  });
}
