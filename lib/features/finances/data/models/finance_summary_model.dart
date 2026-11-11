import '../../domain/entities/finance_summary.dart';

class FinanceSummaryModel extends FinanceSummary {
  const FinanceSummaryModel({
    required super.totalBalance,
    required super.totalIncome,
    required super.totalExpense,
    required super.monthlyBars,
    super.net,
    super.yearIncome,
    super.yearExpense,
    super.movementCount,
    super.periodClosed,
  });

  factory FinanceSummaryModel.fromJson(Map<String, dynamic> json) {
    final rawBars = json['monthly_summary'] as List<dynamic>? ??
        json['monthlySummary'] as List<dynamic>? ??
        json['monthly'] as List<dynamic>? ??
        [];

    final bars =
        rawBars.map((e) => _barFromJson(e as Map<String, dynamic>)).toList();

    final totalIncome =
        _parseDouble(json['total_income'] ?? json['totalIncome'] ?? 0);
    final totalExpense =
        _parseDouble(json['total_expense'] ?? json['totalExpense'] ?? 0);
    final rawClosed = json['period_closed'] ?? json['periodClosed'];

    return FinanceSummaryModel(
      totalBalance: _parseDouble(
        json['balance'] ?? json['total_balance'] ?? json['totalBalance'] ?? 0,
      ),
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      net: json['net'] == null
          ? totalIncome - totalExpense
          : _parseDouble(json['net']),
      yearIncome: _parseDouble(
        json['year_income'] ?? json['yearIncome'] ?? totalIncome,
      ),
      yearExpense: _parseDouble(
        json['year_expenses'] ??
            json['year_expense'] ??
            json['yearExpenses'] ??
            totalExpense,
      ),
      movementCount:
          _parseInt(json['movement_count'] ?? json['movementCount'] ?? 0),
      periodClosed: rawClosed is bool ? rawClosed : null,
      monthlyBars: bars,
    );
  }

  static MonthlyBar _barFromJson(Map<String, dynamic> json) {
    return MonthlyBar(
      year: _parseInt(json['year'] ?? DateTime.now().year),
      month: _parseInt(json['month'] ?? 1),
      income: _parseDouble(json['income'] ?? json['total_income'] ?? 0),
      expense: _parseDouble(json['expense'] ?? json['total_expense'] ?? 0),
    );
  }

  static int _parseInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static double _parseDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  FinanceSummary toEntity() => FinanceSummary(
        totalBalance: totalBalance,
        totalIncome: totalIncome,
        totalExpense: totalExpense,
        monthlyBars: monthlyBars,
        net: net,
        yearIncome: yearIncome,
        yearExpense: yearExpense,
        movementCount: movementCount,
        periodClosed: periodClosed,
      );
}
