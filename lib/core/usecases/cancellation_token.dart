/// Opaque cancellation handle accepted by domain contracts.
///
/// The domain layer must never depend on a concrete HTTP client such as Dio.
/// Presentation/data may pass their native cancellation object through this
/// boundary, and infrastructure adapters decide whether they can consume it.
typedef RequestCancelToken = Object;
