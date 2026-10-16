import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/post_registration/data/models/legal_representative_model.dart';

void main() {
  group('LegalRepresentativeModel.fromJson', () {
    test('parses a backend row with relationship_types', () {
      final model = LegalRepresentativeModel.fromJson({
        'id': '9f1c0c7e-0000-4000-8000-000000000001',
        'user_id': 'u-1',
        'name': 'Ana',
        'paternal_last_name': 'Lopez',
        'maternal_last_name': 'Ruiz',
        'phone': '5512345678',
        'relationship_type_id': 'rel-1',
        'relationship_types': {'name': 'Madre'},
      });

      expect(model.id, '9f1c0c7e-0000-4000-8000-000000000001');
      expect(model.name, 'Ana');
      expect(model.paternalSurname, 'Lopez');
      expect(model.maternalSurname, 'Ruiz');
      expect(model.phone, '5512345678');
      expect(model.relationshipTypeId, 'rel-1');
      expect(model.relationshipTypeName, 'Madre');
    });

    test('falls back to representative_user and nested relationship id', () {
      final model = LegalRepresentativeModel.fromJson({
        'id': 'rep-1',
        'name': null,
        'paternal_last_name': null,
        'maternal_last_name': null,
        'phone': null,
        'representative_user': {
          'name': 'Luis',
          'paternal_last_name': 'Perez',
          'maternal_last_name': 'Gomez',
        },
        'relationship_types': {
          'relationship_type_id': 'rel-2',
          'name': 'Padre',
        },
      });

      expect(model.name, 'Luis');
      expect(model.paternalSurname, 'Perez');
      expect(model.maternalSurname, 'Gomez');
      expect(model.phone, '');
      expect(model.relationshipTypeId, 'rel-2');
      expect(model.relationshipTypeName, 'Padre');
    });

    test('does not throw on null maternal surname, phone and relation', () {
      final model = LegalRepresentativeModel.fromJson({
        'name': 'Ana',
        'paternal_last_name': 'Lopez',
        'maternal_last_name': null,
        'phone': null,
        'relationship_type_id': null,
      });

      expect(model.id, isNull);
      expect(model.maternalSurname, '');
      expect(model.phone, '');
      expect(model.relationshipTypeId, '');
      expect(model.relationshipTypeName, isNull);
    });
  });

  group('LegalRepresentativeModel.toJson', () {
    test('sends exactly the backend DTO whitelist', () {
      const model = LegalRepresentativeModel(
        id: 'rep-1',
        name: 'Ana',
        paternalSurname: 'Lopez',
        maternalSurname: 'Ruiz',
        phone: '5512345678',
        relationshipTypeId: 'rel-1',
        relationshipTypeName: 'Madre',
      );

      expect(model.toJson().keys.toSet(), {
        'name',
        'paternal_last_name',
        'maternal_last_name',
        'phone',
        'relationship_type_id',
      });
      expect(model.toJson()['relationship_type_id'], 'rel-1');
    });

    test('omits maternal_last_name when empty and never sends id or type', () {
      const model = LegalRepresentativeModel(
        id: 'rep-1',
        name: 'Ana',
        paternalSurname: 'Lopez',
        maternalSurname: '',
        phone: '5512345678',
        relationshipTypeId: 'rel-1',
      );

      final json = model.toJson();
      expect(json.containsKey('maternal_last_name'), isFalse);
      expect(json.containsKey('id'), isFalse);
      expect(json.containsKey('type'), isFalse);
    });
  });
}
