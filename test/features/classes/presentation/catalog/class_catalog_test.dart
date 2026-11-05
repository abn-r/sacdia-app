import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/classes/domain/entities/progressive_class.dart';
import 'package:sacdia_app/features/classes/presentation/catalog/class_catalog.dart';

ProgressiveClass _cls(int id, String name, int type, int? age) =>
    ProgressiveClass(id: id, name: name, clubTypeId: type, minimumAge: age);

ProgressiveClass _enrolled(
  int id,
  String status, {
  String? year,
  DateTime? investedAt,
}) =>
    ProgressiveClass(
      id: id,
      name: 'class $id',
      clubTypeId: 0,
      investitureStatus: status,
      ecclesiasticalYearLabel: year,
      investitureDate: investedAt,
    );

final _catalog = [
  // Backend order: club type, then display order. GM arrives first here to
  // prove the screen reorders club types.
  _cls(13, 'Guía Mayor', 3, 16),
  _cls(14, 'Guía Avanzado', 3, 18),
  _cls(1, 'Corderitos', 1, 6),
  _cls(2, 'Aves Madrugadoras', 1, 6),
  _cls(3, 'Abejitas Industriosas', 1, 7),
  _cls(7, 'Amigo', 2, 10),
  _cls(12, 'Guía', 2, 15),
];

void main() {
  test('groups by club type in Aventureros, Conquistadores, GM order', () {
    final sections = buildClassCatalog(catalog: _catalog, enrolled: const []);

    expect(sections.map((s) => s.clubTypeId), [1, 2, 3]);
    expect(sections.first.entries.map((e) => e.name),
        ['Corderitos', 'Aves Madrugadoras', 'Abejitas Industriosas']);
  });

  test('a class runs until the next class that starts older', () {
    final sections = buildClassCatalog(catalog: _catalog, enrolled: const []);
    final all = [for (final s in sections) ...s.entries];
    int? maxOf(String name) => all.firstWhere((e) => e.name == name).maxAge;

    expect(maxOf('Corderitos'), 6); // next older is Abejitas (7)
    expect(maxOf('Aves Madrugadoras'), 6);
    expect(maxOf('Abejitas Industriosas'), 9); // next is Amigo (10)
    expect(maxOf('Guía'), 15); // next is Guía Mayor (16)
    expect(maxOf('Guía Mayor'), 17);
    expect(maxOf('Guía Avanzado'), isNull); // last: open-ended
    expect(sections.last.minAge, 16);
    expect(sections.last.maxAge, isNull);
  });

  test('statuses: invested year wins, then the newest enrollment', () {
    final sections = buildClassCatalog(catalog: _catalog, enrolled: [
      // Newest first, as GET /users/:id/classes returns them.
      _enrolled(12, 'IN_PROGRESS', year: '2026'),
      _enrolled(7, 'INVESTIDO',
          year: '2024', investedAt: DateTime(2024, 11, 2)),
      _enrolled(3, 'INVESTIDO', year: '2019–2020'),
      _enrolled(2, 'EXPIRED', year: '2018'),
      _enrolled(1, 'EXPIRED', year: '2017'),
      _enrolled(1, 'INVESTIDO', year: '2016'),
    ]);
    final byId = {
      for (final s in sections)
        for (final e in s.entries) e.classId: e,
    };

    expect(byId[12]!.status, ClassCatalogStatus.inProgress);
    expect(byId[12]!.year, '2026');
    expect(byId[7]!.status, ClassCatalogStatus.invested);
    expect(byId[7]!.year, '2024');
    // No investiture date: last year of the ecclesiastical year.
    expect(byId[3]!.year, '2020');
    expect(byId[2]!.status, ClassCatalogStatus.expired);
    // An older invested enrollment beats a newer expired one.
    expect(byId[1]!.status, ClassCatalogStatus.invested);
    expect(byId[1]!.year, '2016');
    expect(byId[13]!.status, ClassCatalogStatus.notInvested);
    expect(byId[13]!.year, isNull);
  });

  test('the current class is the newest enrollment that is not expired', () {
    final enrolled = [
      _enrolled(12, 'EXPIRED', year: '2026'),
      _enrolled(7, 'INVESTIDO', year: '2025'),
    ];
    final sections = buildClassCatalog(catalog: _catalog, enrolled: enrolled);
    final current = [
      for (final s in sections) ...s.entries.where((e) => e.isCurrent),
    ];

    expect(currentClassOf(enrolled)?.id, 7);
    expect(current.map((e) => e.classId), [7]);
  });

  test('no enrollments: nothing is current', () {
    final sections = buildClassCatalog(catalog: _catalog, enrolled: const []);
    expect(
      sections.expand((s) => s.entries).where((e) => e.isCurrent),
      isEmpty,
    );
  });
}
