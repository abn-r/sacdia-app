import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Ratchet guard for semantic state colors and error text.
///
/// Counts rule hits per file under `lib/features/**/presentation/**` and
/// compares them with the checked-in baselines below. A file may never go
/// above its baseline (and new files start at zero). When a count drops below
/// its baseline the test fails too, so the baseline is lowered and the
/// ratchet tightens. Comments are ignored.

final _scanRoot = Directory('lib/features');

/// Light-only pastels (and light-only theme constants) that glare on the
/// OLED dark theme. Use `context.sac.xContainer` / `onXContainer` instead.
final _lightOnlyColor = RegExp(
  r'AppColors\.(\w+Light|light\w+|primarySurface)\b',
);

/// Raw exception text shown to users. Use `SacErrorState` /
/// `userErrorMessage` so the message is localized and safe.
final _errorToString = RegExp(r'\b(e|err|error)\.toString\(\)');

/// `backgroundColor: AppColors.secondary|success` inside a `SacSnackBar`
/// call. Use `isSuccess: true`. This is a hard ban (empty baseline).
final _snackBarCall = RegExp(r'SacSnackBar\.show(?:Messenger)?\(');
final _successOverride = RegExp(
  r'backgroundColor:\s*AppColors\.(?:secondary|success)\b',
);

/// Money formatted outside `SacMoney` (hard ban, empty baseline).
final _numberFormatCurrency = RegExp(
  r'NumberFormat\.(?:currency|simpleCurrency|compactCurrency)\(',
);

/// A `DateFormat` call with a quoted `'es'` locale (hard ban, empty baseline).
/// Dates follow the app language through `Intl.defaultLocale`.
final _hardcodedDateLocale = RegExp(
  r'''DateFormat(?:\.\w+)?\([^;]*?['"]es['"]''',
);

/// Files that own the formatting rules and may use the banned calls.
const _formattingOwners = {
  'lib/core/utils/money_format.dart',
  'lib/core/utils/date_formatter.dart',
};

// BASELINE:lightOnlyColor
const Map<String, int> _lightOnlyColorBaseline = {
  'lib/features/achievements/presentation/views/achievement_detail_sheet.dart':
      1,
  'lib/features/achievements/presentation/widgets/achievement_category_section.dart':
      1,
  'lib/features/activities/presentation/views/activity_detail_view.dart': 2,
  'lib/features/activities/presentation/widgets/activity_hero_section.dart': 1,
  'lib/features/activities/presentation/widgets/attendance_button.dart': 1,
  'lib/features/auth/presentation/views/forgot_password_view.dart': 2,
  'lib/features/auth/presentation/views/login_view.dart': 2,
  'lib/features/auth/presentation/views/register_view.dart': 2,
  'lib/features/auth/presentation/widgets/welcome_carousel_visuals.dart': 4,
  'lib/features/camporee_supplies/presentation/views/camporee_supply_plan_view.dart':
      1,
  'lib/features/camporees/presentation/views/camporee_payments_view.dart': 4,
  'lib/features/camporees/presentation/views/camporee_register_member_view.dart':
      1,
  'lib/features/certifications/presentation/views/certification_progress_view.dart':
      1,
  'lib/features/certifications/presentation/views/certifications_list_view.dart':
      1,
  'lib/features/certifications/presentation/views/my_certifications_view.dart':
      3,
  'lib/features/certifications/presentation/widgets/certification_component_field.dart':
      1,
  'lib/features/certifications/presentation/widgets/certification_requirement_status_badge.dart':
      3,
  'lib/features/classes/presentation/views/class_detail_with_progress_view.dart':
      1,
  'lib/features/classes/presentation/views/classes_list_view.dart': 1,
  'lib/features/classes/presentation/widgets/module_expansion_tile.dart': 1,
  'lib/features/classes/presentation/widgets/requirement_status_badge.dart': 4,
  'lib/features/dashboard/presentation/widgets/birthday_celebration.dart': 1,
  'lib/features/dashboard/presentation/widgets/current_class_card.dart': 2,
  'lib/features/dashboard/presentation/widgets/membership_status_banner.dart':
      2,
  'lib/features/dashboard/presentation/widgets/quick_stats_card.dart': 3,
  'lib/features/device_mode/presentation/views/device_requirement_view.dart': 1,
  'lib/features/device_mode/presentation/views/pair_device_view.dart': 1,
  'lib/features/device_mode/presentation/widgets/device_offline_banner.dart': 1,
  'lib/features/enrollment/presentation/views/enrollment_form_view.dart': 1,
  'lib/features/evidence_folder/presentation/views/evidence_section_detail_view.dart':
      7,
  'lib/features/evidence_folder/presentation/widgets/folder_closed_banner.dart':
      2,
  'lib/features/evidence_folder/presentation/widgets/section_status_badge.dart':
      5,
  'lib/features/family/presentation/views/add_dependent_view.dart': 1,
  'lib/features/family/presentation/views/pairing_qr_view.dart': 1,
  'lib/features/family/presentation/views/redeem_link_code_view.dart': 1,
  'lib/features/finances/presentation/widgets/closed_period_banner.dart': 1,
  'lib/features/home/presentation/widgets/club_context_card.dart': 4,
  'lib/features/honors/presentation/views/honor_detail_view.dart': 1,
  'lib/features/honors/presentation/views/my_honors_view.dart': 1,
  'lib/features/honors/presentation/widgets/choice_group_header.dart': 2,
  'lib/features/insurance/presentation/views/insurance_form_sheet.dart': 3,
  'lib/features/insurance/presentation/widgets/insurance_status_badge.dart': 3,
  'lib/features/legal/presentation/views/legal_acceptance_view.dart': 1,
  'lib/features/master_honors/presentation/widgets/master_honor_badge.dart': 4,
  'lib/features/master_honors/presentation/widgets/master_honor_history_section.dart':
      1,
  'lib/features/materials/presentation/views/order_review_view.dart': 9,
  'lib/features/materials/presentation/views/order_summary_view.dart': 1,
  'lib/features/materials/presentation/views/payment_details_view.dart': 1,
  'lib/features/materials/presentation/widgets/material_status_badge.dart': 4,
  'lib/features/materials/presentation/widgets/qty_stepper.dart': 2,
  'lib/features/members/presentation/views/create_minor_view.dart': 1,
  'lib/features/members/presentation/views/member_profile_view.dart': 5,
  'lib/features/members/presentation/widgets/join_request_card.dart': 2,
  'lib/features/monthly_reports/presentation/views/monthly_report_detail_view.dart':
      3,
  'lib/features/monthly_reports/presentation/views/monthly_reports_list_view.dart':
      3,
  'lib/features/monthly_reports/presentation/views/monthly_reports_visible_list_view.dart':
      4,
  'lib/features/post_registration/presentation/views/club_selection_step_view.dart':
      1,
  'lib/features/post_registration/presentation/views/emergency_contacts_view.dart':
      1,
  'lib/features/post_registration/presentation/views/personal_info_step_view.dart':
      7,
  'lib/features/post_registration/presentation/widgets/club_type_selector.dart':
      1,
  'lib/features/post_registration/presentation/widgets/profile_photo_picker.dart':
      1,
  'lib/features/profile/presentation/utils/change_password_flow.dart': 1,
  'lib/features/profile/presentation/views/edit_profile_view.dart': 1,
  'lib/features/profile/presentation/widgets/delete_account_confirm_dialog.dart':
      1,
  'lib/features/profile/presentation/widgets/delete_account_dependents_dialog.dart':
      1,
  'lib/features/profile/presentation/widgets/profile_honors_section.dart': 1,
  'lib/features/rankings/presentation/widgets/ranking_skeleton.dart': 2,
  'lib/features/role_assignments/presentation/views/role_assignments_view.dart':
      4,
  'lib/features/teen/presentation/views/teen_pending_home_view.dart': 1,
  'lib/features/transfers/presentation/views/transfer_request_detail_view.dart':
      4,
  'lib/features/transfers/presentation/views/transfer_requests_view.dart': 7,
  'lib/features/units/presentation/views/unit_detail_view.dart': 1,
  'lib/features/units/presentation/views/units_list_view.dart': 1,
  'lib/features/validation/presentation/widgets/eligibility_banner.dart': 1,
  'lib/features/validation/presentation/widgets/validation_section.dart': 1,
  'lib/features/validation/presentation/widgets/validation_status_badge.dart':
      4,
};

// BASELINE:errorToString
const Map<String, int> _errorToStringBaseline = {
  'lib/features/activities/presentation/views/activity_detail_view.dart': 1,
  'lib/features/auth/presentation/widgets/auth_gate.dart': 1,
  'lib/features/camporee_orders/presentation/providers/camporee_orders_providers.dart':
      1,
  'lib/features/camporee_supplies/presentation/providers/camporee_supplies_providers.dart':
      1,
  'lib/features/camporees/presentation/views/camporee_detail_view.dart': 1,
  'lib/features/camporees/presentation/views/camporee_members_view.dart': 1,
  'lib/features/camporees/presentation/views/camporee_payments_view.dart': 1,
  'lib/features/camporees/presentation/views/camporee_register_member_view.dart':
      1,
  'lib/features/camporees/presentation/views/camporees_list_view.dart': 2,
  'lib/features/camporees/presentation/views/judge_assignments_view.dart': 1,
  'lib/features/camporees/presentation/views/judge_score_entry_view.dart': 2,
  'lib/features/certifications/presentation/views/certification_detail_view.dart':
      1,
  'lib/features/certifications/presentation/views/certification_progress_view.dart':
      2,
  'lib/features/certifications/presentation/views/certifications_list_view.dart':
      2,
  'lib/features/certifications/presentation/views/my_certifications_view.dart':
      2,
  'lib/features/classes/presentation/roadmap/widgets/roadmap_screen_connected.dart':
      1,
  'lib/features/classes/presentation/sheets/enroll_previous_class_sheet.dart':
      1,
  'lib/features/classes/presentation/views/class_counselor_assignments_view.dart':
      1,
  'lib/features/classes/presentation/views/class_detail_view.dart': 1,
  'lib/features/classes/presentation/views/class_detail_with_progress_view.dart':
      1,
  'lib/features/classes/presentation/views/class_members_progress_view.dart': 1,
  'lib/features/classes/presentation/views/class_modules_view.dart': 1,
  'lib/features/classes/presentation/views/classes_list_view.dart': 1,
  'lib/features/classes/presentation/views/teaching_scope_view.dart': 2,
  'lib/features/club/presentation/views/club_detail_view.dart': 1,
  'lib/features/club/presentation/views/club_view.dart': 1,
  'lib/features/coordinator/presentation/providers/coordinator_providers.dart':
      1,
  'lib/features/evidence_folder/presentation/providers/evidence_folder_providers.dart':
      3,
  'lib/features/evidence_folder/presentation/views/evidence_folder_view.dart':
      1,
  'lib/features/home/presentation/views/home_view.dart': 1,
  'lib/features/honors/presentation/views/honor_detail_view.dart': 1,
  'lib/features/honors/presentation/views/honor_evidence_view.dart': 1,
  'lib/features/honors/presentation/views/honor_requirements_view.dart': 2,
  'lib/features/insurance/presentation/views/insurance_view.dart': 1,
  'lib/features/inventory/presentation/views/inventory_view.dart': 1,
  'lib/features/materials/presentation/views/catalog_view.dart': 1,
  'lib/features/materials/presentation/views/order_history_view.dart': 1,
  'lib/features/materials/presentation/views/order_review_view.dart': 1,
  'lib/features/materials/presentation/views/payment_details_view.dart': 1,
  'lib/features/materials/presentation/views/product_detail_view.dart': 1,
  'lib/features/members/presentation/views/annual_continuations_view.dart': 1,
  'lib/features/members/presentation/views/members_view.dart': 2,
  'lib/features/monthly_reports/presentation/views/monthly_report_detail_view.dart':
      2,
  'lib/features/monthly_reports/presentation/views/monthly_reports_list_view.dart':
      1,
  'lib/features/monthly_reports/presentation/views/monthly_reports_visible_list_view.dart':
      1,
  'lib/features/payment_orders/presentation/views/issue_payment_order_view.dart':
      2,
  'lib/features/payment_orders/presentation/views/payment_order_detail_view.dart':
      1,
  'lib/features/payment_orders/presentation/views/payment_orders_view.dart': 1,
  'lib/features/profile/presentation/views/active_sessions_view.dart': 1,
  'lib/features/profile/presentation/views/data_export_view.dart': 1,
  'lib/features/profile/presentation/views/medical_info_view.dart': 4,
  'lib/features/profile/presentation/views/profile_view.dart': 1,
  'lib/features/resources/presentation/widgets/resource_detail_sheet.dart': 1,
  'lib/features/role_assignments/presentation/views/role_assignments_view.dart':
      1,
  'lib/features/settings/presentation/providers/sync_cache_providers.dart': 1,
  'lib/features/support/presentation/views/faq_view.dart': 1,
  'lib/features/transfers/presentation/views/transfer_request_detail_view.dart':
      1,
  'lib/features/transfers/presentation/views/transfer_requests_view.dart': 1,
  'lib/features/units/presentation/views/unit_points_history_view.dart': 1,
};

// BASELINE:snackBarSuccessOverride
const Map<String, int> _snackBarSuccessOverrideBaseline = {};

// BASELINE:numberFormatCurrency
const Map<String, int> _numberFormatCurrencyBaseline = {};

// BASELINE:hardcodedDateLocale
const Map<String, int> _hardcodedDateLocaleBaseline = {};

bool _isPresentationFile(String path) =>
    path.contains('/presentation/') &&
    path.endsWith('.dart') &&
    !path.endsWith('.g.dart') &&
    !path.endsWith('.freezed.dart');

/// Source with whole-line and trailing `//` comments removed.
String _stripComments(String source) => source
    .split('\n')
    .map((line) =>
        line.trimLeft().startsWith('//') ? '' : line.split('//').first)
    .join('\n');

Map<String, String> _presentationSources() {
  final result = <String, String>{};
  for (final entity in _scanRoot.listSync(recursive: true)) {
    if (entity is! File) continue;
    final path = entity.path.replaceAll(r'\', '/');
    if (!_isPresentationFile(path)) continue;
    result[path] = _stripComments(entity.readAsStringSync());
  }
  return result;
}

/// Every `lib/**` source except the formatting owners, comments stripped.
Map<String, String> _libSources() {
  final result = <String, String>{};
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File) continue;
    final path = entity.path.replaceAll(r'\', '/');
    if (!path.endsWith('.dart') ||
        path.endsWith('.g.dart') ||
        path.endsWith('.freezed.dart') ||
        _formattingOwners.contains(path)) {
      continue;
    }
    result[path] = _stripComments(entity.readAsStringSync());
  }
  return result;
}

int _countSnackBarOverrides(String source) {
  var count = 0;
  for (final call in _snackBarCall.allMatches(source)) {
    var depth = 1;
    var i = call.end;
    while (i < source.length && depth > 0) {
      final ch = source[i];
      if (ch == '(') depth++;
      if (ch == ')') depth--;
      i++;
    }
    count += _successOverride.allMatches(source.substring(call.end, i)).length;
  }
  return count;
}

void _expectRatchet({
  required Map<String, int> actual,
  required Map<String, int> baseline,
  required String howToFix,
}) {
  final raised = <String>[];
  final lowered = <String>[];
  for (final path in {...actual.keys, ...baseline.keys}) {
    final now = actual[path] ?? 0;
    final allowed = baseline[path] ?? 0;
    if (now > allowed) raised.add('$path: $now (baseline $allowed)');
    if (now < allowed) lowered.add('$path: $now (baseline $allowed)');
  }
  raised.sort();
  lowered.sort();
  expect(
    raised,
    isEmpty,
    reason: 'More hits than the baseline allows.\n$howToFix\n'
        '${raised.join('\n')}',
  );
  expect(
    lowered,
    isEmpty,
    reason: 'Great, fewer hits than the baseline. Lower the baseline in '
        'test/core/theme/semantic_states_ratchet_test.dart to the new '
        'counts (remove the entry when it reaches 0):\n${lowered.join('\n')}',
  );
}

void main() {
  final sources = _presentationSources();

  Map<String, int> countWith(int Function(String source) counter) {
    final result = <String, int>{};
    sources.forEach((path, source) {
      final count = counter(source);
      if (count > 0) result[path] = count;
    });
    return result;
  }

  test('no new light-only AppColors pastels in feature presentation', () {
    _expectRatchet(
      actual: countWith((s) => _lightOnlyColor.allMatches(s).length),
      baseline: _lightOnlyColorBaseline,
      howToFix: 'Use context.sac.successContainer / warningContainer / '
          'errorContainer / infoContainer (and their on* pair) or other '
          'context.sac tokens; AppColors.*Light does not adapt to dark mode.',
    );
  });

  test('no new raw exception text (e.toString()) in feature presentation', () {
    _expectRatchet(
      actual: countWith((s) => _errorToString.allMatches(s).length),
      baseline: _errorToStringBaseline,
      howToFix: 'Do not show raw exceptions. Render SacErrorState or map the '
          'error with userErrorMessage so the text is localized.',
    );
  });

  test('success snackbars use isSuccess, not a green backgroundColor', () {
    _expectRatchet(
      actual: countWith(_countSnackBarOverrides),
      baseline: _snackBarSuccessOverrideBaseline,
      howToFix: 'Pass isSuccess: true to SacSnackBar.show and drop '
          'backgroundColor (white on AppColors.secondary is only 2.26:1).',
    );
  });

  group('formatting', () {
    final libSources = _libSources();

    Map<String, int> libCountWith(RegExp pattern) {
      final result = <String, int>{};
      libSources.forEach((path, source) {
        final count = pattern.allMatches(source).length;
        if (count > 0) result[path] = count;
      });
      return result;
    }

    test('money goes through SacMoney, not NumberFormat.*Currency', () {
      _expectRatchet(
        actual: libCountWith(_numberFormatCurrency),
        baseline: _numberFormatCurrencyBaseline,
        howToFix: 'Use SacMoney.format / fromCentavos / compact from '
            'lib/core/utils/money_format.dart. One es_MX format for every '
            'amount, no "MXN" suffix.',
      );
    });

    test('dates follow the app language: no hardcoded DateFormat locale', () {
      _expectRatchet(
        actual: libCountWith(_hardcodedDateLocale),
        baseline: _hardcodedDateLocaleBaseline,
        howToFix: 'Drop the locale argument: DateFormat(pattern) uses '
            'Intl.defaultLocale, which main.dart keeps in sync with the '
            'language the user picked. Or use SacDateFormatter '
            '(lib/core/utils/date_formatter.dart). Never pin "es".',
      );
    });
  });
}
