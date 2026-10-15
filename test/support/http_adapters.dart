import 'dart:convert';

import 'package:dio/dio.dart';

/// Adaptador Dio que responde JSON (anidado) con un status fijo.
class JsonAdapter implements HttpClientAdapter {
  JsonAdapter(this.statusCode, this.body);

  final int statusCode;
  final Object body;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? _,
    Future<void>? __,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Adaptador Dio que falla sin respuesta (timeout / sin conexión).
class ErrorAdapter implements HttpClientAdapter {
  ErrorAdapter(this.build);

  final DioException Function(RequestOptions options) build;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? _,
    Future<void>? __,
  ) async =>
      throw build(options);

  @override
  void close({bool force = false}) {}
}
