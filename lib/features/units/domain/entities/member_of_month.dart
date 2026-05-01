import 'package:easy_localization/easy_localization.dart';

/// Un ganador individual del Miembro del Mes.
///
/// Cuando hay empate, el backend retorna múltiples entradas
/// dentro del mismo [MemberOfMonth].
class MemberOfMonthEntry {
  final String userId;
  final String name;
  final String? photoUrl;
  final int totalPoints;

  const MemberOfMonthEntry({
    required this.userId,
    required this.name,
    this.photoUrl,
    required this.totalPoints,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemberOfMonthEntry && other.userId == userId;

  @override
  int get hashCode => userId.hashCode;
}

/// Resultado del Miembro del Mes para un mes/año y sección dados.
///
/// Si no hubo evaluación para el mes actual, el valor es null en el
/// estado del provider (el card no se renderiza).
///
/// Si hay empate, [members] contiene múltiples entradas.
class MemberOfMonth {
  final int month;
  final int year;
  final List<MemberOfMonthEntry> members;

  const MemberOfMonth({
    required this.month,
    required this.year,
    required this.members,
  });

  /// Nombre del mes localizado (1-indexed).
  String get monthName {
    const keys = [
      '', // 0-indexed padding
      'january', 'february', 'march', 'april',
      'may', 'june', 'july', 'august',
      'september', 'october', 'november', 'december',
    ];
    if (month >= 1 && month <= 12) return tr('common.months.${keys[month]}');
    return tr('common.months.unknown', namedArgs: {'month': '$month'});
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemberOfMonth &&
          other.month == month &&
          other.year == year;

  @override
  int get hashCode => Object.hash(month, year);
}
