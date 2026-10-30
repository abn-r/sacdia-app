import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/providers/riverpod_aliases.dart';
import 'package:sacdia_app/core/widgets/instructor_candidates_provider.dart';
import 'package:sacdia_app/core/widgets/instructor_selection.dart';

const anaGomez = InstructorSelection.user(
  id: '11111111-1111-4111-8111-111111111111',
  displayName: 'Ana Gómez',
);
const anaGongora = InstructorSelection.user(
  id: '22222222-2222-4222-8222-222222222222',
  displayName: 'Ana Góngora',
);

/// Stands in for `GET /instructor-candidates`: records every query (and the
/// cancel token it came with) and answers with [handler].
class FakeInstructorSearch {
  FakeInstructorSearch([this.handler]);

  final queries = <String>[];
  final tokens = <CancelToken?>[];
  Future<List<InstructorSelection>> Function(String query)? handler;

  Future<List<InstructorSelection>> call(
    String query, {
    CancelToken? cancelToken,
  }) {
    queries.add(query);
    tokens.add(cancelToken);
    final answer = handler;
    if (answer != null) return answer(query);
    return Future.value(
      query.toLowerCase().startsWith('ana') ? [anaGomez, anaGongora] : const [],
    );
  }

  Override get override => instructorSearchProvider.overrideWithValue(call);
}
