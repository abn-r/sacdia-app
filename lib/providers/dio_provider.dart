import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/auth/acting_for_session.dart';
import '../core/network/dio_client.dart';
import '../features/auth/presentation/providers/auth_providers.dart';

/// Provider para la instancia configurada de Dio
final dioProvider = Provider<Dio>((ref) {
  return DioClient.createDio(
    onAuthExpired: () =>
        ref.read(authNotifierProvider.notifier).expireSession(),
    actingForSession: ref.read(actingForSessionProvider),
  );
});
