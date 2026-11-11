import '../../domain/entities/category_breakdown.dart';

/// Parsea la respuesta de `GET /clubs/:clubId/finances/by-category`.
class CategoryBreakdownModel extends CategoryBreakdown {
  const CategoryBreakdownModel({
    required super.period,
    required super.income,
    required super.expenses,
    required super.totalIncome,
    required super.totalExpenses,
  });

  /// [json] es el contenido de `data` (ya sin el envoltorio `{status, data}`).
  factory CategoryBreakdownModel.fromJson(Map<String, dynamic> json) {
    final income = _list(json['income']);
    final expenses = _list(json['expenses']);
    final totals = json['totals'];
    final totalsMap = totals is Map<String, dynamic> ? totals : const {};

    return CategoryBreakdownModel(
      period: (json['period'] ?? '').toString(),
      income: income,
      expenses: expenses,
      totalIncome: totalsMap['income'] == null
          ? _sum(income)
          : _toDouble(totalsMap['income']),
      totalExpenses: totalsMap['expenses'] == null
          ? _sum(expenses)
          : _toDouble(totalsMap['expenses']),
    );
  }

  static List<CategoryTotal> _list(dynamic raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map<String, dynamic>>().map((e) {
      return CategoryTotal(
        categoryId: _toInt(e['category_id'] ?? e['categoryId']),
        name: (e['name'] ?? '').toString(),
        total: _toDouble(e['total']),
        count: _toInt(e['count']),
      );
    }).toList();
  }

  static double _sum(List<CategoryTotal> items) =>
      items.fold(0.0, (sum, e) => sum + e.total);

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static double _toDouble(dynamic v) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  CategoryBreakdown toEntity() => CategoryBreakdown(
        period: period,
        income: income,
        expenses: expenses,
        totalIncome: totalIncome,
        totalExpenses: totalExpenses,
      );
}
