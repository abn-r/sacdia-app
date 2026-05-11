import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/persona/persona.dart';
import 'package:sacdia_app/core/persona/persona_resolver.dart';

void main() {
  group('personaLandingRoute — one assertion per persona (T-05)', () {
    test('Miembro lands on homeDashboard', () {
      expect(personaLandingRoute(Persona.miembro), RouteNames.homeDashboard);
    });

    test('Consejero lands on homeUnits', () {
      expect(personaLandingRoute(Persona.consejero), RouteNames.homeUnits);
    });

    test('Director lands on homeMembers', () {
      expect(personaLandingRoute(Persona.director), RouteNames.homeMembers);
    });

    test('Tesorero lands on homeFinances', () {
      expect(personaLandingRoute(Persona.tesorero), RouteNames.homeFinances);
    });

    test('Coordinador lands on coordinator route', () {
      expect(personaLandingRoute(Persona.coordinador), RouteNames.coordinator);
    });
  });
}
