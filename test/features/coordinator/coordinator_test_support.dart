import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/coordinator/data/models/consent_pending_page_model.dart';
import 'package:sacdia_app/features/coordinator/domain/entities/consent_pending_queue.dart';
import 'package:sacdia_app/features/coordinator/domain/repositories/coordinator_repository.dart';

/// Un ítem de `GET /coordination/me/consent-pending`, tal como lo manda el
/// backend (el `assignment_id` es el id crudo, sin el prefijo de la sección).
Map<String, Object?> pendingItemJson({
  required String id,
  required int sectionId,
  String name = 'Ana',
  String paternal = 'Pérez',
  String? userId,
  String club = 'Club Águilas',
  String type = 'Conquistadores',
  String? district = 'Distrito Norte',
  String uploadedAt = '2026-10-10T12:00:00.000Z',
}) =>
    {
      'assignment_id': id,
      'user_id': userId ?? 'user-$id',
      'role_id': 'role-member',
      'club_section_id': sectionId,
      'status': 'pending',
      'created_at': '2026-10-09T10:00:00.000Z',
      'expires_at': null,
      'users': {
        'user_id': userId ?? 'user-$id',
        'name': name,
        'email': null,
        'paternal_last_name': paternal,
        'maternal_last_name': 'Soto',
        'user_image': null,
      },
      'roles': {'role_id': 'role-member', 'role_name': 'member'},
      'consent': {
        'required': true,
        'dependent': true,
        'guardian_linked': false,
        'guardianship_id': 'gs-$id',
        'status': 'pending',
        'evidence_uploaded': true,
        'guardians': <Object?>[],
        'viewer_can_verify': true,
        'viewer_verify_block': null,
      },
      'effective_expires_at': null,
      'consent_form_uploaded_at': uploadedAt,
      'club_name': club,
      'club_type_name': type,
      'district_name': district,
    };

Map<String, Object?> pendingSectionJson({
  required int sectionId,
  required int count,
  String club = 'Club Águilas',
  String type = 'Conquistadores',
  String? district = 'Distrito Norte',
}) =>
    {
      'club_section_id': sectionId,
      'club_name': club,
      'club_type_name': type,
      'district_name': district,
      'pending_consent_count': count,
    };

/// El `data` de la respuesta (sin el sobre `{status, data}`).
Map<String, Object?> pendingPageJson({
  required List<Map<String, Object?>> items,
  int? total,
  int limit = 50,
  int offset = 0,
  List<Map<String, Object?>> bySection = const [],
}) =>
    {
      'items': items,
      'total': total ?? items.length,
      'limit': limit,
      'offset': offset,
      'by_section': bySection,
    };

ConsentPendingPage pendingPage({
  required List<Map<String, Object?>> items,
  int? total,
  int limit = 50,
  int offset = 0,
  List<Map<String, Object?>> bySection = const [],
}) =>
    ConsentPendingPageModel.fromJson(
      pendingPageJson(
        items: items,
        total: total,
        limit: limit,
        offset: offset,
        bySection: bySection,
      ),
    );

const noSectionsFailure = AuthFailure(
  message: 'x',
  code: 403,
  errorCode: 'GUARD_CLUB_SCOPE_REQUIRED',
);

const permissionDeniedFailure = AuthFailure(
  message: 'x',
  code: 403,
  errorCode: 'GUARD_PERMISSION_DENIED',
);

/// Repositorio del coordinador que solo implementa la cola de fichas; el resto
/// de métodos no se usan en estos tests.
class FakeCoordinatorRepository implements CoordinatorRepository {
  /// Una respuesta por llamada, en orden; la última se repite.
  List<Either<Failure, ConsentPendingPage>> results = [];

  final calls = <({int limit, int offset})>[];

  /// El token de cada llamada, en el mismo orden que [calls].
  final cancelTokens = <Object?>[];

  /// Si se asigna, las llamadas esperan a que se complete.
  Completer<void>? gate;

  @override
  Future<Either<Failure, ConsentPendingPage>> getConsentPending({
    int limit = 50,
    int offset = 0,
    Object? cancelToken,
  }) async {
    calls.add((limit: limit, offset: offset));
    cancelTokens.add(cancelToken);
    // Como Dio: pedir con un token ya cancelado falla sin tocar la red.
    if (cancelToken is CancelToken && cancelToken.isCancelled) {
      return const Left(ServerFailure(message: 'cancelled', code: 0));
    }
    final gate = this.gate;
    if (gate != null) await gate.future;
    final index = calls.length - 1;
    return results[index < results.length ? index : results.length - 1];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}
