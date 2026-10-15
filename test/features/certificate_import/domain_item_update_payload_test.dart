import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/certificate_import/domain/entities/certificate_import_item.dart';
import 'package:sacdia_app/features/certificate_import/domain/entities/certificate_import_payloads.dart';

const _ana = CertificateImportInstructorRef(
  isUser: true,
  userId: '11111111-1111-4111-8111-111111111111',
  displayName: 'Ana Gómez',
);
const _juan = CertificateImportInstructorRef(
  isUser: false,
  displayName: 'Juan López',
);

CertificateImportItem _item({
  CertificateImportItemType type = CertificateImportItemType.honor,
  CertificateImportInstructorRef? instructor,
}) =>
    CertificateImportItem(
      id: 'row-1',
      batchId: 'batch-1',
      type: type,
      honorId: type == CertificateImportItemType.honor ? 10 : null,
      classId: type == CertificateImportItemType.clazz ? 3 : null,
      detectedName: 'Primeros Auxilios',
      completedAt: DateTime(2023, 3, 12),
      status: CertificateImportItemStatus.ready,
      instructor: instructor,
    );

Map<String, dynamic> _json(
  CertificateImportItem item, {
  CertificateImportItem? previous,
}) =>
    CertificateImportItemUpdatePayload.fromItem(item, previous: previous)
        .toJson();

void main() {
  group('instructor in the row payload', () {
    test('a person goes as instructor_user_id only', () {
      final json = _json(_item(instructor: _ana), previous: _item());
      expect(json['instructor_user_id'], _ana.userId);
      expect(json.containsKey('instructor_name'), isFalse);
    });

    test('a typed name goes as instructor_name only', () {
      final json = _json(_item(instructor: _juan), previous: _item());
      expect(json['instructor_name'], 'Juan López');
      expect(json.containsKey('instructor_user_id'), isFalse);
    });

    test('removing it sends null for both, so the API clears the instructor',
        () {
      final json = _json(_item(), previous: _item(instructor: _ana));
      expect(json.containsKey('instructor_user_id'), isTrue);
      expect(json['instructor_user_id'], isNull);
      expect(json.containsKey('instructor_name'), isTrue);
      expect(json['instructor_name'], isNull);
    });

    test('an unchanged instructor is not sent again', () {
      final json =
          _json(_item(instructor: _ana), previous: _item(instructor: _ana));
      expect(json.keys, isNot(contains('instructor_user_id')));
      expect(json.keys, isNot(contains('instructor_name')));
    });

    test('a row that never had one sends nothing (undefined = no change)', () {
      final json = _json(_item(), previous: _item());
      expect(json.keys, isNot(contains('instructor_user_id')));
      expect(json.keys, isNot(contains('instructor_name')));
    });

    test('a new row sends the instructor it was created with', () {
      expect(_json(_item(instructor: _ana))['instructor_user_id'], _ana.userId);
      expect(_json(_item()).keys, isNot(contains('instructor_user_id')));
    });

    test('changing person replaces it', () {
      final json =
          _json(_item(instructor: _juan), previous: _item(instructor: _ana));
      expect(json['instructor_name'], 'Juan López');
      expect(json.keys, isNot(contains('instructor_user_id')));
    });

    test('a class never sends an instructor, not even to clear one', () {
      final json = _json(
        _item(type: CertificateImportItemType.clazz),
        previous: _item(instructor: _ana),
      );
      expect(json['item_type'], 'CLASS');
      expect(json.keys, isNot(contains('instructor_user_id')));
      expect(json.keys, isNot(contains('instructor_name')));
    });
  });
}
