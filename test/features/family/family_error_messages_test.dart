import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/family/presentation/family_error_messages.dart';

void main() {
  const code = 'GUARDIANSHIP_RELATIONSHIP_TYPE_NOT_ALLOWED';

  test('the not-allowed code is a family code with its errors.* key', () {
    expect(familyErrorCodes, contains(code));
    expect(familyErrorKey(code),
        'errors.guardianship_relationship_type_not_allowed');
  });

  test('the key is translated (non-empty, not the key) in all 4 locales', () {
    for (final locale in ['es', 'en', 'fr', 'pt-BR']) {
      final json = jsonDecode(
        File('assets/translations/$locale.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final errors = json['errors'] as Map<String, dynamic>;
      final message = errors['guardianship_relationship_type_not_allowed'];
      expect(message, isA<String>(), reason: locale);
      expect((message as String).trim(), isNotEmpty, reason: locale);

      final family = (json['family'] as Map<String, dynamic>)['add']
          as Map<String, dynamic>;
      expect(family['relationship'], isNotEmpty, reason: locale);
      expect(family['relationship_hint'], isNotEmpty, reason: locale);
    }
  });

  test('a Failure with the code maps to the specific message key', () {
    const failure = ServerFailure(
      message: 'server text',
      code: 422,
      errorCode: code,
    );
    expect(familyErrorKey(failure.errorCode), isNotNull);
    expect(isGuardianProfileIncomplete(failure), isFalse);
  });
}
