import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:sacdia_app/features/investiture/domain/entities/investiture_status.dart';
import 'package:sacdia_app/features/members/presentation/utils/member_profile_display.dart';

void main() {
  group('member profile display formatters', () {
    test('formats baptized value without leaking Dart interpolation syntax',
        () {
      final value = formatMemberBaptismDisplay(
        baptized: true,
        baptismDate: DateTime(2026, 6, 18),
        yesLabel: 'Sí',
        dateFormat: DateFormat('dd/MM/yyyy'),
      );

      expect(value, 'Sí · 18/06/2026');
      expect(value, isNot(contains(r'${')));
    });

    test('formats non-baptized value with localized label', () {
      final value = formatMemberBaptismDisplay(
        baptized: false,
        baptismDate: null,
        noLabel: 'No',
      );

      expect(value, 'No');
    });

    test('uses compact blood type labels for backend enum values', () {
      expect(formatMemberBloodTypeDisplay('O_POSITIVE'), 'O+');
      expect(formatMemberBloodTypeDisplay('AB_NEGATIVE'), 'AB-');
    });

    test('parses raw investiture backend statuses for localized labels in UI',
        () {
      expect(
        memberProfileInvestitureStatus('SUBMITTED_FOR_VALIDATION'),
        InvestitureStatus.submittedForValidation,
      );
      expect(
        memberProfileInvestitureStatus(' in_progress '),
        InvestitureStatus.inProgress,
      );
    });

    test('builds tel URI for emergency contact dialer', () {
      expect(
        cleanMemberPhoneNumber('+52 (229) 928-0198'),
        '+522299280198',
      );
      expect(
        memberPhoneDialUri('+52 (229) 928-0198')?.toString(),
        'tel:+522299280198',
      );
      expect(memberPhoneDialUri('   '), isNull);
    });
  });
}
