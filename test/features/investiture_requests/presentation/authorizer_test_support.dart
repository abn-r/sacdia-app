import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/investiture_requests/domain/entities/investiture_request.dart';
import 'package:sacdia_app/features/investiture_requests/domain/entities/person_status.dart';
import 'package:sacdia_app/features/investiture_requests/presentation/providers/investiture_requests_providers.dart';
import 'package:sacdia_app/providers/catalogs_provider.dart';
import 'package:sacdia_app/shared/models/catalogs/ecclesiastical_year_model.dart';

import '../fake_investiture_requests_repository.dart';

class FakeAuthNotifier extends AuthNotifier {
  FakeAuthNotifier(this.user);

  final UserEntity? user;

  @override
  Future<UserEntity?> build() async => user;
}

/// Usuario con un rol global (sin club) para las pantallas del autorizador.
UserEntity globalRoleUser(String role) => UserEntity(
      id: 'u-$role',
      email: '$role@example.com',
      authorization: AuthorizationSnapshot(
        effectivePermissions: const ['clubs:read'],
        globalGrants: [AuthorizationGrant(roleName: role)],
      ),
    );

EcclesiasticalYearModel testYear() => EcclesiasticalYearModel(
      ecclesiasticalYearId: 9,
      name: '2025-2026',
      startDate: DateTime(2025, 1, 1),
      endDate: DateTime(2026, 12, 31),
      active: true,
    );

List<Override> authorizerOverrides(
  FakeInvestitureRequestsRepository repo, {
  String role = 'pastor',
}) =>
    [
      investitureRequestsRepositoryProvider.overrideWithValue(repo),
      authNotifierProvider
          .overrideWith(() => FakeAuthNotifier(globalRoleUser(role))),
      currentEcclesiasticalYearProvider.overrideWith((ref) async => testYear()),
    ];

RequestPerson requestPerson(
  String id,
  String name, {
  PersonStatus status = PersonStatus.pending,
  bool canAuthorize = true,
  int classId = 3,
  String className = 'Amigo',
  DateTime? date,
  String? rejectionReason,
  String? systemReason,
  String? resolvedByName,
}) =>
    RequestPerson(
      personId: id,
      userId: 'user-$id',
      userName: name,
      classId: classId,
      className: className,
      enrollmentId: 100 + id.hashCode % 50,
      investitureDate: date ?? DateTime(2026, 11, 15),
      status: status,
      canAuthorize: canAuthorize,
      rejectionReason: rejectionReason,
      systemReason: systemReason,
      resolvedByName: resolvedByName,
    );

InvestitureRequest authorizerRequest({
  String id = 'r1',
  String club = 'Club Alfa',
  String section = 'Conquistadores',
  String district = 'Norte',
  List<RequestPerson>? people,
  int? pendingCount,
  DateTime? earliest,
}) {
  final list = people ??
      [
        requestPerson('p1', 'Ana Pérez'),
        requestPerson('p2', 'Beto Gómez'),
      ];
  return InvestitureRequest(
    requestId: id,
    clubSectionId: 4,
    ecclesiasticalYearId: 9,
    clubId: 1,
    clubName: club,
    sectionName: section,
    districtName: district,
    pendingCount: pendingCount ??
        list.where((p) => p.status == PersonStatus.pending).length,
    earliestInvestitureDate: earliest ?? DateTime(2026, 11, 15),
    createdAt: DateTime(2026, 10, 1),
    people: list,
  );
}
