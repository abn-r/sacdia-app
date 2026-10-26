import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sacdia_app/core/widgets/evidence_staging/evidence_staging_manager.dart';
import 'package:sacdia_app/core/widgets/evidence_staging/staged_file.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('send-to-validation confirm is a success (green) action',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EvidenceStagingManager(
            existingFiles: const [
              StagedFile(
                id: 'remote-1',
                name: 'Evidencia.pdf',
                type: 'pdf',
                status: StagedFileStatus.uploaded,
              ),
            ],
            maxFiles: 5,
            canModify: true,
            onUpload: (_, __, ___) async {},
            onDeleteRemote: (_) async {},
            onSubmit: () async {},
            fileNameBuilder: (name, _) => name,
          ),
        ),
      ),
    );
    await tester.pump();

    // No translations are loaded: the labels are the raw keys.
    await tester.tap(find.text('core.evidence_staging.btn_submit'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final confirm = tester.widget<SacButton>(
      find.widgetWithText(SacButton, 'core.evidence_staging.submit'),
    );
    expect(confirm.variant, SacButtonVariant.success);
    expect(confirm.variant, isNot(SacButtonVariant.destructive));
  });
}
