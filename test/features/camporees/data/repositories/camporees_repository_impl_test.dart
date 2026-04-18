import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/models/paginated_result.dart';
import 'package:sacdia_app/core/network/network_info.dart';
import 'package:sacdia_app/features/camporees/data/datasources/camporees_remote_data_source.dart';
import 'package:sacdia_app/features/camporees/data/models/camporee_member_model.dart';
import 'package:sacdia_app/features/camporees/data/models/camporee_model.dart';
import 'package:sacdia_app/features/camporees/data/models/camporee_payment_model.dart';
import 'package:sacdia_app/features/camporees/data/repositories/camporees_repository_impl.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_member.dart';

// ── Stubs ─────────────────────────────────────────────────────────────────────

/// Manually-written stub for [CamporeesRemoteDataSource].
///
/// Only [getCamporeeMembers] has configurable behaviour for these tests;
/// all other methods throw [UnimplementedError] to keep the stub minimal.
class _StubDataSource implements CamporeesRemoteDataSource {
  /// Set this before each test to control what [getCamporeeMembers] returns.
  Object? getMembersResult; // PaginatedResult<CamporeeMemberModel> or Exception

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
  Future<CamporeeMemberModel> registerMember(
    int camporeeId, {
    required String userId,
    required String camporeeType,
    String? clubName,
    int? insuranceId,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> removeMember(int camporeeId, String userId) =>
      throw UnimplementedError();

  @override
  Future<CamporeeEnrolledClubModel> enrollClub(
    int camporeeId, {
    required int clubSectionId,
  }) =>
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
}

/// Stub [NetworkInfo] that always reports connected.
class _AlwaysConnected implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;
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
  });
}
