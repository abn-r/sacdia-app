import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/auth/club_role_names.dart';
import 'package:sacdia_app/core/authorization/generated/role_names.dart';

/// Files in `lib/features` that still contain a single-quoted literal equal
/// to a club role name or Spanish alias, and why each one is legitimate.
/// Club roles are classified through `ClubRoleNames` / `canonicalClubRoleName`
/// (`lib/core/auth/club_role_names.dart`); do not grow this list for role
/// logic.
const _allowlist = <String>{
  // `name.contains('instructor')` over honor/certificate text, not clubRole.
  'lib/features/certificate_import/domain/entities/certificate_import_item.dart',
  // JSON key `json['instructor']` and l10n named arg `{'instructor': ...}`.
  'lib/features/certificate_import/data/models/certificate_import_item_model.dart',
  'lib/features/honors/presentation/widgets/instructor_proposal_card.dart',
  'lib/features/honors/data/models/instructor_proposal_model.dart',
  'lib/features/honors/data/models/user_honor_model.dart',
  // JSON key `gm['instructor']` (flag of the guide_major object, not a role).
  'lib/features/members/data/models/role_candidate_model.dart',
  // JSON key `json['member']` (a nested object, not a role value).
  'lib/features/qr/data/models/qr_scan_result_model.dart',
  'lib/features/rankings/data/models/member_ranking_dto.dart',
  'lib/features/virtual_card/data/models/virtual_card_model.dart',
};

void main() {
  test('club role literals stay out of lib/features', () {
    final forbidden = <String>{
      ...kClubRoleNames,
      ...kClubRoleSpanishAliases.keys,
    };
    final literal = RegExp("'([^'\\n]*)'");

    final offenders = <String>{};
    final files = Directory('lib/features')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

    for (final file in files) {
      for (final line in file.readAsLinesSync()) {
        if (line.trimLeft().startsWith('//')) continue;
        final code = line.split(RegExp(r'\s//')).first;
        if (literal.allMatches(code).any((m) => forbidden.contains(m[1]))) {
          offenders.add(file.path.replaceAll(r'\', '/'));
          break;
        }
      }
    }

    expect(
      offenders,
      _allowlist,
      reason:
          'Use ClubRoleNames / canonicalClubRoleName instead of role literals '
          'in lib/features. If a literal is legitimate (JSON key, l10n arg), '
          'add the file to _allowlist with a comment; remove stale entries.',
    );
  });
}
