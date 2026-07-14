import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/models/paginated_result.dart';
import 'package:sacdia_app/core/network/interceptors/error_interceptor.dart';
import 'package:sacdia_app/core/network/network_info.dart';
import 'package:sacdia_app/features/camporees/data/datasources/camporees_remote_data_source.dart';
import 'package:sacdia_app/features/camporees/data/models/camporee_event_model.dart';
import 'package:sacdia_app/features/camporees/data/models/camporee_judge_assignment_model.dart';
import 'package:sacdia_app/features/camporees/data/models/camporee_member_model.dart';
import 'package:sacdia_app/features/camporees/data/models/camporee_model.dart';
import 'package:sacdia_app/features/camporees/data/models/camporee_payment_model.dart';
import 'package:sacdia_app/features/camporees/data/models/camporee_rubric_model.dart';
import 'package:sacdia_app/features/camporees/data/models/camporee_section_registration_model.dart';
import 'package:sacdia_app/features/camporees/data/repositories/camporees_repository_impl.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_section_registration.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_member.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_score_submission.dart';

// ── Stubs ─────────────────────────────────────────────────────────────────────

/// Manually-written stub for [CamporeesRemoteDataSource].
///
/// Only [getCamporeeMembers] has configurable behaviour for these tests;
/// all other methods throw [UnimplementedError] to keep the stub minimal.
class _StubDataSource implements CamporeesRemoteDataSource {
  /// Set this before each test to control what [getCamporeeMembers] returns.
  Object? getMembersResult; // PaginatedResult<CamporeeMemberModel> or Exception
  Object?
      judgeAssignmentsResult; // List<CamporeeJudgeAssignmentModel> or Exception
  Object? rubricsResult; // List<CamporeeRubricModel> or Exception
  Object? submitScoreResult; // null or Exception
  Object? getSectionRegistrationResult;
  Object? registerSectionResult;

  @override
  Future<CamporeeSectionRegistrationModel> getActiveSectionRegistration(
    int camporeeId,
  ) async {
    final r = getSectionRegistrationResult;
    if (r is Exception) throw r;
    return r as CamporeeSectionRegistrationModel;
  }

  @override
  Future<CamporeeSectionRegistrationModel> registerActiveSection(
    int camporeeId,
  ) async {
    final r = registerSectionResult;
    if (r is Exception) throw r;
    return r as CamporeeSectionRegistrationModel;
  }

  @override
  Future<PaginatedResult<CamporeeMemberModel>> getCamporeeMembers(
    int camporeeId, {
    int page = 1,
    int limit = 50,
    String? status,
    CancelToken? cancelToken,
  }) async {
    final r = getMembersResult;
    if (r is Exception) throw r;
    return r as PaginatedResult<CamporeeMemberModel>;
  }

  // ── Unimplemented for this test suite ────────────────────────────────────────

  @override
  Future<List<CamporeeModel>> getCamporees({
    bool? active,
    CancelToken? cancelToken,
  }) =>
      throw UnimplementedError();

  @override
  Future<CamporeeModel> getCamporeeDetail(int camporeeId,
          {CancelToken? cancelToken}) =>
      throw UnimplementedError();

  @override
  Future<List<CamporeeEventModel>> getCamporeeEvents(
    int camporeeId, {
    String camporeeType = 'local',
    CancelToken? cancelToken,
  }) =>
      throw UnimplementedError();

  @override
  Future<CamporeeMemberModel> registerMember(
    int camporeeId, {
    required String userId,
    String? camporeeType,
    String? clubName,
    required int insuranceId,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> removeMember(int camporeeId, String userId) =>
      throw UnimplementedError();

  @override
  Future<CamporeeEnrolledClubModel> enrollClub(int camporeeId) =>
      throw UnimplementedError();

  @override
  Future<List<CamporeeEnrolledClubModel>> getEnrolledClubs(
    int camporeeId, {
    CancelToken? cancelToken,
  }) =>
      throw UnimplementedError();

  @override
  Future<CamporeePaymentModel> createPayment(
    int camporeeId,
    String memberId, {
    required double amount,
    required String paymentType,
    String? reference,
    DateTime? paymentDate,
    String? notes,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<CamporeePaymentModel>> getMemberPayments(
    int camporeeId,
    String memberId, {
    CancelToken? cancelToken,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<CamporeePaymentModel>> getCamporeePayments(
    int camporeeId, {
    CancelToken? cancelToken,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<CamporeeJudgeAssignmentModel>> getMyJudgeAssignments({
    CancelToken? cancelToken,
  }) async {
    final r = judgeAssignmentsResult;
    if (r is Exception) throw r;
    return r as List<CamporeeJudgeAssignmentModel>;
  }

  @override
  Future<List<CamporeeRubricModel>> getCamporeeEventRubrics(
    int eventId, {
    CancelToken? cancelToken,
  }) async {
    final r = rubricsResult;
    if (r is Exception) throw r;
    return r as List<CamporeeRubricModel>;
  }

  @override
  Future<void> submitCamporeeEventScore(
    int eventId,
    int clubSectionId, {
    required CamporeeScoreSubmission submission,
  }) async {
    final r = submitScoreResult;
    if (r is Exception) throw r;
  }
}

/// Stub [NetworkInfo] that always reports connected.
class _AlwaysConnected implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;
}

class _ErrorResponseAdapter implements HttpClientAdapter {
  _ErrorResponseAdapter(this.statusCode);

  final int statusCode;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{"message":"Context authorization denied"}',
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

CamporeesRepositoryImpl _repositoryWithErrorInterceptor(int statusCode) {
  final dio = Dio(BaseOptions(responseType: ResponseType.json));
  dio.httpClientAdapter = _ErrorResponseAdapter(statusCode);
  dio.interceptors.add(ErrorInterceptor());
  return CamporeesRepositoryImpl(
    remoteDataSource: CamporeesRemoteDataSourceImpl(
      dio: dio,
      baseUrl: 'http://localhost:3000',
    ),
    networkInfo: _AlwaysConnected(),
  );
}

// ── Fixtures ──────────────────────────────────────────────────────────────────

CamporeeMemberModel _memberModel({
  int id = 1,
  String userId = 'user-abc',
  String? userName = 'Pedro Gomez',
  bool insuranceVerified = true,
}) =>
    CamporeeMemberModel(
      camporeeMemberId: id,
      userId: userId,
      userName: userName,
      insuranceVerified: insuranceVerified,
      active: true,
    );

PaginatedResult<CamporeeMemberModel> _paginatedModels({
  List<CamporeeMemberModel>? members,
  int total = 1,
}) {
  final list = members ?? [_memberModel()];
  return PaginatedResult<CamporeeMemberModel>(
    data: list,
    meta: PaginationMeta(
      page: 1,
      limit: 50,
      total: total,
      totalPages: 1,
      hasNextPage: false,
      hasPreviousPage: false,
    ),
  );
}

const _sectionRegistrationModel = CamporeeSectionRegistrationModel(
  camporeeId: 7,
  clubId: 12,
  clubName: 'Orión',
  clubSectionId: 44,
  sectionName: 'Conquistadores',
  clubTypeId: 2,
  clubTypeName: 'Conquistadores',
  status: CamporeeSectionRegistrationStatus.registered,
  disposition: CamporeeSectionRegistrationDisposition.open,
  canEnroll: false,
  blockingReason: 'already_enrolled',
  enrollmentId: 91,
  registeredAt: null,
  registeredBy: CamporeeSectionRegistrationActorModel(
    userId: 'director-1',
    displayName: 'Directora Activa',
  ),
);

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late _StubDataSource dataSource;
  late CamporeesRepositoryImpl repository;

  setUp(() {
    dataSource = _StubDataSource();
    repository = CamporeesRepositoryImpl(
      remoteDataSource: dataSource,
      networkInfo: _AlwaysConnected(),
    );
  });

  group('CamporeesRepositoryImpl section registration', () {
    test('returns Right domain entity for GET and POST', () async {
      dataSource.getSectionRegistrationResult = _sectionRegistrationModel;
      dataSource.registerSectionResult = _sectionRegistrationModel;

      final getResult = await repository.getActiveSectionRegistration(7);
      final postResult = await repository.registerActiveSection(7);

      for (final result in [getResult, postResult]) {
        expect(result.isRight(), isTrue);
        result.fold(
          (_) => fail('Expected Right'),
          (registration) {
            expect(registration, isA<CamporeeSectionRegistration>());
            expect(registration.clubSectionId, 44);
            expect(registration.enablesParticipants, isTrue);
          },
        );
      }
    });

    test('maps datasource exceptions with the repository failure pattern',
        () async {
      dataSource.getSectionRegistrationResult = ServerException(
        message: 'Malformed response',
        code: 500,
      );
      dataSource.registerSectionResult = AuthException(
        message: 'Unauthorized',
        code: 401,
      );

      final getResult = await repository.getActiveSectionRegistration(7);
      final postResult = await repository.registerActiveSection(7);

      getResult.fold(
        (failure) {
          expect(failure, isA<ServerFailure>());
          expect(failure.code, 500);
        },
        (_) => fail('Expected Left'),
      );
      postResult.fold(
        (failure) {
          expect(failure, isA<AuthFailure>());
          expect(failure.code, 401);
        },
        (_) => fail('Expected Left'),
      );
    });

    test('maps real intercepted 401 and 403 responses to AuthFailure',
        () async {
      for (final testCase in const [
        (statusCode: 401, register: false),
        (statusCode: 403, register: true),
      ]) {
        final realRepository =
            _repositoryWithErrorInterceptor(testCase.statusCode);

        final result = testCase.register
            ? await realRepository.registerActiveSection(7)
            : await realRepository.getActiveSectionRegistration(7);

        result.fold(
          (failure) {
            expect(failure, isA<AuthFailure>());
            expect(failure.code, testCase.statusCode);
            expect(failure.message, 'Context authorization denied');
          },
          (_) => fail('Expected Left'),
        );
      }
    });

    test('maps contextual connection errors to NetworkFailure', () async {
      dataSource.getSectionRegistrationResult = ConnectionException(
        message: 'Network unavailable',
      );

      final result = await repository.getActiveSectionRegistration(7);

      result.fold(
        (failure) {
          expect(failure, isA<NetworkFailure>());
          expect(failure.message, 'Network unavailable');
        },
        (_) => fail('Expected Left'),
      );
    });

    test('maps contextual validation errors and preserves field details',
        () async {
      dataSource.registerSectionResult = ValidationException(
        message: 'Invalid registration',
        fieldsErrors: const {'camporeeId': 'invalid'},
      );

      final result = await repository.registerActiveSection(7);

      result.fold(
        (failure) {
          expect(failure, isA<ValidationFailure>());
          expect(failure.message, 'Invalid registration');
          expect(
            (failure as ValidationFailure).fieldsErrors,
            const {'camporeeId': 'invalid'},
          );
        },
        (_) => fail('Expected Left'),
      );
    });
  });

  group('CamporeesRepositoryImpl.getCamporeeMembers', () {
    // ── Success ───────────────────────────────────────────────────────────────

    test('returns Right(PaginatedResult<CamporeeMember>) on success', () async {
      dataSource.getMembersResult = _paginatedModels();

      final result = await repository.getCamporeeMembers(1);

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Expected Right'),
        (paginated) {
          expect(paginated.data, hasLength(1));
          expect(paginated.meta.total, 1);
        },
      );
    });

    test('maps model properties to entity correctly', () async {
      dataSource.getMembersResult = _paginatedModels(
        members: [
          _memberModel(
            id: 42,
            userId: 'user-xyz',
            userName: 'Maria Lopez',
            insuranceVerified: false,
          ),
        ],
      );

      final result = await repository.getCamporeeMembers(1);

      final entity = (result as Right).value as PaginatedResult<CamporeeMember>;
      final member = entity.data.first;

      // Verify that the model→entity mapping preserves every field.
      expect(member.camporeeMemberId, 42);
      expect(member.userId, 'user-xyz');
      expect(member.userName, 'Maria Lopez');
      expect(member.insuranceVerified, isFalse);
    });

    test('meta is preserved in the mapped entity result', () async {
      final meta = PaginationMeta(
        page: 2,
        limit: 20,
        total: 45,
        totalPages: 3,
        hasNextPage: true,
        hasPreviousPage: true,
      );
      dataSource.getMembersResult = PaginatedResult<CamporeeMemberModel>(
        data: [_memberModel()],
        meta: meta,
      );

      final result = await repository.getCamporeeMembers(1, page: 2, limit: 20);

      result.fold(
        (_) => fail('Expected Right'),
        (paginated) {
          expect(paginated.meta.page, 2);
          expect(paginated.meta.total, 45);
          expect(paginated.meta.hasNextPage, isTrue);
        },
      );
    });

    // ── Failure — ServerException ─────────────────────────────────────────────

    test('returns Left(ServerFailure) when datasource throws ServerException',
        () async {
      dataSource.getMembersResult = ServerException(
        message: 'Internal server error',
        code: 500,
      );

      final result = await repository.getCamporeeMembers(1);

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) {
          expect(failure, isA<ServerFailure>());
          expect((failure as ServerFailure).message, 'Internal server error');
          expect(failure.code, 500);
        },
        (_) => fail('Expected Left'),
      );
    });

    // ── Failure — AuthException ───────────────────────────────────────────────

    test('returns Left(AuthFailure) when datasource throws AuthException',
        () async {
      dataSource.getMembersResult = AuthException(
        message: 'Unauthorized',
        code: 401,
      );

      final result = await repository.getCamporeeMembers(1);

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) {
          expect(failure, isA<AuthFailure>());
          expect((failure as AuthFailure).code, 401);
        },
        (_) => fail('Expected Left'),
      );
    });

    test('maps NotFoundException through the shared repository mapper',
        () async {
      dataSource.getMembersResult = NotFoundException(
        message: 'Camporee not found',
        code: 404,
      );

      final result = await repository.getCamporeeMembers(1);

      result.fold(
        (failure) {
          expect(failure, isA<NotFoundFailure>());
          expect(failure.message, 'Camporee not found');
          expect(failure.code, 404);
        },
        (_) => fail('Expected Left'),
      );
    });
  });

  group('CamporeesRepositoryImpl camporee scoring', () {
    test('maps primary judge assignments to domain entities', () async {
      dataSource.judgeAssignmentsResult = const [
        CamporeeJudgeAssignmentModel(
          assignmentId: 'assignment-1',
          eventId: 77,
          judgeId: 'judge-1',
          camporeeClubId: 5,
          clubSectionId: 99,
          judgeRole: 'primary',
          active: true,
          eventTitle: 'Nudos',
          canSubmitScore: true,
        ),
      ];

      final result = await repository.getMyJudgeAssignments();

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Expected Right'),
        (assignments) {
          expect(assignments, hasLength(1));
          expect(assignments.first.isPrimary, isTrue);
          expect(assignments.first.canSubmitScore, isTrue);
        },
      );
    });

    test('returns Right(null) when score submission succeeds', () async {
      dataSource.submitScoreResult = null;

      final result = await repository.submitCamporeeEventScore(
        77,
        99,
        submission: const CamporeeScoreSubmission(
          items: [
            CamporeeScoreSubmissionItem(rubricId: 101, awardedPoints: 35),
          ],
        ),
      );

      expect(result.isRight(), isTrue);
    });
  });
}
