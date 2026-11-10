import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/config/acting_route_policy.dart';
import 'package:sacdia_app/core/config/coordinator_route_access.dart';
import 'package:sacdia_app/core/config/device_route_policy.dart';
import 'package:sacdia_app/core/config/pastor_route_access.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/config/supervised_route_policy.dart';
import 'package:sacdia_app/features/auth/domain/entities/principal_info.dart';
import 'package:sacdia_app/features/service_credentials/presentation/utils/service_credential_form.dart';
import 'package:sacdia_app/features/service_credentials/presentation/utils/service_credential_labels.dart';
import 'package:sacdia_app/features/service_credentials/presentation/utils/service_credentials_access.dart';
import 'package:sacdia_app/features/service_credentials/presentation/widgets/review_decision_sheets.dart';

import '../service_credentials_test_support.dart';

void main() {
  final today = DateTime(2026, 6, 15, 10);

  group('validateServiceCredentialForm', () {
    ServiceCredentialFormErrors validate({
      DateTime? date,
      bool withFile = true,
      String mime = 'application/pdf',
      int size = 1000,
    }) =>
        validateServiceCredentialForm(
          completedAt: date ?? DateTime(2026, 3, 1),
          file: withFile ? localFile(mime: mime, size: size) : null,
          today: today,
        );

    test('a complete form (date and document) is valid', () {
      expect(validate().isEmpty, isTrue);
    });

    test('the date is required and cannot be in the future', () {
      expect(
        validateServiceCredentialForm(
          completedAt: null,
          file: localFile(),
          today: today,
        ).date,
        ServiceCredentialDateError.required,
      );
      expect(
        validate(date: DateTime(2026, 6, 16)).date,
        ServiceCredentialDateError.future,
      );
      // Today is allowed, whatever the time of day.
      expect(validate(date: DateTime(2026, 6, 15)).date, isNull);
    });

    test('the file is required, PDF/JPG/PNG and at most 10 MB', () {
      expect(validate(withFile: false).fileMissing, isTrue);
      expect(validate(mime: 'image/webp').file,
          ServiceCredentialFileProblem.unsupportedType);
      expect(validate(mime: 'image/heic').file,
          ServiceCredentialFileProblem.unsupportedType);
      expect(validate(size: 10 * 1024 * 1024 + 1).file,
          ServiceCredentialFileProblem.tooLarge);
      expect(validate(size: 0).file, ServiceCredentialFileProblem.empty);
      expect(validate(size: 10 * 1024 * 1024).file, isNull);
      expect(validate(mime: 'image/jpeg').file, isNull);
      expect(validate(mime: 'image/png').file, isNull);
    });
  });

  test('a rejection reason needs 5 to 500 characters once trimmed', () {
    expect(isValidRejectionReason(''), isFalse);
    expect(isValidRejectionReason('    ab    '), isFalse);
    expect(isValidRejectionReason('abcd'), isFalse);
    expect(isValidRejectionReason('abcde'), isTrue);
    expect(isValidRejectionReason('a' * 500), isTrue);
    expect(isValidRejectionReason('a' * 501), isFalse);
  });

  group('entry access', () {
    test('adult in their own profile sees Mis constancias', () {
      expect(
        canManageOwnServiceCredentials(adultUser(), isActing: false),
        isTrue,
      );
    });

    test('hidden while acting for a dependent', () {
      expect(
        canManageOwnServiceCredentials(adultUser(), isActing: true),
        isFalse,
      );
      expect(
        canReviewServiceCredentials(
          adultUser(capabilities: [reviewerCapability]),
          isActing: true,
        ),
        isFalse,
      );
    });

    test('hidden for teens, devices, restricted and unknown-age accounts', () {
      for (final user in [
        adultUser(
            kind: PrincipalKind.supervisedUser,
            supervision: SupervisionStatus.active),
        adultUser(
            kind: PrincipalKind.supervisedUser,
            supervision: SupervisionStatus.pendingGuardian),
        adultUser(kind: PrincipalKind.linkedDevice),
        adultUser(kind: PrincipalKind.unknown),
        adultUser(kind: PrincipalKind.ageUnknownUser),
      ]) {
        expect(canManageOwnServiceCredentials(user, isActing: false), isFalse);
        expect(
          canReviewServiceCredentials(
            adultUser(
              capabilities: [reviewerCapability],
              kind: user.principal!.kind,
              supervision: user.principal!.supervision?.status,
            ),
            isActing: false,
          ),
          isFalse,
        );
      }
    });

    test('review needs the capability', () {
      expect(
          canReviewServiceCredentials(adultUser(), isActing: false), isFalse);
      expect(
        canReviewServiceCredentials(
          adultUser(capabilities: ['club.operational_staff']),
          isActing: false,
        ),
        isFalse,
      );
      expect(
        canReviewServiceCredentials(
          adultUser(capabilities: [reviewerCapability]),
          isActing: false,
        ),
        isTrue,
      );
      expect(canReviewServiceCredentials(null, isActing: false), isFalse);
    });

    test('a pastor or coordinator without club has no own credentials', () {
      final pastor =
          adultUser(capabilities: ['admin_panel.pastor_only'], withClub: false);
      final coordinator =
          adultUser(capabilities: ['coordination.hub_view'], withClub: false);
      expect(canManageOwnServiceCredentials(pastor, isActing: false), isFalse);
      expect(canManageOwnServiceCredentials(coordinator, isActing: false),
          isFalse);
    });
  });

  group('route policies', () {
    const mine = RouteNames.serviceCredentials;
    final paths = [
      mine,
      RouteNames.serviceCredentialsNew,
      RouteNames.serviceCredentialsReview,
      RouteNames.serviceCredentialsReviewDetailPath('c1'),
    ];

    test('blocked while acting for a dependent (also by deep link)', () {
      for (final path in paths) {
        expect(isBlockedWhileActing(path), isTrue, reason: path);
      }
      expect(isBlockedWhileActing(RouteNames.homeProfile), isFalse);
    });

    test('blocked for a supervised teen, open for others', () {
      for (final path in paths) {
        expect(isBlockedForActiveTeen(path), isTrue, reason: path);
        expect(isAllowedForPendingTeen(path), isFalse, reason: path);
        expect(isAllowedForDevice(path), isFalse, reason: path);
      }
    });

    test('reviewers without club keep the queue and its detail only', () {
      expect(isCoordinatorAllowedPath(RouteNames.serviceCredentialsReview),
          isTrue);
      expect(
          isCoordinatorAllowedPath(
              RouteNames.serviceCredentialsReviewDetailPath('c1')),
          isTrue);
      expect(isCoordinatorAllowedPath(mine), isFalse);
      expect(isPastorAllowedPath(RouteNames.serviceCredentialsReview), isTrue);
      expect(
          isPastorAllowedPath(
              RouteNames.serviceCredentialsReviewDetailPath('c1')),
          isTrue);
      expect(isPastorAllowedPath(mine), isFalse);
      expect(isPastorAllowedPath('/service-credentials/review/a/b'), isFalse);
    });
  });
}
