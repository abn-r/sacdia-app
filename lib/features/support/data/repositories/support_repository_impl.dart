import 'package:dartz/dartz.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/faq_item.dart';
import '../../domain/entities/support_report.dart';
import '../../domain/repositories/support_repository.dart';
import '../datasources/faq_local_data_source.dart';
import '../datasources/support_remote_data_source.dart';

class SupportRepositoryImpl implements SupportRepository {
  final FaqLocalDataSource faqLocal;
  final SupportRemoteDataSource remote;
  final NetworkInfo networkInfo;

  SupportRepositoryImpl({
    required this.faqLocal,
    required this.remote,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, List<FaqItem>>> loadFaq() async {
    try {
      final items = await faqLocal.loadAll();
      return Right(items);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, SupportReportResult>> submitReport(
    SupportReportDraft draft,
  ) async {
    final online = await networkInfo.isConnected;
    if (!online) {
      return Left(
        ConnectionFailure(
          message: tr('support.errors.no_internet'),
        ),
      );
    }

    try {
      final result = await remote.submitReport(draft);
      return Right(result);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } on ValidationException catch (e) {
      return Left(ValidationFailure(
        message: e.message,
        fieldsErrors: e.fieldsErrors,
      ));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }
}
