import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/network/network_info.dart';
import 'package:sacdia_app/features/rankings/data/datasources/annual_ranking_progress_remote_data_source.dart';
import 'package:sacdia_app/features/rankings/data/models/annual_ranking_progress_model.dart';
import 'package:sacdia_app/features/rankings/data/repositories/annual_ranking_progress_repository_impl.dart';

class _StubDataSource implements AnnualRankingProgressRemoteDataSource {
  Object? result;

  @override
  Future<AnnualRankingProgressModel> getAnnualRankingProgress({
    required int sectionId,
    required int yearId,
    CancelToken? cancelToken,
  }) async {
    final value = result;
    if (value is Exception) throw value;
    return value as AnnualRankingProgressModel;
  }
}

class _AlwaysConnected implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;
}

class _NeverConnected implements NetworkInfo {
  @override
  Future<bool> get isConnected async => false;
}

void main() {
  late _StubDataSource dataSource;
  late AnnualRankingProgressRepositoryImpl repository;

  setUp(() {
    dataSource = _StubDataSource();
    repository = AnnualRankingProgressRepositoryImpl(
      remoteDataSource: dataSource,
      networkInfo: _AlwaysConnected(),
    );
  });

  test('returns Right(AnnualRankingProgress) on success', () async {
    dataSource.result = AnnualRankingProgressModel.fromJson(_progressJson());

    final result = await repository.getAnnualRankingProgress(
      sectionId: 2,
      yearId: 1,
    );

    expect(result.isRight(), isTrue);
    result.fold(
      (_) => fail('Expected Right'),
      (progress) {
        expect(progress.sectionId, 2);
        expect(progress.currentPoints, 7200);
      },
    );
  });

  test('returns Left(AuthFailure) on auth exception', () async {
    dataSource.result = AuthException(message: 'Forbidden', code: 403);

    final result = await repository.getAnnualRankingProgress(
      sectionId: 2,
      yearId: 1,
    );

    expect(result.isLeft(), isTrue);
    result.fold(
      (failure) => expect(failure, isA<AuthFailure>()),
      (_) => fail('Expected Left'),
    );
  });

  test('returns Left(NetworkFailure) when offline', () async {
    final offlineRepo = AnnualRankingProgressRepositoryImpl(
      remoteDataSource: dataSource,
      networkInfo: _NeverConnected(),
    );

    final result = await offlineRepo.getAnnualRankingProgress(
      sectionId: 2,
      yearId: 1,
    );

    expect(result.isLeft(), isTrue);
    result.fold(
      (failure) => expect(failure, isA<NetworkFailure>()),
      (_) => fail('Expected Left'),
    );
  });
}

Map<String, dynamic> _progressJson() => {
      'section_id': 2,
      'club_id': 7,
      'club_name': 'Halcones',
      'club_type': {'club_type_id': 1, 'name': 'Aventureros'},
      'year': {'ecclesiastical_year_id': 1},
      'current_points': 7200,
      'max_points': 10000,
      'progress_percentage': 72,
      'current_tier': null,
      'next_tier': null,
      'components': const [],
      'pending_items': const [],
    };
