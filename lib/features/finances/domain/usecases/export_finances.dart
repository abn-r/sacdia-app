import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../entities/finance_export.dart';
import '../repositories/finances_repository.dart';

class ExportFinancesParams extends Equatable {
  final int clubId;
  final int year;
  final int month;
  final FinanceExportFormat format;

  const ExportFinancesParams({
    required this.clubId,
    required this.year,
    required this.month,
    required this.format,
  });

  @override
  List<Object?> get props => [clubId, year, month, format];
}

class ExportFinances {
  final FinancesRepository repository;

  ExportFinances(this.repository);

  Future<Either<Failure, FinanceExportFile>> call(
    ExportFinancesParams params, {
    RequestCancelToken? cancelToken,
  }) {
    return repository.exportFinances(
      clubId: params.clubId,
      year: params.year,
      month: params.month,
      format: params.format,
      cancelToken: cancelToken,
    );
  }
}
