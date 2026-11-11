import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/features/members/domain/entities/club_member.dart';
import 'package:sacdia_app/features/enrollment/presentation/widgets/enrollment_board_summary.dart';

ClubMember _member(String id, String name, String? role) =>
    ClubMember(userId: id, name: name, clubRole: role);

Future<void> _pump(
  WidgetTester tester,
  List<ClubMember> members, {
  bool isLoading = false,
  VoidCallback? onOpenMembers,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: EnrollmentBoardSummary(
            members: members,
            isLoading: isLoading,
            onOpenMembers: onOpenMembers,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the board taken from the members roles', (tester) async {
    await _pump(tester, [
      _member('1', 'Ana', 'director'),
      _member('2', 'Beto', 'deputy-director'),
      _member('3', 'Carla', 'deputy-director'),
      _member('4', 'Dora', 'deputy-director'),
      _member('5', 'Eva', 'secretary'),
      _member('6', 'Fito', 'treasurer'),
      _member('7', 'Gus', 'counselor'),
    ]);

    expect(find.text('Ana'), findsOneWidget);
    // Up to two deputies, in one cell.
    expect(find.text('Beto\nCarla'), findsOneWidget);
    expect(find.text('Dora'), findsNothing);
    expect(find.text('Eva'), findsOneWidget);
    expect(find.text('Fito'), findsOneWidget);
    expect(find.text('Gus'), findsNothing);
    expect(find.text('enrollment.form.board_unassigned'), findsNothing);
  });

  testWidgets('shows the combined role instead of secretary and treasurer',
      (tester) async {
    await _pump(tester, [
      _member('1', 'Ana', 'director'),
      _member('2', 'Hugo', 'secretary-treasurer'),
    ]);

    expect(
        find.text('enrollment.form.label_secretary_treasurer'), findsOneWidget);
    expect(find.text('Hugo'), findsOneWidget);
    expect(find.text('enrollment.form.label_secretary'), findsNothing);
    expect(find.text('enrollment.form.label_treasurer'), findsNothing);
  });

  testWidgets('marks empty positions as unassigned', (tester) async {
    await _pump(tester, const []);

    // director, deputies, secretary, treasurer
    expect(find.text('enrollment.form.board_unassigned'), findsNWidgets(4));
  });

  testWidgets('has no pickers, only a link to Members', (tester) async {
    var opened = 0;
    await _pump(tester, const [], onOpenMembers: () => opened++);

    expect(find.byType(InkWell), findsNothing);
    expect(find.text('enrollment.form.board_helper'), findsOneWidget);
    expect(find.byType(SacButton), findsOneWidget);

    await tester.tap(find.text('enrollment.form.board_go_to_members'));
    expect(opened, 1);
  });

  testWidgets('shows a progress indicator while members load', (tester) async {
    await _pump(tester, const [], isLoading: true);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('enrollment.form.board_unassigned'), findsNothing);
  });
}
