import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/post_registration/data/datasources/personal_info_remote_data_source.dart';
import 'package:sacdia_app/features/post_registration/data/models/legal_representative_model.dart';

import '../../../support/http_adapters.dart';

const _baseUrl = 'http://localhost:3000/api/v1';

const _representative = LegalRepresentativeModel(
  name: 'Ana',
  paternalSurname: 'Lopez',
  maternalSurname: 'Ruiz',
  phone: '5512345678',
  relationshipTypeId: 'rel-1',
);

({PersonalInfoRemoteDataSourceImpl ds, JsonAdapter adapter}) _build(
  int status,
  Object body,
) {
  final adapter = JsonAdapter(status, body);
  final dio = Dio()..httpClientAdapter = adapter;
  return (
    ds: PersonalInfoRemoteDataSourceImpl(dio: dio, baseUrl: _baseUrl),
    adapter: adapter,
  );
}

Map<String, dynamic> _envelope() => {
      'status': 'success',
      'data': {
        'id': 'rep-uuid',
        'user_id': 'user-1',
        'name': 'Ana',
        'paternal_last_name': 'Lopez',
        'maternal_last_name': null,
        'phone': '5512345678',
        'relationship_type_id': 'rel-1',
        'relationship_types': {'name': 'Madre'},
      },
      'message': 'ok',
    };

void main() {
  group('checkLegalRepresentativeRequired', () {
    test('reads data.required = true', () async {
      final t = _build(200, {
        'status': 'success',
        'data': {'required': true, 'userAge': 12, 'reason': 'menor'},
      });
      expect(await t.ds.checkLegalRepresentativeRequired('user-1'), isTrue);
    });

    test('reads data.required = false', () async {
      final t = _build(200, {
        'status': 'success',
        'data': {'required': false, 'userAge': 30, 'reason': 'mayor'},
      });
      expect(await t.ds.checkLegalRepresentativeRequired('user-1'), isFalse);
    });

    test('throws when required is not a bool', () async {
      final t = _build(200, {
        'status': 'success',
        'data': {'required': 'yes'},
      });
      expect(
        () => t.ds.checkLegalRepresentativeRequired('user-1'),
        throwsException,
      );
    });

    test('throws when the payload has no required flag', () async {
      final t = _build(200, {'status': 'success', 'data': {}});
      expect(
        () => t.ds.checkLegalRepresentativeRequired('user-1'),
        throwsException,
      );
    });
  });

  group('createLegalRepresentative', () {
    test('posts the DTO whitelist and unwraps the envelope', () async {
      final t = _build(201, _envelope());

      final result =
          await t.ds.createLegalRepresentative('user-1', _representative);

      expect(t.adapter.lastRequest?.method, 'POST');
      expect(
        t.adapter.lastRequest?.path,
        '$_baseUrl/users/user-1/legal-representative',
      );
      expect((t.adapter.lastRequest?.data as Map).keys.toSet(), {
        'name',
        'paternal_last_name',
        'maternal_last_name',
        'phone',
        'relationship_type_id',
      });
      expect(result.id, 'rep-uuid');
      expect(result.name, 'Ana');
      expect(result.maternalSurname, '');
      expect(result.relationshipTypeId, 'rel-1');
      expect(result.relationshipTypeName, 'Madre');
    });
  });

  group('updateLegalRepresentative', () {
    test('patches the DTO whitelist and unwraps the envelope', () async {
      final t = _build(200, _envelope());

      final result =
          await t.ds.updateLegalRepresentative('user-1', _representative);

      expect(t.adapter.lastRequest?.method, 'PATCH');
      expect(
        (t.adapter.lastRequest?.data as Map).containsKey('id'),
        isFalse,
      );
      expect(result.id, 'rep-uuid');
      expect(result.relationshipTypeName, 'Madre');
    });
  });

  group('getLegalRepresentative', () {
    test('returns null when the user has no representative', () async {
      final t = _build(200, {
        'status': 'success',
        'data': null,
        'hasLegalRepresentative': false,
      });
      expect(await t.ds.getLegalRepresentative('user-1'), isNull);
    });

    test('parses the row with representative_user and relation', () async {
      final t = _build(200, {
        'status': 'success',
        'data': {
          'id': 'rep-uuid',
          'representative_user_id': 'u-9',
          'name': null,
          'paternal_last_name': null,
          'maternal_last_name': null,
          'phone': null,
          'relationship_type_id': 'rel-3',
          'representative_user': {
            'user_id': 'u-9',
            'name': 'Luis',
            'paternal_last_name': 'Perez',
            'maternal_last_name': null,
          },
          'relationship_types': {
            'relationship_type_id': 'rel-3',
            'name': 'Tutor',
          },
        },
        'hasLegalRepresentative': true,
      });

      final rep = await t.ds.getLegalRepresentative('user-1');

      expect(rep?.name, 'Luis');
      expect(rep?.paternalSurname, 'Perez');
      expect(rep?.relationshipTypeId, 'rel-3');
      expect(rep?.relationshipTypeName, 'Tutor');
    });
  });
}
