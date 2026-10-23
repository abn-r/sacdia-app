import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/coordinator/data/datasources/coordinator_remote_data_source.dart';
import 'package:sacdia_app/features/coordinator/domain/entities/evidence_review_item.dart';

import '../../../../support/http_adapters.dart';

void main() {
  late JsonAdapter adapter;
  late CoordinatorRemoteDataSourceImpl dataSource;

  setUp(() {
    adapter = JsonAdapter(200, {'status': 'success'});
    dataSource = CoordinatorRemoteDataSourceImpl(
      dio: Dio()..httpClientAdapter = adapter,
      baseUrl: 'http://api.test/api/v1',
    );
  });

  group('approveEvidence', () {
    test('sends the optional comment as `comments` (ApproveEvidenceDto)',
        () async {
      await dataSource.approveEvidence(
        type: EvidenceReviewType.honor,
        id: '14',
        comment: 'Bien hecho',
      );

      final request = adapter.lastRequest!;
      expect(request.method, 'POST');
      expect(request.path, endsWith('/evidence-review/honor/14/approve'));
      expect(request.data, {'comments': 'Bien hecho'});
    });

    test('sends an empty body when there is no comment', () async {
      await dataSource.approveEvidence(
        type: EvidenceReviewType.honor,
        id: '14',
        comment: '',
      );

      expect(adapter.lastRequest!.data, isEmpty);
    });
  });

  group('rejectEvidence', () {
    test('sends the reason as `reason` (RejectEvidenceDto)', () async {
      await dataSource.rejectEvidence(
        type: EvidenceReviewType.classType,
        id: '35',
        rejectionReason: 'Falta la foto',
      );

      expect(adapter.lastRequest!.data, {'reason': 'Falta la foto'});
    });
  });
}
