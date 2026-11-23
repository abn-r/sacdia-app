import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/auth/data/models/user_model.dart';

void main() {
  group('UserModel grant parsing', () {
    test('reads the local field of the club and keeps it through the cache',
        () {
      final original = UserModel.fromCustomApi({
        'user_id': 'user-1',
        'email': 'user@example.com',
        'authorization': {
          'grants': {
            'global_roles': [],
            'club_assignments': [
              {
                'assignment_id': 'assignment-1',
                'role_name': 'member',
                'club': {'club_id': 12, 'club_name': 'Estella'},
                'section': {'club_section_id': 164, 'club_type_id': 3},
                'scope': {
                  'local_field': {
                    'id': 4,
                    'name': 'Asociación Centro de Veracruz',
                  },
                },
              },
            ],
          },
          'active_assignment': {'assignment_id': 'assignment-1'},
        },
      });

      for (final user in [original, UserModel.fromJson(original.toJson())]) {
        final grant = user.authorization!.clubAssignments.single;
        expect(grant.localFieldId, 4);
        expect(grant.localFieldName, 'Asociación Centro de Veracruz');
      }
    });

    test('should parse club_name from nested club object', () {
      final user = UserModel.fromCustomApi({
        'user_id': 'user-1',
        'email': 'user@example.com',
        'authorization': {
          'grants': {
            'global_roles': [],
            'club_assignments': [
              {
                'assignment_id': 'assignment-1',
                'role_name': 'director',
                'permissions': <String>[],
                'club': {
                  'club_id': 25,
                  'club_name': 'ACV',
                },
                'section': {
                  'club_section_id': 10,
                  'club_type_id': 2,
                  'club_type_name': 'Conquistadores',
                },
                'status': 'active',
              },
            ],
          },
          'active_assignment': {'assignment_id': 'assignment-1'},
        },
      });

      final grant = user.authorization!.clubAssignments.single;

      expect(grant.clubName, 'ACV');
      expect(grant.clubId, 25);
      expect(grant.clubTypeName, 'Conquistadores');
    });

    test('should round-trip club_name through toJson/fromJson', () {
      final original = UserModel.fromCustomApi({
        'user_id': 'user-1',
        'email': 'user@example.com',
        'authorization': {
          'grants': {
            'global_roles': [],
            'club_assignments': [
              {
                'assignment_id': 'assignment-1',
                'role_name': 'director',
                'club': {
                  'club_id': 25,
                  'club_name': 'ACV',
                },
                'section': {
                  'club_section_id': 10,
                  'club_type_name': 'Conquistadores',
                },
              },
            ],
          },
          'active_assignment': {'assignment_id': 'assignment-1'},
        },
      });

      final restored = UserModel.fromJson(original.toJson());
      final grant = restored.authorization!.clubAssignments.single;

      expect(grant.clubName, 'ACV');
      expect(grant.clubTypeName, 'Conquistadores');
    });
  });
}
