import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/members/domain/entities/club_member.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';

void main() {
  ClubMember member({
    required String userId,
    String? currentClass,
    int? currentClassId,
    String? clubRole,
    String? guideMajorClassName,
    bool classCounselorEligible = false,
  }) {
    return ClubMember(
      userId: userId,
      name: userId,
      currentClass: currentClass,
      currentClassId: currentClassId,
      clubRole: clubRole,
      guideMajorClassName: guideMajorClassName,
      classCounselorEligible: classCounselorEligible,
    );
  }

  test('groups members by ascending class ID and keeps no class last', () {
    final grouped = groupMembersByClass(
      [
        member(
          userId: 'explorador-1',
          currentClass: 'Explorador',
          currentClassId: 12,
        ),
        member(
          userId: 'amigo-1',
          currentClass: 'Amigo',
          currentClassId: 2,
        ),
        member(userId: 'sin-id-1', currentClass: 'Sin ID'),
        member(userId: 'guia-1', currentClass: 'Guía', currentClassId: 6),
        member(userId: 'sin-clase-1'),
        member(
          userId: 'amigo-2',
          currentClass: 'Amigo',
          currentClassId: 2,
        ),
      ],
      noClassLabel: 'Sin clase',
      guideMajorsLabel: 'Guías Mayores',
    );

    expect(
      grouped.keys,
      orderedEquals(['Amigo', 'Guía', 'Explorador', 'Sin ID', 'Sin clase']),
    );
    expect(
      grouped['Amigo']!.map((member) => member.userId),
      orderedEquals(['amigo-1', 'amigo-2']),
    );
  });

  test('puts guide majors on the section board after classes', () {
    final grouped = groupMembersByClass(
      [
        member(userId: 'sin-clase'),
        member(
          userId: 'secretario',
          clubRole: 'secretary',
          guideMajorClassName: 'Guía Mayor',
          classCounselorEligible: true,
        ),
        member(
          userId: 'amigo',
          currentClass: 'Amigo',
          currentClassId: 2,
        ),
        member(
          userId: 'consejero',
          clubRole: 'counselor',
          classCounselorEligible: true,
        ),
        member(
          userId: 'miembro-gm',
          clubRole: 'member',
          guideMajorClassName: 'Guía Mayor',
          classCounselorEligible: true,
        ),
        member(
          userId: 'director-amigo',
          clubRole: 'director',
          currentClass: 'Amigo',
          currentClassId: 2,
          guideMajorClassName: 'Guía Mayor',
          classCounselorEligible: true,
        ),
      ],
      noClassLabel: 'Sin clase',
      guideMajorsLabel: 'Guías Mayores',
    );

    expect(
      grouped.keys,
      orderedEquals(['Amigo', 'Guías Mayores', 'Sin clase']),
    );
    expect(
      grouped['Guías Mayores']!.map((member) => member.userId),
      orderedEquals(['secretario', 'consejero']),
    );
    expect(
      grouped['Sin clase']!.map((member) => member.userId),
      orderedEquals(['sin-clase', 'miembro-gm']),
    );
    expect(
      grouped['Amigo']!.map((member) => member.userId),
      orderedEquals(['amigo', 'director-amigo']),
    );
  });

  test('sorts class filter options by minimum catalog id', () {
    final sorted = sortClassFilterOptions(
      const [
        'Guía',
        'Guías Mayores',
        'Amigo',
        'Sin clase',
        'Abeja',
        'Viajero',
        'Zorro',
        'Compañero',
        'Explorador',
        'Orientador',
      ],
      [
        member(userId: 'abeja', currentClass: 'Abeja', currentClassId: 1),
        member(userId: 'guia', currentClass: 'Guía', currentClassId: 6),
        member(
          userId: 'amigo-alto',
          currentClass: 'Amigo',
          currentClassId: 9,
        ),
        member(userId: 'amigo', currentClass: 'Amigo', currentClassId: 2),
        member(userId: 'viajero', currentClass: 'Viajero', currentClassId: 5),
        member(
          userId: 'explorador',
          currentClass: 'Explorador',
          currentClassId: 3,
        ),
        member(
          userId: 'companero',
          currentClass: 'Compañero',
          currentClassId: 2,
        ),
        member(
          userId: 'orientador',
          currentClass: 'Orientador',
          currentClassId: 4,
        ),
        member(userId: 'sin-id', currentClass: 'Zorro'),
      ],
      noClassLabel: 'Sin clase',
      guideMajorsLabel: 'Guías Mayores',
    );

    expect(
      sorted,
      orderedEquals([
        'Abeja',
        'Amigo',
        'Compañero',
        'Explorador',
        'Orientador',
        'Viajero',
        'Guía',
        'Zorro',
        'Guías Mayores',
        'Sin clase',
      ]),
    );
  });

  test('uses the conquistadores order only when class ids are missing', () {
    final sorted = sortClassFilterOptions(
      const [
        'Zorro',
        'Guía',
        'Abeja',
        'Orientador',
        'Viajero',
        'Amigo',
        'Explorador',
        'Compañero',
      ],
      const [],
      noClassLabel: 'Sin clase',
      guideMajorsLabel: 'Guías Mayores',
    );

    expect(
      sorted,
      orderedEquals([
        'Amigo',
        'Compañero',
        'Explorador',
        'Orientador',
        'Viajero',
        'Guía',
        'Abeja',
        'Zorro',
      ]),
    );
  });
}
