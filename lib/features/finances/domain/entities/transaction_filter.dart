import 'package:equatable/equatable.dart';

import 'transaction.dart';

/// Preset date ranges for the range bottom sheet.
enum DateRangePreset {
  thisMonth,
  last3Months,
  lastYear,
  custom,
}

/// Immutable value object that holds all active filter state for the
/// All Transactions screen.  Used as the state type for
/// [AllTransactionsFilterNotifier].
class TransactionFilter extends Equatable {
  /// `null` = all types.
  final TransactionType? type;

  /// Full-text search string. `null` or empty = no search applied.
  final String? search;

  /// Which field to sort by: `"date"`, `"amount"`, or `"category"`.
  final String sortBy;

  /// Sort direction: `"asc"` or `"desc"`.
  final String sortOrder;

  final DateRangePreset rangePreset;

  /// Inclusive start date sent as `startDate` query param (`YYYY-MM-DD`).
  final DateTime? startDate;

  /// Inclusive end date sent as `endDate` query param (`YYYY-MM-DD`).
  final DateTime? endDate;

  const TransactionFilter({
    this.type,
    this.search,
    this.sortBy = 'date',
    this.sortOrder = 'desc',
    this.rangePreset = DateRangePreset.thisMonth,
    this.startDate,
    this.endDate,
  });

  TransactionFilter copyWith({
    Object? type = _sentinel,
    Object? search = _sentinel,
    String? sortBy,
    String? sortOrder,
    DateRangePreset? rangePreset,
    Object? startDate = _sentinel,
    Object? endDate = _sentinel,
  }) {
    return TransactionFilter(
      type: type == _sentinel ? this.type : type as TransactionType?,
      search: search == _sentinel ? this.search : search as String?,
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
      rangePreset: rangePreset ?? this.rangePreset,
      startDate:
          startDate == _sentinel ? this.startDate : startDate as DateTime?,
      endDate: endDate == _sentinel ? this.endDate : endDate as DateTime?,
    );
  }

  @override
  List<Object?> get props =>
      [type, search, sortBy, sortOrder, rangePreset, startDate, endDate];
}

/// Sentinel value for optional nullable field overrides in `copyWith`.
const _sentinel = Object();
