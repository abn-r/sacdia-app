import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/enrollment/data/datasources/enrollment_remote_data_source.dart';
import 'package:sacdia_app/features/enrollment/domain/entities/enrollment.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._body);

  final ResponseBody _body;
  RequestOptions? lastOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    return _body;
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
      'sends the backend annual-enrollment contract without legacy coordinates',
      () async {
    final adapter = _FakeAdapter(
      ResponseBody.fromString(
        jsonEncode({
          'status': 'success',
          'data': {
            'club_enrollment_id': '46bebcb7-3f0a-49c7-930a-a25efc9bde89',
            'club_section_id': 12,
            'ecclesiastical_year_id': 2026,
            'status': 'pending_validation',
            'meeting_days': 'Sábado',
          },
        }),
        201,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      ),
    );
    final dio = Dio(BaseOptions(responseType: ResponseType.json))
      ..httpClientAdapter = adapter;
    final dataSource = EnrollmentRemoteDataSourceImpl(
      dio: dio,
      baseUrl: 'http://localhost:3000',
    );

    await dataSource.createEnrollment(
      clubId: '7',
      sectionId: 12,
      address: 'Templo Central',
      lat: 19.4326,
      long: -99.1332,
      meetingSchedule: const [
        MeetingSchedule(day: 'Sábado', time: '09:00'),
      ],
      deputyDirectorIds: const [],
    );

    expect(adapter.lastOptions!.data, {
      'address': 'Templo Central',
      'meeting_days': 'Sábado',
      'meeting_schedule': [
        {'day': 'Sábado', 'time': '09:00'},
      ],
      'latitude': 19.4326,
      'longitude': -99.1332,
    });
  });
}
