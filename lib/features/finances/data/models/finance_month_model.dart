import '../../domain/entities/finance_month.dart';
import '../../domain/entities/transaction.dart';
import 'transaction_model.dart';

class FinanceMonthModel extends FinanceMonth {
  const FinanceMonthModel({
    required super.year,
    required super.month,
    required super.isOpen,
    required super.totalBalance,
    required super.totalIncome,
    required super.totalExpense,
    required super.transactions,
  });

  /// Construye desde la respuesta de [GET /clubs/:id/finances?year=&month=].
  ///
  /// El backend devuelve la lista de movimientos + metadatos calculados.
  factory FinanceMonthModel.fromJson(
    Map<String, dynamic> json, {
    required int year,
    required int month,
  }) {
    final rawList = json['data'] as List<dynamic>? ??
        json['finances'] as List<dynamic>? ??
        (json is List ? json as List<dynamic> : []);

    final transactions = rawList
        .map((e) => FinanceTransactionModel.fromJson(e as Map<String, dynamic>)
            .toEntity())
        .toList();

    // Estadísticas calculadas desde el servidor o computadas localmente.
    final income = _parseDouble(json['total_income'] ?? json['totalIncome']);
    final expense = _parseDouble(json['total_expense'] ?? json['totalExpense']);
    final balance = _parseDouble(json['total_balance'] ?? json['totalBalance'] ?? json['balance']);
    final isOpen = json['is_open'] as bool? ?? json['isOpen'] as bool? ?? true;

    // Si el servidor no proporciona totales, calcularlos.
    final computedIncome = income > 0
        ? income
        : transactions
            .where((t) => t.type == TransactionType.income)
            .fold(0.0, (sum, t) => sum + t.amount);
    final computedExpense = expense > 0
        ? expense
        : transactions
            .where((t) => t.type == TransactionType.expense)
            .fold(0.0, (sum, t) => sum + t.amount);

    return FinanceMonthModel(
      year: year,
      month: month,
      isOpen: isOpen,
      totalBalance: balance,
      totalIncome: computedIncome,
      totalExpense: computedExpense,
      transactions: transactions,
    );
  }

  static double _parseDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  FinanceMonth toEntity() => FinanceMonth(
        year: year,
        month: month,
        isOpen: isOpen,
        totalBalance: totalBalance,
        totalIncome: totalIncome,
        totalExpense: totalExpense,
        transactions: transactions,
      );
}
