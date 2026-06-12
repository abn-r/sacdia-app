import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/honors/data/datasources/honors_remote_data_source.dart';
import 'package:sacdia_app/features/honors/data/models/honor_group_model.dart';
import 'package:sacdia_app/features/honors/data/models/user_honor_model.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor.dart';

void main() {
  group('HonorGroupModel', () {
    test('preserves club type and category metadata from grouped endpoint', () {
      final group = HonorGroupModel.fromJson(const {
        'category': {
          'honor_category_id': 2,
          'name': 'ADRA',
          'description': null,
          'icon': null,
        },
        'honors': [
          {
            'honor_id': 99,
            'name': 'Contar historias bíblicas',
            'description': 'Especialidad de Aventureros',
            'honor_image': 'https://cdn.test/honor.png',
            'skill_level': 1,
            'material_url': 'https://cdn.test/honor.pdf',
            'club_type_id': 1,
            'club_type_name': 'Aventureros',
          },
        ],
      });

      final honor = group.honors.single.toEntity();

      expect(honor.categoryId, 2);
      expect(honor.categoryName, 'ADRA');
      expect(honor.clubTypeId, 1);
      expect(honor.clubTypeName, 'Aventureros');
    });
  });

  group('UserHonorModel completion mode mapping', () {
    test('maps backend completion_mode into domain enum', () {
      final model = UserHonorModel.fromJson(const {
        'user_honor_id': 10,
        'honor_id': 7,
        'user_id': 'user-1',
        'validation_status': 'IN_PROGRESS',
        'completion_mode': 'EXTERNAL',
        'certificate': '',
        'images': [],
        'document': null,
        'date': '2026-06-11T00:00:00.000Z',
      });

      expect(model.completionMode, HonorCompletionMode.external);
      expect(model.toEntity().completionMode, HonorCompletionMode.external);
      expect(model.toJson()['completion_mode'], 'EXTERNAL');
    });

    test('defaults missing or unknown completion mode to undecided', () {
      final model = UserHonorModel.fromJson(const {
        'user_honor_id': 10,
        'honor_id': 7,
        'user_id': 'user-1',
        'validation_status': 'IN_PROGRESS',
        'completion_mode': 'legacy',
        'certificate': '',
        'images': [],
        'document': null,
        'date': '2026-06-11T00:00:00.000Z',
      });

      expect(model.completionMode, HonorCompletionMode.undecided);
    });
  });

  group('HonorsRemoteDataSourceImpl.updateHonorCompletionMode', () {
    test('sends camelCase completionMode accepted by the backend contract',
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
                  'user_honor_id': 10,
                  'honor_id': 7,
                  'user_id': 'user-1',
                  'validation_status': 'IN_PROGRESS',
                  'completion_mode': 'IN_APP',
                  'certificate': '',
                  'images': [],
                  'document': null,
                  'date': '2026-06-11T00:00:00.000Z',
                },
              ),
            );
          },
        ),
      );

      final ds = HonorsRemoteDataSourceImpl(
        dio: dio,
        baseUrl: 'https://api.test/api/v1',
      );

      final result = await ds.updateHonorCompletionMode(
        userId: 'user-1',
        honorId: 7,
        completionMode: HonorCompletionMode.inApp,
      );

      expect(captured.path, 'https://api.test/api/v1/users/user-1/honors/7');
      expect(captured.data, {'completionMode': 'IN_APP'});
      expect(result.completionMode, HonorCompletionMode.inApp);
    });
  });

  group('HonorsRemoteDataSourceImpl.uploadHonorFile', () {
    Future<RequestOptions> captureUploadRequest(
      HonorFileUploadField uploadField,
    ) async {
      late RequestOptions captured;
      final file = File('${Directory.systemTemp.path}/honor-contract.pdf')
        ..writeAsBytesSync([1, 2, 3]);
      addTearDown(() {
        if (file.existsSync()) file.deleteSync();
      });

      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            captured = options;
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 201,
                data: const {'status': 'success'},
              ),
            );
          },
        ),
      );

      final ds = HonorsRemoteDataSourceImpl(
        dio: dio,
        baseUrl: 'https://api.test/api/v1',
      );

      await ds.uploadHonorFile(
        userId: 'user-1',
        honorId: 7,
        file: file,
        fileName: 'honor-contract.pdf',
        uploadField: uploadField,
      );

      return captured;
    }

    test('sends general evidence through the images multipart field', () async {
      final captured = await captureUploadRequest(HonorFileUploadField.images);
      final formData = captured.data as FormData;

      expect(
          captured.path, 'https://api.test/api/v1/users/user-1/honors/7/files');
      expect(formData.files.single.key, 'images');
      expect(formData.files.single.value.contentType.toString(),
          'application/pdf');
    });

    test('sends completed format through the document multipart field',
        () async {
      final captured =
          await captureUploadRequest(HonorFileUploadField.document);
      final formData = captured.data as FormData;

      expect(formData.files.single.key, 'document');
      expect(formData.files.single.value.contentType.toString(),
          'application/pdf');
    });
  });

  group('HonorsRemoteDataSourceImpl requirement evidence', () {
    test('parses upload response wrapped in the standard API envelope',
        () async {
      late RequestOptions captured;
      final file = File('${Directory.systemTemp.path}/requirement-photo.jpg')
        ..writeAsBytesSync([1, 2, 3]);
      addTearDown(() {
        if (file.existsSync()) file.deleteSync();
      });

      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            captured = options;
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 201,
                data: const {
                  'status': 'success',
                  'data': {
                    'evidence_id': 99,
                    'evidence_type': 'IMAGE',
                    'url': 'https://cdn.test/requirement-photo.jpg',
                    'filename': 'requirement-photo.jpg',
                    'mime_type': 'image/jpeg',
                    'file_size': 3,
                  },
                },
              ),
            );
          },
        ),
      );

      final ds = HonorsRemoteDataSourceImpl(
        dio: dio,
        baseUrl: 'https://api.test/api/v1',
      );

      final result = await ds.uploadRequirementEvidence(
        'user-1',
        7,
        10,
        file,
        mimeType: 'image/jpeg',
      );

      expect(
        captured.path,
        'https://api.test/api/v1/users/user-1/honors/7/requirements/10/evidence/upload',
      );
      expect(result.id, 99);
      expect(result.url, 'https://cdn.test/requirement-photo.jpg');
    });

    test('parses evidence link response wrapped in the standard API envelope',
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
                statusCode: 201,
                data: const {
                  'status': 'success',
                  'data': {
                    'evidence_id': 100,
                    'evidence_type': 'LINK',
                    'url': 'https://example.test/evidence',
                    'filename': null,
                    'mime_type': null,
                    'file_size': null,
                  },
                },
              ),
            );
          },
        ),
      );

      final ds = HonorsRemoteDataSourceImpl(
        dio: dio,
        baseUrl: 'https://api.test/api/v1',
      );

      final result = await ds.addRequirementEvidenceLink(
        'user-1',
        7,
        10,
        'https://example.test/evidence',
      );

      expect(
        captured.path,
        'https://api.test/api/v1/users/user-1/honors/7/requirements/10/evidence/link',
      );
      expect(captured.data, {'url': 'https://example.test/evidence'});
      expect(result.id, 100);
      expect(result.url, 'https://example.test/evidence');
    });
  });

  group('HonorsRemoteDataSourceImpl.updateRequirementProgress', () {
    test(
        'uses live users/:userId/honors/:honorId/requirements/:requirementId/progress endpoint',
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
                  'status': 'success',
                  'data': {
                    'requirement_id': 10,
                    'requirement_number': 1,
                    'requirement_text': 'Texto requisito',
                    'completed': true,
                    'has_sub_items': false,
                    'notes': 'ok',
                  },
                },
              ),
            );
          },
        ),
      );

      final ds = HonorsRemoteDataSourceImpl(
        dio: dio,
        baseUrl: 'https://api.test/api/v1',
      );

      final result = await ds.updateRequirementProgress(
        userId: 'user-1',
        honorId: 7,
        requirementId: 10,
        completed: true,
        notes: 'ok',
      );

      expect(
        captured.path,
        'https://api.test/api/v1/users/user-1/honors/7/requirements/10/progress',
      );
      expect(captured.data, {'completed': true, 'notes': 'ok'});
      expect(result.requirementId, 10);
      expect(result.completed, isTrue);
    });
  });
}
