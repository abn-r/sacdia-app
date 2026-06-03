import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/profile/presentation/utils/profile_context_resolver.dart';

void main() {
  group('resolveProfileClubType', () {
    test('uses active grant club type over stale profile club type', () {
      final result = resolveProfileClubType(
        profileClubType: 'Conquistadores',
        activeClubTypeName: 'Guías Mayores',
      );

      expect(result, 'Guías Mayores');
    });

    test('falls back to profile club type when active grant is missing', () {
      final result = resolveProfileClubType(
        profileClubType: 'Aventureros',
        activeClubTypeName: null,
      );

      expect(result, 'Aventureros');
    });

    test('ignores blank active grant value', () {
      final result = resolveProfileClubType(
        profileClubType: 'Conquistadores',
        activeClubTypeName: '   ',
      );

      expect(result, 'Conquistadores');
    });
  });
}
