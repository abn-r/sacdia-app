import 'package:dio/dio.dart';

import '../../domain/entities/location_search_result.dart';

abstract class NominatimRemoteDataSource {
  Future<List<LocationSearchResult>> search(String query);
}

class NominatimRemoteDataSourceImpl implements NominatimRemoteDataSource {
  final Dio _dio;

  NominatimRemoteDataSourceImpl({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://nominatim.openstreetmap.org',
                connectTimeout: const Duration(seconds: 5),
                receiveTimeout: const Duration(seconds: 5),
                headers: const {
                  'User-Agent': 'SACDIA App/1.0 (contact@sacdia.org)',
                  'Accept-Language': 'es',
                },
              ),
            );

  @override
  Future<List<LocationSearchResult>> search(String query) async {
    final response = await _dio.get<List<dynamic>>(
      '/search',
      queryParameters: {
        'q': query.trim(),
        'format': 'json',
        'limit': 5,
        'addressdetails': 1,
        'accept-language': 'es',
      },
    );

    final data = response.data ?? const [];
    return data.map((item) {
      final map = item as Map<String, dynamic>;
      return LocationSearchResult(
        lat: double.parse(map['lat'] as String),
        lon: double.parse(map['lon'] as String),
        displayName: map['display_name'] as String,
      );
    }).toList();
  }
}
