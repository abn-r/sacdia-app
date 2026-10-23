import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// FP-60: the legal-representative step/view/model and its data-source calls
/// were removed in favour of guardianships (family feature). This static check
/// keeps them from coming back.
void main() {
  final lib = Directory('lib');

  List<File> dartFiles() => lib
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('legal_representative view and model files no longer exist', () {
    final offenders = dartFiles()
        .where((f) =>
            f.path.endsWith('legal_representative_view.dart') ||
            f.path.endsWith('legal_representative_model.dart'))
        .map((f) => f.path)
        .toList();

    expect(offenders, isEmpty);
  });

  test('no source references legal_representative_view or its model', () {
    final offenders = <String>[];
    for (final file in dartFiles()) {
      final content = file.readAsStringSync();
      if (content.contains('legal_representative_view') ||
          content.contains('legal_representative_model') ||
          content.contains('LegalRepresentativeView') ||
          content.contains('LegalRepresentativeModel')) {
        offenders.add(file.path);
      }
    }

    expect(offenders, isEmpty);
  });

  test('personal info data source has no legal-representative endpoints', () {
    final content = File(
      'lib/features/post_registration/data/datasources/'
      'personal_info_remote_data_source.dart',
    ).readAsStringSync();

    expect(content.contains('legal-representative'), isFalse);
    expect(content.contains('requires-legal-representative'), isFalse);
  });
}
