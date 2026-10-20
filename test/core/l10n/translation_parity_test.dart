import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _locales = ['es', 'en', 'fr', 'pt-BR'];

/// Llaves que ya faltaban en fr y pt-BR antes de Mi familia. No se añaden más:
/// cualquier llave nueva que falte en un idioma rompe el test.
const _knownGaps = {
  'camporees.detail.resources',
  'dashboard.quick_access.materials',
};

Map<String, String> _flatten(Map<String, dynamic> map, [String prefix = '']) {
  final out = <String, String>{};
  map.forEach((key, value) {
    final path = prefix.isEmpty ? key : '$prefix.$key';
    if (value is Map<String, dynamic>) {
      out.addAll(_flatten(value, path));
    } else {
      out[path] = value.toString();
    }
  });
  return out;
}

Map<String, String> _load(String locale) {
  final raw = File('assets/translations/$locale.json').readAsStringSync();
  return _flatten(jsonDecode(raw) as Map<String, dynamic>);
}

/// Códigos de error nuevos de Phase 2 (2a) que la app debe traducir (FP-68).
const _phase2ErrorCodes = [
  'GUARDIANSHIP_NOT_FOUND',
  'GUARDIANSHIP_DEPENDENT_AGE_OUT_OF_RANGE',
  'GUARDIANSHIP_GUARDIAN_NOT_ADULT',
  'GUARDIANSHIP_GUARDIAN_BIRTHDAY_REQUIRED',
  'GUARDIANSHIP_DEPENDENT_LIMIT_REACHED',
  'GUARDIANSHIP_GUARDIAN_LIMIT_REACHED',
  'GUARDIANSHIP_LINK_CODE_INVALID',
  'GUARDIANSHIP_LINK_CODE_LOCKED',
  'GUARDIANSHIP_LINK_CODE_SELF_REDEEM',
  'GUARDIANSHIP_ALREADY_GUARDIAN',
  'GUARDIANSHIP_REVOKE_FORBIDDEN',
  'GUARDIANSHIP_RELATIONSHIP_TYPE_INVALID',
  'ACTING_FOR_HEADER_INVALID',
  'ACTING_FOR_FORBIDDEN',
  'ACTING_FOR_SCOPE_DENIED',
  'AUTH_DELETE_DEPENDENTS_ACK_REQUIRED',
  'AUTH_REGISTRATION_AGE_BELOW_MINIMUM',
  'USER_SELF_ACCOUNT_BELOW_MINIMUM_AGE',
  'POST_REG_GUARDIAN_ONLY_REQUIRES_ADULT',
  'MR_CONSENT_NOT_VERIFIED',
];

/// Códigos nuevos de Phase 2c (verificación del consentimiento) que la app
/// debe traducir (FP-68), más los que puede mostrar el director al subir y
/// verificar.
const _phase2cErrorCodes = [
  'GUARDIANSHIP_EVIDENCE_NOT_FOUND',
  'GUARDIANSHIP_EVIDENCE_REQUIRED',
  'GUARDIANSHIP_EVIDENCE_UNAVAILABLE',
  'GUARDIANSHIP_CUSTODIAN_SELF_VERIFY',
  'MR_CONSENT_CONFIRMATION_REQUIRED',
  'MR_NOT_FOUND',
  'MR_ALREADY_PENDING',
  'GUARD_PERMISSION_DENIED',
  'FILE_REQUIRED',
  'FILE_TYPE_INVALID',
  'FILE_TOO_LARGE',
  // Fix batch 2c backend (rulings W1/W2).
  'GUARDIANSHIP_CONSENT_ALREADY_VERIFIED',
  'GUARDIANSHIP_GUARDIAN_SELF_VERIFY',
];

/// Códigos nuevos de la Fase 3a (login supervisado, resumen, modo pendiente)
/// que la app debe traducir en los 4 idiomas (FP3-34).
const _phase3aErrorCodes = [
  'AUTH_INVALID_CREDENTIALS',
  'AUTH_LOGIN_LOCKED',
  'AUTH_SUPERVISED_LOGIN_DISABLED',
  'AUTH_ACCOUNT_FROZEN',
  'AUTH_SUPERVISED_ACCESS_REVOKED',
  'PRINCIPAL_SCOPE_DENIED',
  'USER_BIRTHDAY_CHANGE_REQUIRES_GUARDIAN',
  'SUPERVISED_LOGIN_NOT_ELIGIBLE',
  'SUPERVISED_LOGIN_AGE_OUT_OF_RANGE',
  'SUPERVISED_LOGIN_ALREADY_ENABLED',
  'SUPERVISED_LOGIN_NOT_FOUND',
  'SUPERVISED_LOGIN_EMAIL_UNAVAILABLE',
  'SUPERVISED_LOGIN_PASSWORD_INVALID',
  'GUARDIANSHIP_CONSENT_NOT_VERIFIED',
  'FAMILY_FEATURE_DISABLED',
];

/// Códigos nuevos de la Fase 3b (teléfono vinculado) que la app debe traducir
/// en los 4 idiomas (FP3-34). Los dos grupos de nombres (spec y diseño) se
/// traducen: el servidor puede usar cualquiera.
const _phase3bErrorCodes = [
  'AUTH_DEVICE_REVOKED',
  'AUTH_DEVICE_SESSION_EXPIRED',
  'DEVICE_PAIRING_TOKEN_INVALID',
  'DEVICE_PAIRING_NOT_ELIGIBLE',
  'DEVICE_LIMIT_REACHED',
  'LINKED_DEVICE_LIMIT_REACHED',
  'LINKED_DEVICE_AGE_OUT_OF_RANGE',
  'DEVICE_NOT_FOUND',
  'LINKED_DEVICE_NOT_FOUND',
];

void main() {
  final translations = {for (final l in _locales) l: _load(l)};
  final base = translations['es']!;

  test('every locale has exactly the keys of es (known gaps aside)', () {
    for (final locale in _locales.skip(1)) {
      final keys = translations[locale]!.keys.toSet();
      final missing = base.keys.toSet().difference(keys).difference(_knownGaps);
      final extra = keys.difference(base.keys.toSet());
      expect(missing, isEmpty, reason: '$locale is missing keys');
      expect(extra, isEmpty, reason: '$locale has keys es does not');
    }
  });

  test('no translation is empty', () {
    for (final locale in _locales) {
      final empty = translations[locale]!
          .entries
          .where((e) => e.value.trim().isEmpty)
          .map((e) => e.key);
      expect(empty, isEmpty, reason: locale);
    }
  });

  test('placeholders match across locales for the family keys', () {
    final placeholder = RegExp(r'\{[a-z_]+\}');
    for (final entry in base.entries.where(
      (e) =>
          e.key.startsWith('family.') ||
          e.key.startsWith('errors.') ||
          e.key.startsWith('members.consent.') ||
          e.key.startsWith('core.consent.'),
    )) {
      final expected =
          placeholder.allMatches(entry.value).map((m) => m.group(0)).toSet();
      for (final locale in _locales.skip(1)) {
        final value = translations[locale]![entry.key];
        if (value == null) continue;
        final actual =
            placeholder.allMatches(value).map((m) => m.group(0)).toSet();
        expect(actual, expected, reason: '${entry.key} in $locale');
      }
    }
  });

  test('every Phase 2 error code has an errors.* translation in all locales',
      () {
    for (final code in _phase2ErrorCodes) {
      final key = 'errors.${code.toLowerCase()}';
      for (final locale in _locales) {
        expect(
          translations[locale]!.containsKey(key),
          isTrue,
          reason: '$key missing in $locale',
        );
      }
    }
  });

  test('every Phase 2c error code has an errors.* translation in all locales',
      () {
    for (final code in _phase2cErrorCodes) {
      final key = 'errors.${code.toLowerCase()}';
      for (final locale in _locales) {
        expect(
          translations[locale]!.containsKey(key),
          isTrue,
          reason: '$key missing in $locale',
        );
      }
    }
  });

  test(
      'the consent trees (members.consent.*, core.consent.*) exist in all '
      'locales', () {
    for (final prefix in ['members.consent.', 'core.consent.']) {
      final keys = base.keys.where((k) => k.startsWith(prefix)).toList();
      expect(keys.length, greaterThan(15), reason: prefix);
      for (final locale in _locales) {
        for (final key in keys) {
          expect(
            translations[locale]!.containsKey(key),
            isTrue,
            reason: '$key missing in $locale',
          );
        }
      }
    }
  });

  test('every Phase 3a error code has an errors.* translation in all locales',
      () {
    for (final code in _phase3aErrorCodes) {
      final key = 'errors.${code.toLowerCase()}';
      for (final locale in _locales) {
        expect(
          translations[locale]!.containsKey(key),
          isTrue,
          reason: '$key missing in $locale',
        );
      }
    }
  });

  test('the 3a login and teen trees keep their placeholders in all locales',
      () {
    final placeholder = RegExp(r'\{[a-z_]+\}');
    for (final entry in base.entries.where(
      (e) =>
          e.key.startsWith('auth.login.') ||
          e.key.startsWith('teen.') ||
          e.key == 'errors.auth_login_locked_wait',
    )) {
      final expected =
          placeholder.allMatches(entry.value).map((m) => m.group(0)).toSet();
      for (final locale in _locales.skip(1)) {
        final value = translations[locale]![entry.key];
        expect(value, isNotNull, reason: '${entry.key} in $locale');
        final actual =
            placeholder.allMatches(value!).map((m) => m.group(0)).toSet();
        expect(actual, expected, reason: '${entry.key} in $locale');
      }
    }
  });

  test('the family.* tree exists in all locales', () {
    final familyKeys = base.keys.where((k) => k.startsWith('family.')).toList();
    expect(familyKeys.length, greaterThan(50));
    for (final locale in _locales) {
      for (final key in familyKeys) {
        expect(
          translations[locale]!.containsKey(key),
          isTrue,
          reason: '$key missing in $locale',
        );
      }
    }
  });

  test('every Phase 3b error code has an errors.* translation in all locales',
      () {
    for (final code in _phase3bErrorCodes) {
      final key = 'errors.${code.toLowerCase()}';
      for (final locale in _locales) {
        expect(
          translations[locale]!.containsKey(key),
          isTrue,
          reason: '$key missing in $locale',
        );
      }
    }
  });

  test('every device.* key used in lib exists in all locales', () {
    final used = <String>{};
    final pattern = RegExp(r"'(device\.[a-z_]+(?:\.[a-z_]+)*)'");
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      for (final m in pattern.allMatches(entity.readAsStringSync())) {
        used.add(m.group(1)!);
      }
    }
    expect(used.length, greaterThan(40));
    for (final key in used) {
      for (final locale in _locales) {
        expect(
          translations[locale]!.containsKey(key),
          isTrue,
          reason: '$key missing in $locale',
        );
      }
    }
  });

  test('device.* placeholders match across locales', () {
    final placeholder = RegExp(r'\{[a-z_]+\}');
    for (final entry
        in base.entries.where((e) => e.key.startsWith('device.'))) {
      final expected =
          placeholder.allMatches(entry.value).map((m) => m.group(0)).toSet();
      for (final locale in _locales.skip(1)) {
        final actual = placeholder
            .allMatches(translations[locale]![entry.key]!)
            .map((m) => m.group(0))
            .toSet();
        expect(actual, expected, reason: '${entry.key} in $locale');
      }
    }
  });
}
