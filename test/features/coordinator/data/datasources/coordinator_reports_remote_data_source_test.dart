import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/coordinator/data/datasources/coordinator_reports_remote_data_source.dart';

import '../../../../support/http_adapters.dart';

const _uuid = '3f2b8c1e-0a4d-4e7b-9c55-000000000055';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('coordinator_pdf_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tempDir.path,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    tempDir.deleteSync(recursive: true);
  });

  test('downloadReportPdf requests /monthly-reports/<uuid>/pdf', () async {
    final adapter = JsonAdapter(200, {'pdf': 'bytes'});
    final dataSource = CoordinatorReportsRemoteDataSourceImpl(
      dio: Dio()..httpClientAdapter = adapter,
      baseUrl: 'http://api.test/api/v1',
    );

    final path = await dataSource.downloadReportPdf(reportId: _uuid);

    expect(adapter.lastRequest!.method, 'GET');
    expect(adapter.lastRequest!.path, endsWith('/monthly-reports/$_uuid/pdf'));
    expect(path, endsWith('informe-mensual-$_uuid.pdf'));
  });
}
