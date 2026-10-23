import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/errors/user_error_message.dart';

import '../../features/family/family_test_harness.dart';

/// Resuelve [userErrorMessage] con las traducciones reales cargadas.
Future<List<String>> _messages(
    WidgetTester tester, List<Object?> errors) async {
  final out = <String>[];
  await pumpFamilyApp(
    tester,
    overrides: const [],
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) {
          out
            ..clear()
            ..addAll(errors.map(userErrorMessage));
          return const SizedBox();
        },
      ),
    ],
  );
  return out;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initLocalization);

  testWidgets('a scope-denied AuthException reads as the friendly message',
      (tester) async {
    final out = await _messages(tester, [
      AuthException(
        message: 'Forbidden resource',
        code: 403,
        errorCode: 'ACTING_FOR_SCOPE_DENIED',
      ),
      const ServerFailure(
        message: 'x',
        code: 403,
        errorCode: 'ACTING_FOR_SCOPE_DENIED',
      ),
    ]);
    for (final message in out) {
      expect(message, contains('no está disponible'));
      expect(message, isNot(contains('AppException')));
      expect(message, isNot(contains('Code:')));
    }
  });

  testWidgets('no connection reads as the connection message', (tester) async {
    final out = await _messages(tester, [
      ConnectionException(message: 'raw socket text'),
      const ConnectionFailure(message: 'raw socket text'),
    ]);
    expect(out, everyElement('Error de conexión. Compruebe su red.'));
  });

  testWidgets('an unknown code or a bare exception never leaks the raw text',
      (tester) async {
    final out = await _messages(tester, [
      ServerException(message: 'boom', code: 500, errorCode: 'SOME_UNKNOWN'),
      ServerException(message: 'boom'),
      Exception('boom'),
      'boom',
    ]);
    expect(out, everyElement('Ocurrió un error. Intente nuevamente.'));
  });

  test('ACTING_FOR_SCOPE_DENIED is translated in all 4 locales', () {
    for (final locale in ['es', 'en', 'fr', 'pt-BR']) {
      final json = jsonDecode(
        File('assets/translations/$locale.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final errors = json['errors'] as Map<String, dynamic>;
      final message = errors['acting_for_scope_denied'];
      expect(message, isA<String>(), reason: locale);
      expect((message as String).trim(), isNotEmpty, reason: locale);
    }
  });
}
