import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/constants/api_endpoints.dart';
import 'package:sacdia_app/providers/dio_provider.dart';

import 'instructor_selection.dart';

/// Why the instructor search failed, independent of wording.
enum InstructorSearchError { rateLimited, offline, unknown }

class InstructorSearchException implements Exception {
  const InstructorSearchException(this.error);

  final InstructorSearchError error;

  @override
  String toString() => 'InstructorSearchException($error)';
}

/// Runs one search. Overridable so tests need no network.
typedef InstructorSearch = Future<List<InstructorSelection>> Function(
  String query, {
  CancelToken? cancelToken,
});

/// `GET /instructor-candidates?q=`: people of the caller's Local Field, at
/// most 10, name and photo only. The API answers 429 after 30 queries a
/// minute.
final instructorSearchProvider = Provider<InstructorSearch>((ref) {
  final dio = ref.watch(dioProvider);
  return (query, {cancelToken}) async {
    try {
      final response = await dio.get(
        ApiEndpoints.instructorCandidates,
        queryParameters: {'q': query},
        cancelToken: cancelToken,
      );
      final body = response.data;
      final data = body is Map ? body['data'] : body;
      if (data is! List) {
        throw const InstructorSearchException(InstructorSearchError.unknown);
      }
      return data
          .map(InstructorSelection.tryParseCandidate)
          .whereType<InstructorSelection>()
          .toList(growable: false);
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) rethrow;
      throw InstructorSearchException(_classify(error));
    }
  };
});

InstructorSearchError _classify(DioException error) {
  if (error.response?.statusCode == 429) {
    return InstructorSearchError.rateLimited;
  }
  if (error.response == null) return InstructorSearchError.offline;
  return InstructorSearchError.unknown;
}

/// Results for a (debounced) query. A query the API would ignore answers
/// empty without a request. When the query changes the previous family entry
/// loses its listener and is disposed, which cancels its request.
final instructorCandidatesProvider = FutureProvider.autoDispose
    .family<List<InstructorSelection>, String>((ref, query) async {
  if (!InstructorRules.isSearchable(query)) return const [];
  final token = CancelToken();
  ref.onDispose(token.cancel);
  final search = ref.watch(instructorSearchProvider);
  return search(InstructorRules.normalize(query), cancelToken: token);
});
