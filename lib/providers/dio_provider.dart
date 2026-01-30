import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';

/// Provider para la instancia configurada de Dio
final dioProvider = Provider<Dio>((ref) {
  return DioClient.createDio();
});
