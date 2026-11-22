import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/certifications/domain/entities/certification.dart';
import 'package:sacdia_app/features/certifications/domain/entities/certification_eligibility.dart';
import 'package:sacdia_app/features/certifications/domain/entities/certification_status.dart';
import 'package:sacdia_app/features/certifications/presentation/providers/certifications_providers.dart';

import '../../../support/l10n_test_support.dart';
import '../../../support/riverpod_test_support.dart';
import 'certification_test_support.dart';

const _published = Certification(
  certificationId: 7,
  name: 'Instructor',
  active: true,
  modulesCount: 8,
);

const _other = Certification(
  certificationId: 8,
  name: 'Director',
  active: true,
  modulesCount: 5,
);

const _draft = Certification(
  certificationId: 9,
  name: 'Sin publicar',
  active: false,
  modulesCount: 1,
);

Right<Failure, CertificationEligibility> _eligible(bool value) =>
    Right(CertificationEligibility(eligible: value));

Future<bool> _access(FakeCertificationsRepository repo) async {
  final container = createTestContainer(overrides: [
    authNotifierProvider.overrideWith(FakeCertificationAuth.new),
    certificationsRepositoryProvider.overrideWithValue(repo),
  ]);
  return container.read(certificationsAccessProvider.future);
}

/// Who sees certifications in Mis clases, Explorar and the profile: someone
/// already enrolled, or eligible for at least one published certification.
void main() {
  setUpAll(loadSpanishTranslations);

  test('an active enrollment is enough, without asking eligibility', () async {
    final repo = FakeCertificationsRepository()
      ..catalog = [_published]
      ..enrollments = [sampleEnrollment()];

    expect(await _access(repo), isTrue);
  });

  test('a withdrawn enrollment does not count', () async {
    final repo = FakeCertificationsRepository()
      ..catalog = [_published]
      ..enrollments = [
        sampleEnrollment(status: CertificationEnrollmentStatus.withdrawn),
      ]
      ..eligibility = {7: _eligible(false)};

    expect(await _access(repo), isFalse);
  });

  test('eligible for any published certification', () async {
    final repo = FakeCertificationsRepository()
      ..catalog = [_published, _other]
      ..eligibility = {7: _eligible(false), 8: _eligible(true)};

    expect(await _access(repo), isTrue);
  });

  test('unpublished certifications are never asked about', () async {
    final repo = FakeCertificationsRepository()
      ..catalog = [_draft]
      ..eligibility = {9: _eligible(true)};

    expect(await _access(repo), isFalse);
  });

  test('not eligible for any and not enrolled: hidden', () async {
    final repo = FakeCertificationsRepository()
      ..catalog = [_published, _other]
      ..eligibility = {7: _eligible(false), 8: _eligible(false)};

    expect(await _access(repo), isFalse);
  });

  test('a failed check is not remembered as «no»', () async {
    final repo = FakeCertificationsRepository()
      ..catalog = [_published, _other]
      ..eligibility = {
        7: _eligible(false),
        8: const Left(ServerFailure(message: 'offline')),
      };

    await expectLater(_access(repo), throwsA(anything));
  });

  test('one eligible certification wins over a failed check', () async {
    final repo = FakeCertificationsRepository()
      ..catalog = [_published, _other]
      ..eligibility = {
        7: const Left(ServerFailure(message: 'offline')),
        8: _eligible(true),
      };

    expect(await _access(repo), isTrue);
  });
}
