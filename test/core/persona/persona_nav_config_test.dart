import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/persona/nav_slot.dart';
import 'package:sacdia_app/core/persona/persona.dart';
import 'package:sacdia_app/core/persona/persona_nav_config.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';

void main() {
  group('personaNavConfig — shape assertions (T-06)', () {
    test('contains an entry for every Persona', () {
      for (final persona in Persona.values) {
        expect(
          personaNavConfig.containsKey(persona),
          isTrue,
          reason: 'personaNavConfig missing key for Persona.$persona',
        );
      }
    });

    for (final persona in Persona.values) {
      group('Persona.$persona', () {
        late List<NavSlot> slots;

        setUp(() {
          slots = personaNavConfig[persona]!;
        });

        test('has exactly 5 slots', () {
          expect(slots.length, 5,
              reason: 'Persona.$persona must have exactly 5 NavSlots');
        });

        test('all slots have a non-empty labelKey', () {
          for (final slot in slots) {
            expect(
              slot.labelKey.isNotEmpty,
              isTrue,
              reason: 'slot with branchIndex=${slot.branchIndex} has empty labelKey',
            );
          }
        });

        test('all slots have a HugeIconData icon (List<List<dynamic>>)', () {
          for (final slot in slots) {
            expect(
              slot.icon,
              isA<HugeIconData>(),
              reason:
                  'slot "${slot.labelKey}" icon is not a valid HugeIconData',
            );
          }
        });

        test('all slots have a non-empty route', () {
          for (final slot in slots) {
            expect(
              slot.route.isNotEmpty,
              isTrue,
              reason: 'slot "${slot.labelKey}" has empty route',
            );
          }
        });

        test('contains an Activities slot (FR-8)', () {
          final activitiesSlots = slots.where(
            (s) => s.badgeSource == NavBadgeSource.activities,
          );
          expect(
            activitiesSlots.isNotEmpty,
            isTrue,
            reason:
                'Persona.$persona must have at least one slot with badgeSource=activities (FR-8)',
          );
        });
      });
    }

    test('branchIndex values in main-shell personas are in range 0–17', () {
      // Coordinator shell uses its own branchIndex (0–4). Main-shell personas
      // must stay within the StatefulShellRoute branches list bounds.
      const mainShellPersonas = [
        Persona.miembro,
        Persona.consejero,
        Persona.director,
        Persona.tesorero,
      ];
      for (final persona in mainShellPersonas) {
        for (final slot in personaNavConfig[persona]!) {
          expect(
            slot.branchIndex,
            inInclusiveRange(0, 17),
            reason:
                'Persona.$persona slot "${slot.labelKey}" has out-of-range branchIndex=${slot.branchIndex}',
          );
        }
      }
    });

    test('coordinator shell branchIndex values are in range 0–4', () {
      for (final slot in personaNavConfig[Persona.coordinador]!) {
        expect(
          slot.branchIndex,
          inInclusiveRange(0, 4),
          reason:
              'Coordinador slot "${slot.labelKey}" has out-of-range branchIndex=${slot.branchIndex}',
        );
      }
    });
  });
}
