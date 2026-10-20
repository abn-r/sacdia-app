import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/config/device_pair_link.dart';
import 'package:sacdia_app/core/config/device_route_policy.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/config/supervised_route_policy.dart';
import 'package:sacdia_app/features/auth/domain/entities/principal_info.dart';

void main() {
  group('device allowlist', () {
    test('the shell tabs, details and the inbox are reachable', () {
      for (final path in [
        RouteNames.deviceHome,
        RouteNames.deviceClasses,
        RouteNames.deviceClassDetailPath(3),
        RouteNames.deviceRequirementPath(3, 9),
        RouteNames.deviceAgenda,
        RouteNames.deviceActivityDetailPath(12),
        RouteNames.deviceInbox,
        RouteNames.notificationsInbox,
      ]) {
        expect(
          deviceRouteRedirect(
            path: path,
            legalPending: false,
            needsRegistration: false,
          ),
          isNull,
          reason: path,
        );
      }
    });

    test('everything an account has goes back to the device home', () {
      for (final path in [
        RouteNames.homeDashboard,
        RouteNames.homeClasses,
        RouteNames.homeActivities,
        RouteNames.homeProfile,
        RouteNames.homeHonors,
        RouteNames.homeMembers,
        RouteNames.homeUnits,
        RouteNames.family,
        RouteNames.familyAdd,
        RouteNames.familyDetailPath('d1'),
        RouteNames.familyPairDevicePath('d1'),
        RouteNames.login,
        RouteNames.register,
        RouteNames.forgotPassword,
        RouteNames.postRegistration,
        RouteNames.legalAcceptance,
        RouteNames.teenPendingHome,
        RouteNames.restrictedAccount,
        RouteNames.devicePair,
        '/security/sessions',
        '/sessions',
        '/mfa',
        '/delete-account',
        '/data-export',
        '/device', // sin sub-ruta
        '/devices/x', // prefijo parecido
      ]) {
        expect(
          deviceRouteRedirect(
            path: path,
            legalPending: false,
            needsRegistration: false,
          ),
          RouteNames.deviceHome,
          reason: path,
        );
      }
    });

    test('pending terms block every route, including the shell', () {
      for (final path in [
        RouteNames.deviceHome,
        RouteNames.deviceClasses,
        RouteNames.deviceInbox,
        RouteNames.familyAdd,
      ]) {
        expect(
          deviceRouteRedirect(
            path: path,
            legalPending: true,
            needsRegistration: false,
          ),
          RouteNames.deviceLegalBlock,
          reason: path,
        );
      }
      expect(
        deviceRouteRedirect(
          path: RouteNames.deviceLegalBlock,
          legalPending: true,
          needsRegistration: false,
        ),
        isNull,
      );
    });

    test('an incomplete registration never reaches post-registration', () {
      expect(
        deviceRouteRedirect(
          path: RouteNames.postRegistration,
          legalPending: false,
          needsRegistration: true,
        ),
        RouteNames.deviceRegistrationPending,
      );
      expect(
        deviceRouteRedirect(
          path: RouteNames.deviceHome,
          legalPending: false,
          needsRegistration: true,
        ),
        RouteNames.deviceRegistrationPending,
      );
      expect(
        deviceRouteRedirect(
          path: RouteNames.deviceRegistrationPending,
          legalPending: false,
          needsRegistration: true,
        ),
        isNull,
      );
    });

    test('the blocking screens are not destinations without their cause', () {
      for (final path in [
        RouteNames.deviceLegalBlock,
        RouteNames.deviceRegistrationPending,
      ]) {
        expect(
          deviceRouteRedirect(
            path: path,
            legalPending: false,
            needsRegistration: false,
          ),
          RouteNames.deviceHome,
          reason: path,
        );
      }
    });

    test('trailing slashes are ignored', () {
      expect(
        deviceRouteRedirect(
          path: '${RouteNames.deviceClasses}/',
          legalPending: false,
          needsRegistration: false,
        ),
        isNull,
      );
    });
  });

  group('device home targets', () {
    test('terms > registration > home', () {
      expect(deviceHomeFor(legalPending: true, needsRegistration: true),
          RouteNames.deviceLegalBlock);
      expect(deviceHomeFor(legalPending: false, needsRegistration: true),
          RouteNames.deviceRegistrationPending);
      expect(deviceHomeFor(legalPending: false, needsRegistration: false),
          RouteNames.deviceHome);
    });

    test('accountHomeFor and supervisedRouteRedirect agree for the device', () {
      expect(
        accountHomeFor(AccountMode.linkedDevice, needsPostRegistration: false),
        RouteNames.deviceHome,
      );
      expect(
        accountHomeFor(AccountMode.linkedDevice, needsPostRegistration: true),
        RouteNames.deviceRegistrationPending,
      );
      expect(
        supervisedRouteRedirect(
          mode: AccountMode.linkedDevice,
          path: RouteNames.homeDashboard,
          needsPostRegistration: false,
        ),
        RouteNames.deviceHome,
      );
    });
  });

  group('accounts cannot enter the device shell', () {
    test('/device/* goes home for adults and active teens', () {
      for (final mode in [AccountMode.adult, AccountMode.teenSupervised]) {
        for (final path in [
          RouteNames.deviceHome,
          RouteNames.deviceClassDetailPath(1),
          RouteNames.deviceInbox,
        ]) {
          expect(
            supervisedRouteRedirect(
              mode: mode,
              path: path,
              needsPostRegistration: false,
            ),
            RouteNames.homeDashboard,
            reason: '$mode $path',
          );
        }
        // La pantalla de vinculación la abre cualquiera (para negarse).
        expect(
          supervisedRouteRedirect(
            mode: mode,
            path: RouteNames.devicePair,
            needsPostRegistration: false,
          ),
          isNull,
        );
      }
    });

    test('pending teens and restricted accounts also bounce', () {
      expect(
        supervisedRouteRedirect(
          mode: AccountMode.teenPending,
          path: RouteNames.deviceHome,
          needsPostRegistration: false,
        ),
        RouteNames.teenPendingHome,
      );
      expect(
        supervisedRouteRedirect(
          mode: AccountMode.restricted,
          path: RouteNames.deviceHome,
          needsPostRegistration: false,
        ),
        RouteNames.restrictedAccount,
      );
    });
  });

  group('pairing links', () {
    test('accepts both c (spec) and t (design) and rejects look-alikes', () {
      expect(pairingTokenFromUri(Uri.parse('sacdia://pair?c=AbC_-123')),
          'AbC_-123');
      expect(pairingTokenFromUri(Uri.parse('sacdia://pair?t=AbC_-123')),
          'AbC_-123');
      expect(pairingTokenFromUri(Uri.parse('sacdia:///pair?c=zzz')), 'zzz');
      expect(pairingTokenFromUri(Uri.parse('SACDIA://PAIR?c=zzz')), 'zzz');

      expect(pairingTokenFromUri(Uri.parse('sacdia://pair')), isNull);
      expect(pairingTokenFromUri(Uri.parse('sacdia://pair?c=')), isNull);
      expect(pairingTokenFromUri(Uri.parse('sacdia://pair?c=a%20b')), isNull);
      expect(pairingTokenFromUri(Uri.parse('sacdia://other?c=zzz')), isNull);
      expect(pairingTokenFromUri(Uri.parse('https://pair?c=zzz')), isNull);
      expect(pairingTokenFromUri(Uri.parse('/pair?c=zzz')), isNull);
      expect(pairingTokenFromUri(Uri.parse('/')), isNull);
    });

    test('rejects an over-long or non-base64url token', () {
      expect(normalizePairingToken('a' * 257), isNull);
      expect(normalizePairingToken('a' * 256), isNotNull);
      expect(normalizePairingToken('abc def'), isNull);
      expect(normalizePairingToken('abc/def'), isNull);
      expect(normalizePairingToken('  abc  '), 'abc');
      expect(normalizePairingToken(null), isNull);
    });
  });
}
