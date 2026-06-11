import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('runtime UI uses HugeIcons instead of Material or Cupertino icon APIs',
      () {
    final projectRoot = Directory.current;
    final libDir = Directory('${projectRoot.path}/lib');

    final violations = <String>[];

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('.g.dart') ||
          entity.path.endsWith('.freezed.dart')) {
        continue;
      }

      final relativePath = entity.path.substring(projectRoot.path.length + 1);
      final source = _stripDartComments(entity.readAsStringSync());
      final lines = source.split('\n');

      for (var index = 0; index < lines.length; index++) {
        final line = lines[index];
        if (_containsForbiddenIconApi(line)) {
          violations.add('$relativePath:${index + 1}: ${line.trim()}');
        }
      }

      _addImplicitAppBarViolations(source, relativePath, violations);
    }

    expect(
      violations,
      isEmpty,
      reason: 'Use HugeIcon + HugeIcons.* in runtime UI. Offenders:\n'
          '${violations.join('\n')}',
    );
  });
}

bool _containsForbiddenIconApi(String line) {
  return RegExp(r'(^|[^A-Za-z0-9_])Icons\.').hasMatch(line) ||
      line.contains('CupertinoIcons.') ||
      RegExp(r'\bIconData\b').hasMatch(line) ||
      RegExp(r'(^|[^A-Za-z0-9_])Icon\(').hasMatch(line) ||
      RegExp(r'(^|[^A-Za-z0-9_])(BackButton|CloseButton)\(').hasMatch(line);
}

void _addImplicitAppBarViolations(
  String source,
  String relativePath,
  List<String> violations,
) {
  for (final widgetName in ['AppBar', 'SliverAppBar']) {
    var offset = 0;

    while (offset < source.length) {
      final index = source.indexOf('$widgetName(', offset);
      if (index == -1) break;

      if (!_hasIdentifierBoundary(source, index)) {
        offset = index + widgetName.length;
        continue;
      }

      final openParen = index + widgetName.length;
      final closeParen = _findMatchingParen(source, openParen);
      if (closeParen == -1) break;

      final args = source.substring(openParen + 1, closeParen);
      final hasExplicitLeading = _hasTopLevelNamedArg(args, 'leading');
      final disablesImplicitLeading = _topLevelNamedArgStartsWith(
        args,
        'automaticallyImplyLeading',
        'false',
      );

      if (!hasExplicitLeading && !disablesImplicitLeading) {
        final line = _lineNumberAt(source, index);
        violations.add(
          '$relativePath:$line: $widgetName relies on implicit Material leading icon',
        );
      }

      offset = closeParen + 1;
    }
  }
}

bool _hasIdentifierBoundary(String source, int index) {
  if (index == 0) return true;
  final previous = source[index - 1];
  return !RegExp(r'[A-Za-z0-9_]').hasMatch(previous);
}

int _findMatchingParen(String source, int openParen) {
  var depth = 0;
  var inSingleQuote = false;
  var inDoubleQuote = false;
  var escaped = false;

  for (var i = openParen; i < source.length; i++) {
    final char = source[i];

    if (inSingleQuote || inDoubleQuote) {
      if (escaped) {
        escaped = false;
        continue;
      }

      if (char == r'\') {
        escaped = true;
        continue;
      }

      if (inSingleQuote && char == "'") {
        inSingleQuote = false;
      } else if (inDoubleQuote && char == '"') {
        inDoubleQuote = false;
      }
      continue;
    }

    if (char == "'") {
      inSingleQuote = true;
      continue;
    }

    if (char == '"') {
      inDoubleQuote = true;
      continue;
    }

    if (char == '(') {
      depth++;
    } else if (char == ')') {
      depth--;
      if (depth == 0) return i;
    }
  }

  return -1;
}

bool _hasTopLevelNamedArg(String args, String name) {
  return _topLevelNamedArgIndex(args, name) != -1;
}

bool _topLevelNamedArgStartsWith(String args, String name, String value) {
  final index = _topLevelNamedArgIndex(args, name);
  if (index == -1) return false;

  var valueStart = index + name.length + 1;
  while (valueStart < args.length && args[valueStart].trim().isEmpty) {
    valueStart++;
  }

  return args.substring(valueStart).startsWith(value);
}

int _topLevelNamedArgIndex(String args, String name) {
  var depth = 0;
  var inSingleQuote = false;
  var inDoubleQuote = false;
  var escaped = false;
  final token = '$name:';

  for (var i = 0; i < args.length; i++) {
    final char = args[i];

    if (inSingleQuote || inDoubleQuote) {
      if (escaped) {
        escaped = false;
        continue;
      }

      if (char == r'\') {
        escaped = true;
        continue;
      }

      if (inSingleQuote && char == "'") {
        inSingleQuote = false;
      } else if (inDoubleQuote && char == '"') {
        inDoubleQuote = false;
      }
      continue;
    }

    if (char == "'") {
      inSingleQuote = true;
      continue;
    }

    if (char == '"') {
      inDoubleQuote = true;
      continue;
    }

    if ('([{'.contains(char)) {
      depth++;
    } else if (')]}'.contains(char)) {
      depth--;
    }

    if (depth == 0 && args.startsWith(token, i)) {
      final hasBoundary =
          i == 0 || !RegExp(r'[A-Za-z0-9_]').hasMatch(args[i - 1]);
      if (hasBoundary) return i;
    }
  }

  return -1;
}

int _lineNumberAt(String source, int index) {
  return '\n'.allMatches(source.substring(0, index)).length + 1;
}

String _stripDartComments(String source) {
  final buffer = StringBuffer();
  var inLineComment = false;
  var inBlockComment = false;
  var inSingleQuote = false;
  var inDoubleQuote = false;
  var inRawString = false;

  for (var i = 0; i < source.length; i++) {
    final char = source[i];
    final next = i + 1 < source.length ? source[i + 1] : '';
    final prev = i > 0 ? source[i - 1] : '';

    if (inLineComment) {
      if (char == '\n') {
        inLineComment = false;
        buffer.write(char);
      }
      continue;
    }

    if (inBlockComment) {
      if (char == '*' && next == '/') {
        inBlockComment = false;
        i++;
      } else if (char == '\n') {
        buffer.write(char);
      }
      continue;
    }

    if (!inSingleQuote &&
        !inDoubleQuote &&
        char == 'r' &&
        (next == "'" || next == '"')) {
      inRawString = true;
      buffer.write(char);
      continue;
    }

    if (!inSingleQuote && !inDoubleQuote && char == '/' && next == '/') {
      inLineComment = true;
      i++;
      continue;
    }

    if (!inSingleQuote && !inDoubleQuote && char == '/' && next == '*') {
      inBlockComment = true;
      i++;
      continue;
    }

    if (!inDoubleQuote && char == "'" && (prev != r'\' || inRawString)) {
      inSingleQuote = !inSingleQuote;
      if (!inSingleQuote) inRawString = false;
    } else if (!inSingleQuote && char == '"' && (prev != r'\' || inRawString)) {
      inDoubleQuote = !inDoubleQuote;
      if (!inDoubleQuote) inRawString = false;
    }

    buffer.write(char);
  }

  return buffer.toString();
}
