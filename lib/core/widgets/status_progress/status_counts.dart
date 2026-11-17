/// Items counted by what they mean for the user.
///
/// [review] is "sent, waiting for someone else"; [pending] is "not done yet".
class StatusCounts {
  const StatusCounts({
    this.validated = 0,
    this.review = 0,
    this.rejected = 0,
    this.pending = 0,
  });

  final int validated;
  final int review;
  final int rejected;
  final int pending;

  int get total => validated + review + rejected + pending;

  /// Sent or validated: nothing left to do there.
  int get ready => validated + review;

  int get missing => total - ready;
}
