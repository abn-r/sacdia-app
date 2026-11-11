import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/enrollment/presentation/views/enrollment_form_view.dart';
import 'package:sacdia_app/features/enrollment/presentation/widgets/enrollment_board_summary.dart';
import 'package:sacdia_app/features/members/domain/entities/club_member.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';

import '../../../../support/riverpod_test_support.dart';

class _FakeMembersNotifier extends MembersNotifier {
  _FakeMembersNotifier(this._members);

  final List<ClubMember> _members;

  @override
  Future<MembersData> build() async => MembersData(members: _members);
}

void main() {
  testWidgets('shows the board read-only from Members and no pickers',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      testProviderScope(
        overrides: [
          membersNotifierProvider.overrideWith(
            () => _FakeMembersNotifier(const [
              ClubMember(userId: '1', name: 'Ana', clubRole: 'director'),
              ClubMember(userId: '2', name: 'Eva', clubRole: 'secretary'),
            ]),
          ),
        ],
        child: const MaterialApp(
          home: EnrollmentFormView(clubId: '1', sectionId: 2),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('enrollment.form.title_create'), findsOneWidget);
    expect(find.text('enrollment.form.section_leadership'), findsOneWidget);
    expect(find.byType(EnrollmentBoardSummary), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Eva'), findsOneWidget);
    expect(find.text('enrollment.form.board_helper'), findsOneWidget);
    expect(find.text('enrollment.form.board_go_to_members'), findsOneWidget);
    // Only the fee toggle remains: no secretary-treasurer switch or pickers.
    expect(find.byType(Switch), findsOneWidget);
  });
}
