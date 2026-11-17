import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/config/route_names.dart';

void main() {
  test('class path carries the context in the query', () {
    final uri = Uri.parse(
      RouteNames.groupedClassClassPath(
        3,
        clubId: 7,
        sectionId: 2,
        yearId: 12,
        className: 'Compañero',
      ),
    );
    expect(uri.path, '/home/grouped-class/class/3');
    expect(uri.queryParameters, {
      'clubId': '7',
      'sectionId': '2',
      'yearId': '12',
      'className': 'Compañero',
    });
  });

  test('empty and null query values are left out', () {
    expect(RouteNames.groupedClassAssignPath(), '/home/grouped-class/assign');
    expect(
      RouteNames.groupedClassAssignPath(yearId: 12),
      '/home/grouped-class/assign?yearId=12',
    );
  });

  test('member and requirement paths nest under the class', () {
    final member = Uri.parse(
      RouteNames.groupedClassMemberPath(
        3,
        'u 1',
        clubId: 7,
        sectionId: 2,
        enrollmentId: 55,
        memberName: 'Ana Pérez',
      ),
    );
    expect(member.path, '/home/grouped-class/class/3/member/u%201');
    expect(member.queryParameters['memberName'], 'Ana Pérez');
    expect(member.queryParameters['enrollmentId'], '55');

    final req = Uri.parse(
      RouteNames.groupedClassRequirementPath(3, 'u1', 9, enrollmentId: 55),
    );
    expect(req.path, '/home/grouped-class/class/3/member/u1/requirement/9');
    expect(req.queryParameters, {'enrollmentId': '55'});
  });
}
