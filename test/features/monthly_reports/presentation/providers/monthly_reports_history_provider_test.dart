import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/enrollment/domain/entities/enrollment.dart';
import 'package:sacdia_app/features/enrollment/presentation/providers/enrollment_providers.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';
import 'package:sacdia_app/features/monthly_reports/domain/entities/monthly_report.dart';
import 'package:sacdia_app/features/monthly_reports/presentation/providers/monthly_reports_providers.dart';

const _gmEnrollment = Enrollment(
  id: 12,
  userId: 'director',
  clubSectionId: 1,
  year: 2026,
  meetingDays: [],
  status: EnrollmentStatus.active,
);

final _otherSectionPage = VisibleMonthlyReportsPage(
  total: 1,
  page: 1,
  limit: 20,
  items: const [
    VisibleMonthlyReport(
      id: 'cq-1',
      enrollmentId: 'cq-enrollment',
      month: 9,
      year: 2026,
      status: 'generated',
      clubType: 'Conquistadores',
    ),
  ],
);

MonthlyReport _gmReport(String id, int month, int year) => MonthlyReport(
      id: id,
      enrollmentId: '12',
      month: month,
      year: year,
      status: 'generated',
      clubType: 'Guías Mayores',
      totalMembers: 8,
    );

void main() {
  test('a club role sees the active section enrollment reports', () async {
    final requestedEnrollments = <String>[];
    var visibleReads = 0;
    final container = ProviderContainer(
      overrides: [
        clubContextProvider.overrideWith(
          (ref) async => const ClubContext(
            clubId: 1,
            sectionId: 1,
            roleName: 'director',
          ),
        ),
        currentEnrollmentProvider.overrideWith((ref) async => _gmEnrollment),
        monthlyReportsByEnrollmentProvider.overrideWith((ref, enrollmentId) {
          requestedEnrollments.add(enrollmentId);
          return Future.value([
            _gmReport('gm-1', 1, 2026),
            _gmReport('gm-9', 9, 2026),
            _gmReport('gm-dec', 12, 2025),
          ]);
        }),
        visibleMonthlyReportsProvider.overrideWith((ref) async {
          visibleReads++;
          return _otherSectionPage;
        }),
      ],
    );
    addTearDown(container.dispose);

    final history = await container.read(monthlyReportsHistoryProvider.future);

    expect(requestedEnrollments, ['12']);
    expect(visibleReads, 0);
    expect(history.map((r) => r.id), ['gm-9', 'gm-1', 'gm-dec']);
    expect(history.first.clubType, 'Guías Mayores');
    expect(history.first.memberCount, 8);
  });

  test('a club role without enrollment gets an empty history', () async {
    final container = ProviderContainer(
      overrides: [
        clubContextProvider.overrideWith(
          (ref) async => const ClubContext(clubId: 1, sectionId: 1),
        ),
        currentEnrollmentProvider.overrideWith((ref) async => null),
        visibleMonthlyReportsProvider
            .overrideWith((ref) async => _otherSectionPage),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(monthlyReportsHistoryProvider.future), isEmpty);
  });

  test('without club context the multi-club list is used', () async {
    final container = ProviderContainer(
      overrides: [
        clubContextProvider.overrideWith((ref) async => null),
        visibleMonthlyReportsProvider
            .overrideWith((ref) async => _otherSectionPage),
      ],
    );
    addTearDown(container.dispose);

    final history = await container.read(monthlyReportsHistoryProvider.future);

    expect(history.single.id, 'cq-1');
  });
}
