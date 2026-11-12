import '../../domain/entities/finance_monthly_series.dart';

/// Parsea la respuesta de `GET /clubs/:clubId/finances/monthly`.
class FinanceMonthlySeriesModel extends FinanceMonthlySeries {
  const FinanceMonthlySeriesModel({required super.items});

  /// [json] es el contenido de `data` (ya sin el envoltorio `{status, data}`).
  /// Ordena por año y mes por si el servidor no lo hiciera.
  factory FinanceMonthlySeriesModel.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    final items = raw is List
        ? raw.whereType<Map<String, dynamic>>().map(_pointFromJson).toList()
        : <FinanceMonthlyPoint>[];
    items.sort((a, b) {
      final cmp = a.year.compareTo(b.year);
      return cmp != 0 ? cmp : a.month.compareTo(b.month);
    });
    return FinanceMonthlySeriesModel(items: items);
  }

  static FinanceMonthlyPoint _pointFromJson(Map<String, dynamic> json) {
    final income = _toDouble(json['income']);
    final expenses = _toDouble(json['expenses']);
    return FinanceMonthlyPoint(
      year: _toInt(json['year']),
      month: _toInt(json['month']),
      income: income,
      expenses: expenses,
      net: json['net'] == null ? income - expenses : _toDouble(json['net']),
      balance: _toDouble(json['balance']),
    );
  }

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

  FinanceMonthlySeries toEntity() => FinanceMonthlySeries(items: items);
}
