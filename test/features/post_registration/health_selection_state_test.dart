import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/post_registration/presentation/utils/health_selection_state.dart';

void main() {
  group('health selection pending changes', () {
    test('treats explicit none as saveable even without existing records', () {
      expect(
        hasHealthSelectionPendingChanges(
          noneExplicit: true,
          hasNewSelections: false,
          hasModifiedRegistered: false,
        ),
        isTrue,
      );
    });

    test('keeps the save action disabled when nothing was changed', () {
      expect(
        hasHealthSelectionPendingChanges(
          noneExplicit: false,
          hasNewSelections: false,
          hasModifiedRegistered: false,
        ),
        isFalse,
      );
    });
  });
}
