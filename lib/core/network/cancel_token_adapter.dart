import 'package:dio/dio.dart';

import '../usecases/cancellation_token.dart';

/// Adapts the domain's opaque cancellation handle to Dio when the caller passed
/// a Dio [CancelToken]. Non-Dio handles are ignored by this infrastructure layer.
extension DioCancelTokenAdapter on RequestCancelToken? {
  CancelToken? asDioCancelToken() {
    final token = this;
    return token is CancelToken ? token : null;
  }
}
