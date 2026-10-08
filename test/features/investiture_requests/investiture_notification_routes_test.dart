import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/features/investiture_requests/presentation/utils/investiture_notification_routes.dart';

void main() {
  group('isInvestitureResultSource', () {
    test('matches the invested and rejected result sources', () {
      expect(isInvestitureResultSource('investiture:invested'), isTrue);
      expect(isInvestitureResultSource('investiture:rejected'), isTrue);
      expect(isInvestitureResultSource('Investiture:Invested'), isTrue);
    });

    test('ignores any other source', () {
      expect(isInvestitureResultSource(null), isFalse);
      expect(isInvestitureResultSource(''), isFalse);
      expect(isInvestitureResultSource('investiture:pending'), isFalse);
      expect(isInvestitureResultSource('validation:approved'), isFalse);
    });
  });

  group('investitureInboxRoute', () {
    test('sends the board to the section screen', () {
      expect(
        investitureInboxRoute(isBoard: true),
        RouteNames.sectionInvestiture,
      );
    });

    test('sends everyone else to their own investiture list', () {
      expect(
        investitureInboxRoute(isBoard: false),
        RouteNames.ownInvestiture,
      );
    });
  });

  group('investitureResultPushRoute', () {
    test('board audience opens the section screen', () {
      expect(
        investitureResultPushRoute({
          'type': 'investiture_result',
          'audience': 'board',
          'requestId': 'r1',
          'sectionId': '4',
        }),
        RouteNames.sectionInvestiture,
      );
    });

    test('person audience with a class opens that class', () {
      expect(
        investitureResultPushRoute({
          'type': 'investiture_result',
          'audience': 'person',
          'requestId': 'r1',
          'sectionId': '4',
          'classId': '3',
        }),
        '/class/3',
      );
    });

    test('person audience without a class falls back to the own list', () {
      expect(
        investitureResultPushRoute({
          'audience': 'person',
          'requestId': 'r1',
          'sectionId': '4',
        }),
        RouteNames.ownInvestiture,
      );
    });

    test('a malformed class id falls back to the own list', () {
      expect(
        investitureResultPushRoute({'audience': 'person', 'classId': 'x/../y'}),
        RouteNames.ownInvestiture,
      );
    });

    test('an unknown audience falls back to the own list', () {
      expect(
        investitureResultPushRoute({'audience': 'stranger', 'classId': '3'}),
        RouteNames.ownInvestiture,
      );
      expect(investitureResultPushRoute({}), RouteNames.ownInvestiture);
    });
  });
}
