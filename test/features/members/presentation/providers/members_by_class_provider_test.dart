import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/members/domain/entities/club_member.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';

void main() {
  ClubMember member({
    required String userId,
    String? currentClass,
    int? currentClassId,
  }) {
    return ClubMember(
      userId: userId,
      name: userId,
      currentClass: currentClass,
      currentClassId: currentClassId,
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
}
