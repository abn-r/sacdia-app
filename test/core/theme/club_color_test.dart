import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/club_type.dart';

void main() {
  group('clubTypeFromName', () {
    group('known club types — exact canonical names', () {
      test('resolves Conquistadores', () {
        expect(clubTypeFromName('Conquistadores'), ClubType.conquistadores);
      });

      test('resolves Aventureros', () {
        expect(clubTypeFromName('Aventureros'), ClubType.aventureros);
      });

      test('resolves Guías Mayores (with accent)', () {
        expect(clubTypeFromName('Guías Mayores'), ClubType.guiasMayores);
      });

      test('resolves Guias Mayores (without accent)', () {
        expect(clubTypeFromName('Guias Mayores'), ClubType.guiasMayores);
      });
    });

    group('case insensitivity', () {
      test('CONQUISTADORES uppercase', () {
        expect(clubTypeFromName('CONQUISTADORES'), ClubType.conquistadores);
      });

      test('aventureros lowercase', () {
        expect(clubTypeFromName('aventureros'), ClubType.aventureros);
      });

      test('GUÍA MAYOR uppercase with accent', () {
        expect(clubTypeFromName('GUÍA MAYOR'), ClubType.guiasMayores);
      });

      test('mixed case Conquistador (singular)', () {
        expect(clubTypeFromName('Conquistador'), ClubType.conquistadores);
      });
    });

    group('whitespace handling', () {
      test('trims leading and trailing spaces', () {
        expect(
          clubTypeFromName('  Conquistadores  '),
          ClubType.conquistadores,
        );
      });

      test('trims spaces around Aventureros', () {
        expect(clubTypeFromName(' aventureros '), ClubType.aventureros);
      });

      test('trims spaces around Guía', () {
        expect(clubTypeFromName(' Guía Mayor '), ClubType.guiasMayores);
      });
    });

    group('fallback for unknown or null input', () {
      test('returns null for null', () {
        expect(clubTypeFromName(null), isNull);
      });

      test('returns null for empty string', () {
        expect(clubTypeFromName(''), isNull);
      });

      test('returns null for whitespace-only string', () {
        expect(clubTypeFromName('   '), isNull);
      });

      test('returns null for an unknown name', () {
        expect(clubTypeFromName('Pathfinders'), isNull);
      });
    });
  });

  group('ClubColorX.color', () {
    test('conquistadores → AppColors.primary', () {
      expect(ClubType.conquistadores.color, AppColors.primary);
    });

    test('aventureros → AppColors.info', () {
      expect(ClubType.aventureros.color, AppColors.info);
    });

    test('guiasMayores → AppColors.secondary', () {
      expect(ClubType.guiasMayores.color, AppColors.secondary);
    });
  });

  group('clubColorFromName — convenience helper', () {
    test('known name returns the correct color', () {
      expect(clubColorFromName('Conquistadores'), AppColors.primary);
      expect(clubColorFromName('Aventureros'), AppColors.info);
      expect(clubColorFromName('Guías Mayores'), AppColors.secondary);
    });

    test('null input falls back to AppColors.primary', () {
      expect(clubColorFromName(null), AppColors.primary);
    });

    test('unknown name falls back to AppColors.primary', () {
      expect(clubColorFromName('UnknownClub'), AppColors.primary);
    });

    test('behavior is identical to original _getClubColor for all known inputs',
        () {
      // This documents the behavioral contract exactly as it was before
      // the refactor: same string in → same Color out.
      final cases = {
        'Conquistadores': AppColors.primary,
        'conquistador': AppColors.primary,
        'CONQUISTADORES': AppColors.primary,
        'Aventureros': AppColors.info,
        'aventurero': AppColors.info,
        'AVENTUREROS': AppColors.info,
        'Guías Mayores': AppColors.secondary,
        'guia mayor': AppColors.secondary,
        'GUÍA': AppColors.secondary,
        'Unknown': AppColors.primary,
        '': AppColors.primary,
      };

      for (final entry in cases.entries) {
        expect(
          clubColorFromName(entry.key),
          entry.value,
          reason: 'Input "${entry.key}" should map to ${entry.value}',
        );
      }
    });
  });
}
