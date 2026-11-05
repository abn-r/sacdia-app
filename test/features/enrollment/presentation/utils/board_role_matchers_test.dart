import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/enrollment/presentation/utils/board_role_matchers.dart';

// Reference implementations: the exact expressions enrollment_form_view.dart
// used before the refactor.
bool _oldDeputy(String? r) {
  final role = r?.toLowerCase().trim() ?? '';
  return role == 'deputy-director' ||
      role.contains('deputy') ||
      role.contains('subdirector');
}

bool _oldSecretary(String? r) => (r?.toLowerCase().trim() ?? '') == 'secretary';

bool _oldTreasurer(String? r) => (r?.toLowerCase().trim() ?? '') == 'treasurer';

bool _oldSecTre(String? r) {
  final role = r?.toLowerCase().trim() ?? '';
  return role == 'secretary_treasurer' ||
      role.contains('secretario_tesorero') ||
      role.contains('secretary-treasurer');
}

bool _oldDirector(String? r) =>
    r?.toLowerCase().contains('director') == true &&
    !r!.toLowerCase().contains('sub') &&
    !r.toLowerCase().contains('vice') &&
    !r.toLowerCase().contains('deputy');

const _inputs = <String?>[
  null,
  '',
  'director',
  'Director',
  'deputy-director',
  'Deputy-Director',
  'deputy_director',
  'deputy director',
  'subdirector',
  'Subdirector',
  'sub-director',
  'vice-director',
  'vicedirector',
  'secretary',
  ' Secretary ',
  'secretario',
  'treasurer',
  'Treasurer',
  'tesorero',
  'secretary-treasurer',
  'secretary_treasurer',
  'Secretary_Treasurer',
  'secretario_tesorero',
  'member',
  'counselor',
  'instructor',
];

void main() {
  group('board role matchers keep the previous behaviour', () {
    for (final input in _inputs) {
      test('input ${input == null ? 'null' : "'$input'"}', () {
        expect(isDeputyDirectorRole(input), _oldDeputy(input));
        expect(isSecretaryRole(input), _oldSecretary(input));
        expect(isTreasurerRole(input), _oldTreasurer(input));
        expect(isSecretaryTreasurerRole(input), _oldSecTre(input));
        expect(isDirectorRole(input), _oldDirector(input));
      });
    }
  });

  test('hyphen/space variants of secretary-treasurer are now accepted', () {
    // Only intentional divergence: normalization makes `secretario-tesorero`
    // equal to the already-accepted `secretario_tesorero`.
    expect(isSecretaryTreasurerRole('secretario-tesorero'), isTrue);
    expect(isSecretaryTreasurerRole('secretary treasurer'), isTrue);
  });

  test('every alias accepted before is still accepted', () {
    expect(isDeputyDirectorRole('deputy-director'), isTrue);
    expect(isDeputyDirectorRole('subdirector'), isTrue);
    expect(isDeputyDirectorRole('deputy_director'), isTrue);
    expect(isSecretaryTreasurerRole('secretary_treasurer'), isTrue);
    expect(isSecretaryTreasurerRole('secretario_tesorero'), isTrue);
    expect(isSecretaryTreasurerRole('secretary-treasurer'), isTrue);
    expect(isDirectorRole('director'), isTrue);
    expect(isDirectorRole('deputy-director'), isFalse);
    expect(isDirectorRole('subdirector'), isFalse);
  });
}
