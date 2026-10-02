import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/weekly_record.dart';
import '../../domain/usecases/get_weekly_records.dart';
import 'units_providers.dart';

class UnitPointsHistoryQuery {
  const UnitPointsHistoryQuery({
    required this.clubId,
    required this.unitId,
  });

  final int clubId;
  final int unitId;

  @override
  bool operator ==(Object other) =>
      other is UnitPointsHistoryQuery &&
      other.clubId == clubId &&
      other.unitId == unitId;

  @override
  int get hashCode => Object.hash(clubId, unitId);
}

final unitPointsHistoryProvider = FutureProvider.autoDispose
    .family<List<WeeklyRecord>, UnitPointsHistoryQuery>((ref, query) async {
  final result = await ref.read(getWeeklyRecordsUseCaseProvider).call(
        GetWeeklyRecordsParams(clubId: query.clubId, unitId: query.unitId),
      );
  return result.fold(
    (failure) => throw Exception(failure.message),
    (records) => records,
  );
});
