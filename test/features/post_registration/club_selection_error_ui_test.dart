import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/network/interceptors/error_interceptor.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/post_registration/data/datasources/club_selection_remote_data_source.dart';
import 'package:sacdia_app/features/post_registration/presentation/providers/club_selection_providers.dart';
import 'package:sacdia_app/features/post_registration/presentation/views/club_selection_step_view.dart';

import '../../support/http_adapters.dart';
import '../family/family_test_harness.dart';

/// Responde `[]` a los catálogos y delega `/clubs` en [clubs].
class _Adapter implements HttpClientAdapter {
  _Adapter(this.clubs);

  final HttpClientAdapter clubs;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    if (options.uri.path.endsWith('/clubs')) {
      return clubs.fetch(options, requestStream, cancelFuture);
    }
    return Future.value(ResponseBody.fromString(
      jsonEncode(<Object>[]),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    ));
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initLocalization);

  Future<void> pump(WidgetTester tester, HttpClientAdapter clubs) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final dio = Dio()
      ..httpClientAdapter = _Adapter(clubs)
      ..interceptors.add(ErrorInterceptor());
    final ds = ClubSelectionRemoteDataSourceImpl(
      dio: dio,
      baseUrl: 'http://localhost:3000/api/v1',
    );

    await pumpFamilyApp(
      tester,
      overrides: [
        authNotifierProvider.overrideWith(() => FakeAuthNotifier(guardianUser)),
        clubSelectionDataSourceProvider.overrideWithValue(ds),
        selectedCountryProvider.overrideWith((ref) => 1),
        selectedUnionProvider.overrideWith((ref) => 1),
        selectedLocalFieldProvider.overrideWith((ref) => 1),
      ],
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: ClubSelectionStepView()),
        ),
      ],
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
      'ACTING_FOR_SCOPE_DENIED on /clubs shows the friendly message, never '
      'the raw exception or a network error', (tester) async {
    await pump(
      tester,
      JsonAdapter(403, {
        'status': 'error',
        'statusCode': 403,
        'code': 'ACTING_FOR_SCOPE_DENIED',
        'message': 'Forbidden resource',
      }),
    );

    expect(
      find.textContaining('Esta acción no está disponible mientras gestionas'),
      findsOneWidget,
    );
    expect(find.textContaining('AppException'), findsNothing);
    expect(find.textContaining('Code:'), findsNothing);
    expect(find.textContaining('Sin conexión'), findsNothing);
  });

  testWidgets('an unknown server error shows the generic message only',
      (tester) async {
    await pump(
      tester,
      JsonAdapter(500, {
        'status': 'error',
        'code': 'SOMETHING_ODD',
        'message': 'stack trace and internals',
      }),
    );

    expect(find.textContaining('Error al cargar clubes'), findsOneWidget);
    expect(find.textContaining('Ocurrió un error'), findsOneWidget);
    expect(find.textContaining('internals'), findsNothing);
    expect(find.textContaining('AppException'), findsNothing);
  });

  testWidgets('a real connection failure still reads as a connection error',
      (tester) async {
    await pump(
      tester,
      ErrorAdapter((options) => DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          )),
    );

    expect(find.textContaining('Error de conexión'), findsWidgets);
    expect(find.textContaining('AppException'), findsNothing);
  });
}
