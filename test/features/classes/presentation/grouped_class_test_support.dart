import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/providers/riverpod_aliases.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/usecases/cancellation_token.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/classes/domain/entities/class_counselor_assignment.dart';
import 'package:sacdia_app/features/classes/domain/entities/class_progress_summary.dart';
import 'package:sacdia_app/features/classes/domain/entities/class_requirement.dart';
import 'package:sacdia_app/features/classes/domain/entities/class_module_detail.dart';
import 'package:sacdia_app/features/classes/domain/entities/requirement_evidence.dart';
import 'package:sacdia_app/features/classes/domain/entities/class_with_progress.dart';
import 'package:sacdia_app/features/classes/domain/repositories/classes_repository.dart';
import 'package:sacdia_app/features/classes/presentation/providers/classes_providers.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';

import '../../../support/l10n_test_support.dart';
import '../../../support/riverpod_test_support.dart';

/// Real Spanish copy and Spanish dates ("5 nov"), as the app runs.
Future<void> initGroupedClassL10n() async {
  loadSpanishTranslations();
  await initializeDateFormatting('es');
  Intl.defaultLocale = 'es';
}

const kClubContext = ClubContext(
  clubId: 7,
  sectionId: 3,
  clubTypeId: 2,
  clubTypeName: 'Conquistadores',
);

class FakeAuthNotifier extends AuthNotifier {
  FakeAuthNotifier(this.user);

  final UserEntity? user;

  @override
  Future<UserEntity?> build() async => user;
}

/// A signed-in user with the given [permissions].
UserEntity userWith(List<String> permissions) => UserEntity(
      id: 'u1',
      email: 'u1@example.com',
      postRegisterComplete: true,
      authorization: AuthorizationSnapshot(effectivePermissions: permissions),
    );

/// The director of a section: can read and change class assignments.
final directorUser = userWith(const [
  'club_roles:read',
  'club_roles:assign',
  'club_roles:revoke',
]);

/// A counselor: sees progress but cannot manage assignments.
final counselorUser = userWith(const ['clubs:read']);

/// Every location a stub route was opened at, in order.
class Navigated {
  final List<Uri> locations = [];
  Uri get last => locations.last;
}

/// Mounts [home] under a router that also answers every grouped-class path
/// with a stub, so a test can check where a tap goes without building the
/// destination.
Future<Navigated> pumpGroupedApp(
  WidgetTester tester, {
  required Widget home,
  List<Override> overrides = const [],
  UserEntity? user,
  Size size = const Size(420, 1800),

  /// False when the screen animates forever (a skeleton): pump a few frames.
  bool settle = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final navigated = Navigated();
  Widget stub(GoRouterState state) {
    navigated.locations.add(state.uri);
    return Scaffold(body: Text('STUB ${state.uri.path}'));
  }

  final router = GoRouter(
    initialLocation: '/start',
    routes: [
      GoRoute(path: '/start', builder: (_, __) => home),
      for (final path in const [
        '/home/grouped-class/assign',
        '/home/grouped-class/class/:classId',
        '/home/grouped-class/class/:classId/member/:userId',
        '/home/grouped-class/class/:classId/member/:userId/requirement/:requirementId',
      ])
        GoRoute(path: path, builder: (_, state) => stub(state)),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    testProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(() => FakeAuthNotifier(user)),
        clubContextProvider.overrideWith((ref) async => kClubContext),
        ...overrides,
      ],
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: router,
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }
  return navigated;
}

// ── Fixtures ─────────────────────────────────────────────────────────────────

ClassRequirement requirement(
  int id,
  String name,
  RequirementStatus status, {
  int files = 0,
  String? rejectionReason,
  DateTime? submittedAt,
  DateTime? validatedAt,
  DateTime? rejectedAt,
  String? description,
}) =>
    ClassRequirement(
      id: id,
      name: name,
      moduleId: 1,
      description: description,
      rejectedAt: rejectedAt,
      status: status,
      rejectionReason: rejectionReason,
      submittedAt: submittedAt,
      validatedAt: validatedAt,
      files: [
        for (var i = 0; i < files; i++)
          RequirementEvidence(
            id: '$id-$i',
            url: 'https://example.com/$id-$i.jpg',
            fileName: 'f$i.jpg',
            type: EvidenceFileType.image,
            uploadedByName: 'Ana',
            uploadedAt: DateTime(2026, 11, 1),
          ),
      ],
    );

ClassWithProgress classWithRequirements(
  List<ClassRequirement> requirements, {
  int overallProgress = 40,
  String name = 'Explorador',
}) =>
    ClassWithProgress(
      id: 5,
      name: name,
      clubTypeId: 2,
      overallProgress: overallProgress,
      modules: [
        ClassModuleDetail(
          id: 1,
          name: 'General',
          classId: 5,
          requirements: requirements,
        ),
      ],
    );

ClassCounselorAssignment assignment({
  required String id,
  required String userId,
  required String name,
  required int classId,
  required String className,
  String responsibility = 'primary',
}) =>
    ClassCounselorAssignment(
      assignmentId: id,
      userId: userId,
      clubSectionId: 3,
      classId: classId,
      ecclesiasticalYearId: 12,
      clubRoleAssignmentId: 'cra-$id',
      responsibilityType: responsibility,
      active: true,
      exceptional: false,
      assignedById: 'u1',
      startDate: null,
      endDate: null,
      createdAt: null,
      modifiedAt: null,
      user: ClassCounselorPerson(
        userId: userId,
        name: name,
        paternalLastName: '',
        maternalLastName: '',
        email: '$userId@example.com',
      ),
      assignedBy: const ClassCounselorPerson(
        userId: 'u1',
        name: 'Director',
        paternalLastName: '',
        maternalLastName: '',
        email: 'u1@example.com',
      ),
      clazz: ClassCounselorAssignmentClass(
        classId: classId,
        name: className,
        clubTypeId: 2,
        displayOrder: classId,
      ),
    );

/// Repository that records the counselor assignment calls and answers the
/// rest of them with a failure. [createFailure] makes `create` fail with a
/// business code.
class FakeAssignmentsRepository implements ClassesRepository {
  FakeAssignmentsRepository({this.createFailure});

  final ServerFailure? createFailure;
  final List<String> calls = [];

  @override
  Future<Either<Failure, List<ClassCounselorAssignment>>>
      getClassCounselorAssignments(int clubId, int sectionId,
          {int? yearId,
          int? classId,
          bool? active,
          RequestCancelToken? cancelToken}) async {
    calls.add('list');
    return const Right([]);
  }

  @override
  Future<Either<Failure, ClassCounselorAssignment>>
      createClassCounselorAssignment(
    int clubId,
    int sectionId, {
    required String userId,
    required int classId,
    int? ecclesiasticalYearId,
    String? responsibilityType,
    bool? exceptional,
    String? exceptionReason,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    calls.add('create:$userId:$classId:$responsibilityType');
    final failure = createFailure;
    if (failure != null) return Left(failure);
    return Right(assignment(
      id: 'new',
      userId: userId,
      name: userId,
      classId: classId,
      className: 'Clase',
      responsibility: responsibilityType ?? 'primary',
    ));
  }

  @override
  Future<Either<Failure, ClassCounselorAssignment>>
      revokeClassCounselorAssignment(String assignmentId) async {
    calls.add('revoke:$assignmentId');
    return Right(assignment(
      id: assignmentId,
      userId: 'x',
      name: 'x',
      classId: 1,
      className: 'Clase',
    ));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

const kNoSummary = ClassProgressSummary();

/// Progress of member `x` in class 3 (the one the requirement tests open).
Override classProgressOverride(List<ClassRequirement> requirements) =>
    classWithProgressProvider(
      const ClassProgressQuery(
        classId: 3,
        enrollmentId: 55,
        targetUserId: 'x',
      ),
    ).overrideWith((ref) async => classWithRequirements(requirements));
