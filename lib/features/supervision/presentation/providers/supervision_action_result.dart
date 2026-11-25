import '../../../../core/errors/failures.dart';
import '../../../../core/errors/forbidden.dart';

/// Outcome of a supervision write (approve, reject, save a setting).
///
/// Views read [errorCode] to pick their own localized text and fall back to
/// [errorMessage] (the server message) for codes they do not know.
class SupervisionActionResult {
  const SupervisionActionResult.success()
      : ok = true,
        errorMessage = null,
        errorCode = null,
        isForbidden = false;

  const SupervisionActionResult.failure({
    this.errorMessage,
    this.errorCode,
    this.isForbidden = false,
  }) : ok = false;

  factory SupervisionActionResult.fromFailure(Failure failure) =>
      SupervisionActionResult.failure(
        errorMessage: failure.message,
        errorCode: failure.errorCode,
        isForbidden: isForbiddenFailure(failure),
      );

  final bool ok;
  final String? errorMessage;
  final String? errorCode;
  final bool isForbidden;
}
