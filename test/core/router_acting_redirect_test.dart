import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/config/acting_route_policy.dart';
import 'package:sacdia_app/core/config/route_names.dart';

void main() {
  group('isBlockedWhileActing (FP-56)', () {
    test('Mi familia and all its sub-routes are blocked', () {
      expect(isBlockedWhileActing(RouteNames.family), isTrue);
      expect(isBlockedWhileActing(RouteNames.familyAdd), isTrue);
      expect(isBlockedWhileActing(RouteNames.familyLink), isTrue);
      expect(
          isBlockedWhileActing(RouteNames.familyDetailPath('ana-1')), isTrue);
    });

    test('the dependent can still use the rest of the app', () {
      expect(isBlockedWhileActing(RouteNames.homeDashboard), isFalse);
      expect(isBlockedWhileActing(RouteNames.homeProfile), isFalse);
      expect(isBlockedWhileActing(RouteNames.postRegistration), isFalse);
      expect(isBlockedWhileActing(RouteNames.homeClasses), isFalse);
    });

    test('a path that merely starts with the same letters is not blocked', () {
      expect(isBlockedWhileActing('/familyroom'), isFalse);
      expect(isBlockedWhileActing('/families'), isFalse);
    });

    test('the detail route is declared after the static ones', () {
      expect(RouteNames.familyDetail, '/family/:dependentId');
      expect(RouteNames.familyAdd, isNot(RouteNames.familyDetail));
    });
  });
}
