import '../../domain/entities/join_request.dart';

/// Next step a join request is waiting for.
enum JoinRequestGroup { ready, review, waiting }

/// Requests split by what the director has to do next.
typedef JoinRequestGroups = ({
  List<JoinRequest> ready,
  List<JoinRequest> review,
  List<JoinRequest> waiting,
});

/// Group of a single request.
///
/// - No consent block (own account) or a verified one: ready to approve.
/// - Consent pending with a signed form uploaded: the form needs review.
/// - Consent pending without the form: waiting for the guardian.
JoinRequestGroup joinRequestGroupOf(JoinRequest request) {
  if (!request.consentPending) return JoinRequestGroup.ready;
  return request.consent!.evidenceUploaded
      ? JoinRequestGroup.review
      : JoinRequestGroup.waiting;
}

/// Splits [requests] by [joinRequestGroupOf], keeping the incoming order.
JoinRequestGroups groupJoinRequests(List<JoinRequest> requests) {
  final ready = <JoinRequest>[];
  final review = <JoinRequest>[];
  final waiting = <JoinRequest>[];
  for (final request in requests) {
    switch (joinRequestGroupOf(request)) {
      case JoinRequestGroup.ready:
        ready.add(request);
      case JoinRequestGroup.review:
        review.add(request);
      case JoinRequestGroup.waiting:
        waiting.add(request);
    }
  }
  return (ready: ready, review: review, waiting: waiting);
}
