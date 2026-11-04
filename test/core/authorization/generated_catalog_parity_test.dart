import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/auth/club_role_names.dart';
import 'package:sacdia_app/core/authorization/generated/capability_keys.dart';
import 'package:sacdia_app/core/authorization/generated/permission_keys.dart';
import 'package:sacdia_app/core/authorization/generated/role_names.dart';
import 'package:sacdia_app/core/authorization/role_aliases.dart';

/// Single-quoted tokens shaped like `a:b` that are NOT permissions.
const _nonPermissionTokens = <String>{
  // Dart VM pragma annotation.
  'vm:entry-point',
  // FCM notification types (push_notification_service.dart, notification_type_badge.dart).
  'activities:foreground',
  'validation:foreground',
  'requests:foreground',
  'membership_requests:new_request',
  'investiture:foreground',
  'units:member_of_month',
  'monthly_reports:reminder',
  // FCM family push types (family_push_route.dart).
  'family:security',
  'family:evidence_uploaded',
  'family:age_nudge',
  'family:teen_reminder',
  // Consent evidence upload type tag (acting_consent_form_card.dart).
  'consent:evidence',
  // FCM investiture notification types (investiture_notification_routes.dart).
  'investiture:invested',
  'investiture:rejected',
};

void main() {
  test('ClubRoleNames only uses names from the generated club catalog', () {
    final all = <String>{
      ClubRoleNames.director,
      ClubRoleNames.deputyDirector,
      ClubRoleNames.secretary,
      ClubRoleNames.treasurer,
      ClubRoleNames.secretaryTreasurer,
      ClubRoleNames.counselor,
      ClubRoleNames.member,
    };
    expect(all.difference(kClubRoleNames.toSet()), isEmpty);
  });

  test('kGlobalRoleAliases keys and values are generated global roles', () {
    final known = kGlobalRoleNames.toSet();
    final used = <String>{
      ...kGlobalRoleAliases.keys,
      for (final v in kGlobalRoleAliases.values) ...v,
    };
    expect(used.difference(known), isEmpty);
  });

  test('kCapabilityKeys is the generated catalog of 47 sorted keys', () {
    expect(kCapabilityKeys, hasLength(47));
    final sorted = kCapabilityKeys.toList()..sort();
    expect(kCapabilityKeys.toList(), sorted);
    // Una capacidad tiene forma `a.b`, nunca `a:b` (eso es un permiso).
    for (final key in kCapabilityKeys) {
      expect(key, matches(RegExp(r'^[a-z_]+(\.[a-z_]+)+$')), reason: key);
      expect(kPermissionKeys.contains(key), isFalse, reason: key);
    }
  });

  test('every capability referenced in lib/ exists in kCapabilityKeys', () {
    // `hasCapability(user, 'a.b')` y `capability: 'a.b'` (gates del catálogo).
    final re = RegExp(
      r"(?:hasCapability\([^,]+,\s*|capability:\s*)'([a-z_]+(?:\.[a-z_]+)+)'",
    );
    final unknown = <String>{};
    var referenced = 0;
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.contains('lib/core/authorization/generated/')) continue;
      final source = entity.readAsStringSync();
      for (final m in re.allMatches(source)) {
        referenced++;
        final key = m.group(1)!;
        if (!kCapabilityKeys.contains(key)) {
          unknown.add('$key (${entity.path})');
        }
      }
    }
    expect(referenced, greaterThan(0), reason: 'the scan found no usages');
    expect(unknown, isEmpty);
  });

  test('every permission literal in lib/ exists in kPermissionKeys', () {
    final re = RegExp(r"'([a-z_]+:[a-z_-]+)'");
    final unknown = <String>{};
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.contains('lib/core/authorization/generated/')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final trimmed = lines[i].trimLeft();
        if (trimmed.startsWith('import ') ||
            trimmed.startsWith('export ') ||
            trimmed.startsWith('part ')) {
          continue;
        }
        for (final m in re.allMatches(lines[i])) {
          final t = m.group(1)!;
          if (!kPermissionKeys.contains(t) &&
              !_nonPermissionTokens.contains(t)) {
            unknown.add('$t (${entity.path}:${i + 1})');
          }
        }
      }
    }
    expect(unknown, isEmpty);
  });
}
