import '../../domain/entities/finance_summary.dart';

class FinanceSummaryModel extends FinanceSummary {
  const FinanceSummaryModel({
    required super.totalBalance,
    required super.totalIncome,
    required super.totalExpense,
    required super.monthlyBars,
  });

  factory FinanceSummaryModel.fromJson(Map<String, dynamic> json) {
    final rawBars = json['monthly_summary'] as List<dynamic>? ??
        json['monthlySummary'] as List<dynamic>? ??
        json['monthly'] as List<dynamic>? ??
        [];

    final bars = rawBars
        .map((e) => _barFromJson(e as Map<String, dynamic>))
        .toList();

    return FinanceSummaryModel(
      totalBalance:
          _parseDouble(json['total_balance'] ?? json['totalBalance'] ?? 0),
      totalIncome:
          _parseDouble(json['total_income'] ?? json['totalIncome'] ?? 0),
      totalExpense:
          _parseDouble(json['total_expense'] ?? json['totalExpense'] ?? 0),
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
      );
}
