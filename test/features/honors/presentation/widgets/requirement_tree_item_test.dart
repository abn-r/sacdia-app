import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor_requirement.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/requirement_tree_item.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }

  HonorRequirement requirement({bool requiresEvidence = true}) {
    return HonorRequirement(
      id: 10,
      honorId: 1,
      requirementNumber: 1,
      text: 'Completa una actividad práctica.',
      requiresEvidence: requiresEvidence,
    );
  }

  testWidgets('shows per-requirement evidence CTA when required',
      (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      wrap(
        RequirementTreeItem(
          requirement: requirement(),
          completed: false,
          depth: 0,
          categoryColor: Colors.blue,
          onToggle: () {},
          onAddEvidence: () => tapped = true,
        ),
      ),
    );

    expect(
      find.text('honors.requirements.requirement_evidence_button'),
      findsOneWidget,
    );

    await tester
        .tap(find.text('honors.requirements.requirement_evidence_button'));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('does not show evidence CTA when requirement does not require it',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        RequirementTreeItem(
          requirement: requirement(requiresEvidence: false),
          completed: false,
          depth: 0,
          categoryColor: Colors.blue,
          onToggle: () {},
        ),
      ),
    );

    expect(
      find.text('honors.requirements.requirement_evidence_button'),
      findsNothing,
    );
  });
}
