import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/providers/catalogs_provider.dart';
import 'package:sacdia_app/shared/models/catalogs/catalogs.dart';

EcclesiasticalYearModel _year(int id, String start, String end, bool active) =>
    EcclesiasticalYearModel(
      ecclesiasticalYearId: id,
      name: start.substring(0, 4),
      startDate: DateTime.parse(start),
      endDate: DateTime.parse(end),
      active: active,
    );

void main() {
  final today = DateTime(2026, 10, 15);

  test('accepts the active year that contains today', () {
    expect(
      isCurrentEcclesiasticalYear(
          _year(1, '2026-01-01', '2026-12-31', true), today),
      isTrue,
    );
  });

  test('rejects a future year cached by the old list fallback', () {
    expect(
      isCurrentEcclesiasticalYear(
          _year(2, '2027-01-01', '2027-12-31', false), today),
      isFalse,
    );
  });

  test('rejects an active year whose dates do not contain today', () {
    expect(
      isCurrentEcclesiasticalYear(
          _year(3, '2025-01-01', '2025-12-31', true), today),
      isFalse,
    );
  });
}
