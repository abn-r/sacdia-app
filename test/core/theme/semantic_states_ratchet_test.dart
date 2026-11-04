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
  'lib/features/auth/presentation/widgets/welcome_carousel_visuals.dart': 4,
  'lib/features/units/presentation/views/units_list_view.dart': 1,
};

// BASELINE:errorToString
const Map<String, int> _errorToStringBaseline = {
  'lib/features/coordinator/presentation/providers/coordinator_providers.dart':
      1,
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
