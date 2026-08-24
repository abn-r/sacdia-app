import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/features/classes/data/datasources/classes_remote_data_source.dart';

void main() {
  group('ClassesRemoteDataSourceImpl', () {
    test('requests progress-scope with yearId and parses minimal response',
        () async {
      late RequestOptions captured;
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            captured = options;
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: const {
                  'club_section_id': 44,
                  'club_type_id': 2,
                  'ecclesiastical_year_id': 2026,
                  'access_level': 'section',
                  'classes': [
                    {
                      'class_id': 13,
                      'name': 'Guía',
                      'club_type_id': 2,
                      'access_level': 'section',
                    },
                  ],
                },
              ),
            );
          },
        ),
      );

      final dataSource = ClassesRemoteDataSourceImpl(
        dio: dio,
        baseUrl: 'https://api.test/api/v1',
      );

      final result = await dataSource.getProgressScope(
        10,
        44,
        yearId: 2026,
      );

      expect(captured.path,
          'https://api.test/api/v1/clubs/10/sections/44/classes/progress-scope');
      expect(captured.queryParameters, equals({'yearId': 2026}));
      expect(result.clubSectionId, 44);
      expect(result.accessLevel, 'section');
      expect(result.classes.single.classId, 13);
    });

    test('requests members-progress with yearId and parses minimal response',
        () async {
      late RequestOptions captured;
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            captured = options;
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: const {
                  'club_section_id': 44,
                  'club_type_id': 2,
                  'class_id': 13,
                  'ecclesiastical_year_id': 2026,
                  'access_level': 'assigned',
                  'members': [
                    {
                      'user_id': 'user-1',
                      'name': 'Ana Pérez',
                      'enrollment_id': 901,
                      'class_id': 13,
                      'ecclesiastical_year_id': 2026,
                      'investiture_status': 'PENDING',
                      'completed_sections': 2,
                      'total_sections': 5,
                      'overall_progress': 40,
                    },
                  ],
                },
              ),
            );
          },
        ),
      );

      final dataSource = ClassesRemoteDataSourceImpl(
        dio: dio,
        baseUrl: 'https://api.test/api/v1',
      );

      final result = await dataSource.getClassMembersProgress(
        10,
        44,
        13,
        yearId: 2026,
      );

      expect(captured.path,
          'https://api.test/api/v1/clubs/10/sections/44/classes/13/members-progress');
      expect(captured.queryParameters, equals({'yearId': 2026}));
      expect(result.classId, 13);
      expect(result.members.single.name, 'Ana Pérez');
      expect(result.members.single.overallProgress, 40);
    });

    test('passes enrollmentId as query param when fetching progress detail',
        () async {
      late RequestOptions captured;
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            captured = options;
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: const {
                  'class_id': 13,
                  'class_name': 'Guía',
                  'club_type_id': 2,
                  'enrollment_id': 901,
                  'modules': <dynamic>[],
                },
              ),
            );
          },
        ),
      );

      final dataSource = ClassesRemoteDataSourceImpl(
        dio: dio,
        baseUrl: 'https://api.test/api/v1',
      );

      await dataSource.getClassWithProgress(
        '104a2549-2056-4b9b-aaeb-51d8fd43191d',
        13,
        enrollmentId: 901,
      );

      expect(captured.path,
          'https://api.test/api/v1/users/104a2549-2056-4b9b-aaeb-51d8fd43191d/classes/13/progress');
      expect(captured.queryParameters, containsPair('enrollmentId', 901));
    });

    test(
        'requests class counselor assignments with filters and parses response payload',
        () async {
      late RequestOptions captured;
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            captured = options;
            handler.resolve(
              Response<List<dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: [
                  {
                    'assignment_id': 'assign-1',
                    'user_id': 'user-1',
                    'club_section_id': 44,
                    'class_id': 13,
                    'ecclesiastical_year_id': 2026,
                    'club_role_assignment_id': 'cra-1',
                    'responsibility_type': 'primary',
                    'active': true,
                    'exceptional': false,
                    'exception_reason': null,
                    'assigned_by_id': 'admin-1',
                    'start_date': '2026-01-10T08:00:00.000Z',
                    'end_date': null,
                    'created_at': '2026-01-01T08:00:00.000Z',
                    'modified_at': '2026-01-01T08:00:00.000Z',
                    'users': {
                      'user_id': 'user-1',
                      'name': 'Ana',
                      'paternal_last_name': 'Perez',
                      'maternal_last_name': 'Lopez',
                      'email': 'ana@example.com',
                    },
                    'assigned_by': {
                      'user_id': 'admin-1',
                      'name': 'Juan',
                      'paternal_last_name': 'Boss',
                      'maternal_last_name': 'Principal',
                      'email': 'juan@example.com',
                    },
                    'classes': {
                      'class_id': 13,
                      'name': 'Guía',
                      'club_type_id': 2,
                      'display_order': 3,
                    },
                    'club_role_assignments': {
                      'assignment_id': 'cra-1',
                      'roles': {'role_name': 'counselor'},
                    },
                  },
                ],
              ),
            );
          },
        ),
      );

      final dataSource = ClassesRemoteDataSourceImpl(
        dio: dio,
        baseUrl: 'https://api.test/api/v1',
      );

      final result = await dataSource.getClassCounselorAssignments(
        10,
        44,
        yearId: 2026,
        classId: 13,
        active: false,
      );

      expect(captured.path,
          'https://api.test/api/v1/clubs/10/sections/44/class-counselor-assignments');
      expect(captured.queryParameters,
          equals({'yearId': 2026, 'classId': 13, 'active': false}));
      expect(result, hasLength(1));
      expect(result.single.assignmentId, 'assign-1');
      expect(result.single.user.userId, 'user-1');
      expect(result.single.clazz.name, 'Guía');
      expect(result.single.classRoleAssignment?.roleName, 'counselor');
    });

    test('creates class counselor assignment with expected payload', () async {
      late RequestOptions captured;
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            captured = options;
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 201,
                data: {
                  'assignment_id': 'assign-1',
                  'user_id': 'user-1',
                  'club_section_id': 44,
                  'class_id': 13,
                  'ecclesiastical_year_id': 2026,
                  'club_role_assignment_id': 'cra-1',
                  'responsibility_type': 'primary',
                  'active': true,
                  'exceptional': true,
                  'exception_reason': 'Coverage',
                  'assigned_by_id': 'admin-1',
                  'start_date': '2026-01-10T08:00:00.000Z',
                  'end_date': '2026-06-10T08:00:00.000Z',
                  'created_at': '2026-01-01T08:00:00.000Z',
                  'modified_at': '2026-01-01T09:00:00.000Z',
                  'users': {
                    'user_id': 'user-1',
                    'name': 'Ana',
                    'paternal_last_name': 'Perez',
                    'maternal_last_name': 'Lopez',
                    'email': 'ana@example.com',
                  },
                  'assigned_by': {
                    'user_id': 'admin-1',
                    'name': 'Juan',
                    'paternal_last_name': 'Boss',
                    'maternal_last_name': 'Principal',
                    'email': 'juan@example.com',
                  },
                  'classes': {
                    'class_id': 13,
                    'name': 'Guía',
                    'club_type_id': 2,
                    'display_order': 3,
                  },
                  'club_role_assignments': {
                    'assignment_id': 'cra-1',
                    'roles': {'role_name': 'counselor'},
                  },
                },
              ),
            );
          },
        ),
      );

      final dataSource = ClassesRemoteDataSourceImpl(
        dio: dio,
        baseUrl: 'https://api.test/api/v1',
      );

      await dataSource.createClassCounselorAssignment(
        10,
        44,
        userId: 'user-1',
        classId: 13,
        ecclesiasticalYearId: 2026,
        responsibilityType: 'assistant',
        exceptional: true,
        exceptionReason: 'Coverage',
        startDate: DateTime.parse('2026-01-10T08:00:00.000Z'),
        endDate: DateTime.parse('2026-06-10T08:00:00.000Z'),
      );

      expect(captured.path,
          'https://api.test/api/v1/clubs/10/sections/44/class-counselor-assignments');
      expect(
        captured.data,
        equals({
          'user_id': 'user-1',
          'class_id': 13,
          'ecclesiastical_year_id': 2026,
          'responsibility_type': 'assistant',
          'exceptional': true,
          'exception_reason': 'Coverage',
          'start_date': '2026-01-10T08:00:00.000Z',
          'end_date': '2026-06-10T08:00:00.000Z',
        }),
      );
    });

    test('revokes class counselor assignment via expected endpoint', () async {
      late RequestOptions captured;
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            captured = options;
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'assignment_id': 'assign-1',
                  'user_id': 'user-1',
                  'club_section_id': 44,
                  'class_id': 13,
                  'ecclesiastical_year_id': 2026,
                  'club_role_assignment_id': 'cra-1',
                  'responsibility_type': 'primary',
                  'active': false,
                  'exceptional': false,
                  'exception_reason': null,
                  'assigned_by_id': 'admin-1',
                  'start_date': '2026-01-10T08:00:00.000Z',
                  'end_date': '2026-02-10T08:00:00.000Z',
                  'created_at': '2026-01-01T08:00:00.000Z',
                  'modified_at': '2026-02-10T09:00:00.000Z',
                  'users': {
                    'user_id': 'user-1',
                    'name': 'Ana',
                    'paternal_last_name': 'Perez',
                    'maternal_last_name': 'Lopez',
                    'email': 'ana@example.com',
                  },
                  'assigned_by': {
                    'user_id': 'admin-1',
                    'name': 'Juan',
                    'paternal_last_name': 'Boss',
                    'maternal_last_name': 'Principal',
                    'email': 'juan@example.com',
                  },
                  'classes': {
                    'class_id': 13,
                    'name': 'Guía',
                    'club_type_id': 2,
                    'display_order': 3,
                  },
                  'club_role_assignments': {
                    'assignment_id': 'cra-1',
                    'roles': {'role_name': 'counselor'},
                  },
                },
              ),
            );
          },
        ),
      );

      final dataSource = ClassesRemoteDataSourceImpl(
        dio: dio,
        baseUrl: 'https://api.test/api/v1',
      );

      final result =
          await dataSource.revokeClassCounselorAssignment('assign-1');

      expect(captured.path,
          'https://api.test/api/v1/class-counselor-assignments/assign-1');
      expect(result.assignmentId, 'assign-1');
      expect(result.active, isFalse);
    });

    test('requests class honors and parses relation + user status', () async {
      late RequestOptions captured;
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            captured = options;
            handler.resolve(
              Response<List<dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: [
                  {
                    'class_honor_id': 10,
                    'relation_type': 'RECOMMENDED',
                    'honor': {
                      'honor_id': 55,
                      'name': 'Primeros Auxilios',
                      'honor_image': 'primeros-auxilios.png',
                      'honors_category_id': 3,
                      'skill_level': 1,
                    },
                    'user_status': 'APPROVED',
                  },
                  {
                    'class_honor_id': 11,
                    'relation_type': 'REQUIRED',
                    'honor': {
                      'honor_id': 56,
                      'name': 'Nudos',
                    },
                    'user_status': null,
                  },
                ],
              ),
            );
          },
        ),
      );

      final dataSource = ClassesRemoteDataSourceImpl(
        dio: dio,
        baseUrl: 'https://api.test/api/v1',
      );

      final result = await dataSource.getClassHonors(13);

      expect(
        captured.path,
        'https://api.test/api/v1/classes/13/honors',
      );
      expect(result, hasLength(2));
      expect(result.first.honorName, 'Primeros Auxilios');
      expect(result.first.userStatus, 'APPROVED');
      expect(result.last.honorId, 56);
      expect(result.last.userStatus, isNull);
    });

    test('maps CLASS_PREREQUISITE_NOT_MET enroll error to friendly message',
        () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response(
                  requestOptions: options,
                  statusCode: 403,
                  data: {
                    'statusCode': 403,
                    'code': 'CLASS_PREREQUISITE_NOT_MET',
                    'message': 'Class prerequisite not met',
                  },
                ),
                type: DioExceptionType.badResponse,
              ),
            );
          },
        ),
      );

      final dataSource = ClassesRemoteDataSourceImpl(
        dio: dio,
        baseUrl: 'https://api.test/api/v1',
      );

      // easy_localization isn't initialized in plain unit tests, so `tr()`
      // falls back to the translation key itself. This still proves the
      // dedicated CLASS_PREREQUISITE_NOT_MET branch is taken instead of the
      // generic Dio message ("Class prerequisite not met" from the response
      // body). The actual Spanish copy is covered by the translations test.
      await expectLater(
        dataSource.enrollUser('user-1', 13, 2026),
        throwsA(
          isA<ServerException>().having((e) => e.code, 'code', 403).having(
                (e) => e.message,
                'message',
                'classes.errors.prerequisite_not_met',
              ),
        ),
      );
    });
  });
}
