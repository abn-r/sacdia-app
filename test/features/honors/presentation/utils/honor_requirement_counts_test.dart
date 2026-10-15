import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor_requirement.dart';
import 'package:sacdia_app/features/honors/presentation/utils/honor_requirement_counts.dart';

HonorRequirement _req(int id, [List<HonorRequirement> children = const []]) =>
    HonorRequirement(
      id: id,
      honorId: 16,
      requirementNumber: id,
      text: 'Requisito $id',
      hasSubItems: children.isNotEmpty,
      children: children,
    );

void main() {
  test('counts every requirement plus nested sub-items', () {
    final requirements = [
      _req(1),
      _req(2, [_req(21), _req(22), _req(23)]),
      _req(3, [
        _req(31, [_req(311), _req(312)]),
      ]),
    ];

    expect(countRequirementPoints(requirements), 9);
  });

  test('equals the requirement count when there are no sub-items', () {
    expect(countRequirementPoints([_req(1), _req(2)]), 2);
    expect(countRequirementPoints(const []), 0);
  });
}
