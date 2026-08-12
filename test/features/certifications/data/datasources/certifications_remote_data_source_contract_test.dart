import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/certifications/data/datasources/certifications_remote_data_source.dart';

/// Contrato de rutas de ejecución de participante (plan base):
/// `/certifications/users/:userId/certification-enrollments/:enrollmentId/...`
/// — la inscripción se identifica por `enrollmentId`, no por
/// `certificationId`.
void main() {
  const baseUrl = 'https://api.test/api/v1';
  const userId = 'user-1';
  const enrollmentId = 500;
  const requirementId = 10;
  const enrollmentBase =
      '$baseUrl/certifications/users/$userId/certification-enrollments/$enrollmentId';

  const requirementJson = {
    'section_id': requirementId,
    'module_id': 1,
    'name': 'Requisito',
    'required': true,
    'status': 'DRAFT',
  };

  late RequestOptions captured;

  CertificationsRemoteDataSourceImpl buildDataSource(
    Map<String, dynamic> responseData, {
    int statusCode = 200,
  }) {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          captured = options;
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: statusCode,
              data: responseData,
            ),
          );
        },
      ),
    );
    return CertificationsRemoteDataSourceImpl(dio: dio, baseUrl: baseUrl);
  }

  group('participant execution routes (enrollment contract)', () {
    test('getRequirement uses GET .../requirements/:requirementId', () async {
      final dataSource = buildDataSource(
        const {'status': 'success', 'data': requirementJson},
      );

      await dataSource.getRequirement(userId, enrollmentId, requirementId);

      expect(captured.method, 'GET');
      expect(captured.path, '$enrollmentBase/requirements/$requirementId');
    });

    test('saveDraft uses PATCH .../requirements/:requirementId/draft',
        () async {
      final dataSource = buildDataSource(
        const {'status': 'success', 'data': requirementJson},
      );

      await dataSource.saveDraft(userId, enrollmentId, requirementId, const [
        {'component_id': 1, 'text_value': 'Hola'},
      ]);

      expect(captured.method, 'PATCH');
      expect(
        captured.path,
        '$enrollmentBase/requirements/$requirementId/draft',
      );
    });

    test('submitRequirement uses POST .../requirements/:requirementId/submit',
        () async {
      final dataSource = buildDataSource(const {
        'status': 'success',
        'data': {
          'requirement': requirementJson,
          'progress_summary': {
            'requiredTotal': 1,
            'requiredApproved': 0,
            'optionalTotal': 0,
            'optionalApproved': 0,
            'percentComplete': 0,
            'allRequiredApproved': false,
          },
        },
      });

      await dataSource.submitRequirement(
        userId,
        enrollmentId,
        requirementId,
        lockVersion: 3,
      );

      expect(captured.method, 'POST');
      expect(
        captured.path,
        '$enrollmentBase/requirements/$requirementId/submit',
      );
      expect(captured.data, {'lock_version': 3});
    });

    test('presignEvidence uses POST .../evidences/presign', () async {
      final dataSource = buildDataSource(const {
        'status': 'success',
        'data': {
          'evidence_id': 100,
          'upload_url': 'https://r2.example/put',
          'object_key': 'enrollment-500/requirement-10/x.pdf',
          'expires_in': 900,
        },
      });

      await dataSource.presignEvidence(
        userId,
        enrollmentId,
        requirementId,
        componentId: 2,
        fileName: 'foto.jpg',
        mimeType: 'image/jpeg',
        fileSize: 2048,
      );

      expect(captured.method, 'POST');
      expect(
        captured.path,
        '$enrollmentBase/requirements/$requirementId/evidences/presign',
      );
    });

    test('confirmEvidence uses POST .../evidences/confirm', () async {
      final dataSource = buildDataSource(const {
        'status': 'success',
        'data': {
          'evidence_id': 100,
          'object_key': 'enrollment-500/requirement-10/x.pdf',
          'original_filename': 'foto.jpg',
          'mime_type': 'image/jpeg',
          'size_bytes': 2048,
          'upload_status': 'CONFIRMED',
        },
      });

      await dataSource.confirmEvidence(
        userId,
        enrollmentId,
        requirementId,
        evidenceId: 100,
      );

      expect(captured.method, 'POST');
      expect(
        captured.path,
        '$enrollmentBase/requirements/$requirementId/evidences/confirm',
      );
    });

    test(
        'deleteEvidence uses DELETE '
        '.../certification-enrollments/:enrollmentId/evidences/:evidenceId',
        () async {
      final dataSource = buildDataSource(const {'status': 'success'});

      await dataSource.deleteEvidence(userId, enrollmentId, 77);

      expect(captured.method, 'DELETE');
      expect(captured.path, '$enrollmentBase/evidences/77');
    });

    test('presignCloseoutEvidence uses POST .../closeout-evidence/presign',
        () async {
      final dataSource = buildDataSource(const {
        'status': 'success',
        'data': {
          'closeout_evidence_id': 200,
          'upload_url': 'https://r2.example/put',
          'object_key': 'enrollment-500/closeout/x.pdf',
          'expires_in': 900,
        },
      });

      await dataSource.presignCloseoutEvidence(
        userId,
        enrollmentId,
        fileName: 'acta.pdf',
        mimeType: 'application/pdf',
        fileSize: 4096,
      );

      expect(captured.method, 'POST');
      expect(captured.path, '$enrollmentBase/closeout-evidence/presign');
    });

    test('confirmCloseoutEvidence uses POST .../closeout-evidence/confirm',
        () async {
      final dataSource = buildDataSource(const {
        'status': 'success',
        'data': {
          'closeout_evidence_id': 200,
          'upload_status': 'CONFIRMED',
          'review_status': 'PENDING',
        },
      });

      await dataSource.confirmCloseoutEvidence(
        userId,
        enrollmentId,
        closeoutEvidenceId: 200,
      );

      expect(captured.method, 'POST');
      expect(captured.path, '$enrollmentBase/closeout-evidence/confirm');
    });

    test('submitFinal uses POST .../submit-final', () async {
      final dataSource = buildDataSource(const {
        'status': 'success',
        'data': {
          'enrollment_id': enrollmentId,
          'status': 'SUBMITTED_FOR_FINAL_REVIEW',
        },
      });

      await dataSource.submitFinal(userId, enrollmentId);

      expect(captured.method, 'POST');
      expect(captured.path, '$enrollmentBase/submit-final');
    });
  });
}
