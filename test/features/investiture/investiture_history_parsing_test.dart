import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/investiture/data/datasources/investiture_remote_data_source.dart';
import 'package:sacdia_app/features/investiture/data/models/investiture_history_entry_model.dart';
import 'package:sacdia_app/features/investiture/domain/entities/investiture_history_entry.dart';

void main() {
  test('extracts history from legacy success envelope', () {
    final list = extractInvestitureListFromResponse({
      'status': 'success',
      'data': {
        'enrollment_id': 5,
        'history': [
          {
            'history_id': 10,
            'action': 'SUBMITTED',
            'performed_by': {
              'name': 'Abner',
              'paternal_last_name': 'Reyes',
            },
            'comments': 'Lista para revisar',
            'created_at': '2026-06-15T20:00:00.000Z',
          },
        ],
      },
    }, 'history');

    expect(list, hasLength(1));

    final entry = InvestitureHistoryEntryModel.fromJson(
      list.first as Map<String, dynamic>,
    ).toEntity();

    expect(entry.id, 10);
    expect(entry.action, InvestitureAction.submitted);
    expect(entry.performerFullName, 'Abner Reyes');
    expect(entry.comments, 'Lista para revisar');
  });

  test('maps multi-step approval actions explicitly', () {
    expect(
      InvestitureAction.fromString('CLUB_APPROVED'),
      InvestitureAction.clubApproved,
    );
    expect(
      InvestitureAction.fromString('COORDINATOR_APPROVED'),
      InvestitureAction.coordinatorApproved,
    );
    expect(
      InvestitureAction.fromString('FIELD_APPROVED'),
      InvestitureAction.fieldApproved,
    );
  });
}
