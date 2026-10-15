import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/members/data/datasources/members_remote_data_source.dart';

/// Responde las peticiones en memoria y registra lo que se envió.
class _FakeApi extends Interceptor {
  _FakeApi(this.rolesCatalog);

  final List<Map<String, dynamic>> rolesCatalog;
  final List<RequestOptions> requests = [];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    requests.add(options);
    final data = options.path.endsWith('/catalogs/roles')
        ? rolesCatalog
        : <String, dynamic>{'assignment_id': 'assignment-1'};
    handler.resolve(Response(
      requestOptions: options,
      statusCode: options.method == 'POST' ? 201 : 200,
      data: data,
    ));
  }
}

void main() {
  group('assignClubRole role_id resolution', () {
    Future<_FakeApi> assign(List<Map<String, dynamic>> catalog) async {
      final api = _FakeApi(catalog);
      final dio = Dio()..interceptors.add(api);
      final ds = MembersRemoteDataSourceImpl(dio: dio, baseUrl: 'http://api');

      final ok = await ds.assignClubRole(
        clubId: 1,
        sectionId: 2,
        userId: 'user-1',
        role: 'instructor',
      );

      expect(ok, isTrue);
      return api;
    }

    test('resolves role_id from the normalized catalog `name` field', () async {
      final api = await assign([
        {'role_id': 'role-member', 'name': 'member', 'role_category': 'CLUB'},
        {
          'role_id': 'role-instructor',
          'name': 'instructor',
          'role_category': 'CLUB',
        },
      ]);

      final post = api.requests.singleWhere((r) => r.method == 'POST');
      expect(post.path, 'http://api/clubs/1/sections/2/roles');
      expect((post.data as Map)['role_id'], 'role-instructor');
    });

    test('still accepts the legacy `role_name` field', () async {
      final api = await assign([
        {'role_id': 'role-instructor', 'role_name': 'instructor'},
      ]);

      final post = api.requests.singleWhere((r) => r.method == 'POST');
      expect((post.data as Map)['role_id'], 'role-instructor');
    });
  });

  group('getAssignableRoles', () {
    const payload = {
      'roles': [
        {
          'role_id': 'role-director',
          'role_name': 'director',
          'allowed': false,
          'violation_rule': 1,
          'violation_code': 'CLUB_ROLE_GUIDE_MAJOR_REQUIRED',
        },
        {
          'role_id': 'role-member',
          'role_name': 'member',
          'allowed': true,
          'violation_rule': null,
          'violation_code': null,
        },
      ],
      'guide_major_eligible': false,
      'section_kind': 'CONQUISTADORES',
    };

    Future<(MembersRemoteDataSourceImpl, List<RequestOptions>)> build(
        Object body) async {
      final requests = <RequestOptions>[];
      final dio = Dio()
        ..interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
          requests.add(o);
          h.resolve(Response(requestOptions: o, statusCode: 200, data: body));
        }));
      return (
        MembersRemoteDataSourceImpl(dio: dio, baseUrl: 'http://api'),
        requests
      );
    }

    test('parses roles, eligibility flags and unwraps {data}', () async {
      final (ds, requests) =
          await build({'status': 'success', 'data': payload});

      final result =
          await ds.getAssignableRoles(clubId: 1, sectionId: 2, userId: 'u-1');

      expect(requests.single.path,
          'http://api/clubs/1/sections/2/members/u-1/assignable-roles');
      expect(result.guideMajorEligible, isFalse);
      expect(result.sectionKind, 'CONQUISTADORES');
      expect(result.roles, hasLength(2));
      expect(result.roles.first.roleName, 'director');
      expect(result.roles.first.allowed, isFalse);
      expect(
          result.roles.first.violationCode, 'CLUB_ROLE_GUIDE_MAJOR_REQUIRED');
      expect(result.roles.last.allowed, isTrue);
      expect(result.roles.last.violationCode, isNull);
    });

    test('reuses role_id from the endpoint when assigning (no catalog call)',
        () async {
      final (ds, requests) = await build(payload);
      await ds.getAssignableRoles(clubId: 1, sectionId: 2, userId: 'u-1');

      await ds.assignClubRole(
        clubId: 1,
        sectionId: 2,
        userId: 'u-1',
        role: 'member',
      );

      expect(requests.any((r) => r.path.endsWith('/catalogs/roles')), isFalse);
      final post = requests.singleWhere((r) => r.method == 'POST');
      expect((post.data as Map)['role_id'], 'role-member');
    });
  });
}
