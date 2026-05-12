/// Drift guard for [appDestinations] (T-32).
///
/// These tests act as a compile-time + runtime invariant check: they verify
/// that the shared destinations catalog never silently drifts into an
/// inconsistent state (empty list, ungated items, destinations with no
/// navigation target).
///
/// Run with:
///   flutter test test/core/nav/destinations_drift_test.dart
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/nav/destinations.dart';

void main() {
  group('appDestinations drift guard (T-32)', () {
    test('catalog is non-empty', () {
      expect(
        appDestinations,
        isNotEmpty,
        reason: 'appDestinations must contain at least one destination',
      );
    });

    test('every destination has a route target (static OR resolver)', () {
      for (final dest in appDestinations) {
        final hasStaticRoute = dest.route.isNotEmpty;
        final hasResolver = dest.routeResolver != null;
        expect(
          hasStaticRoute || hasResolver,
          isTrue,
          reason:
              '"${dest.labelKey}" has neither a non-empty route nor a routeResolver — '
              'the card/item would be un-navigable',
        );
      }
    });

    test('every destination is gated (requiredPermissions OR requiredRoles)',
        () {
      for (final dest in appDestinations) {
        final hasPermissions = dest.requiredPermissions.isNotEmpty;
        final hasRoles = dest.requiredRoles.isNotEmpty;
        expect(
          hasPermissions || hasRoles,
          isTrue,
          reason:
              '"${dest.labelKey}" has neither requiredPermissions nor requiredRoles — '
              'ungated destinations are visible to all authenticated users, '
              'which is not allowed per project RBAC policy',
        );
      }
    });

    test('no duplicate labelKeys', () {
      final keys = appDestinations.map((d) => d.labelKey).toList();
      final unique = keys.toSet();
      expect(
        keys.length,
        equals(unique.length),
        reason: 'Duplicate labelKey found in appDestinations',
      );
    });
  });
}
