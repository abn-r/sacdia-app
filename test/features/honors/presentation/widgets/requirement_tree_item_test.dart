import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/widgets/sac_text_field.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor_requirement.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/requirement_tree_item.dart';

void main() {
  group('RequirementTreeItem', () {
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

    HonorRequirement leaf({bool requiresEvidence = true}) {
      return HonorRequirement(
        id: 10,
        honorId: 1,
        requirementNumber: 1,
        text: 'Completa una actividad práctica.',
        requiresEvidence: requiresEvidence,
      );
    }

    HonorRequirement parentWithChildren() {
      return HonorRequirement(
        id: 1,
        honorId: 1,
        requirementNumber: 1,
        text: 'Completa los siguientes incisos.',
        hasSubItems: true,
        children: [
          HonorRequirement(
            id: 2,
            honorId: 1,
            requirementNumber: 1,
            parentId: 1,
            displayLabel: 'a',
            text: 'Inciso A',
          ),
        ],
      );
    }

    testWidgets('should show per-requirement evidence CTA when required',
        (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        wrap(
          RequirementTreeItem(
            requirement: leaf(),
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

    testWidgets(
        'should hide evidence CTA when requirement does not require it',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          RequirementTreeItem(
            requirement: leaf(requiresEvidence: false),
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

    testWidgets('should show a response field on leaf items', (tester) async {
      await tester.pumpWidget(
        wrap(
          RequirementTreeItem(
            requirement: leaf(requiresEvidence: false),
            completed: false,
            depth: 0,
            categoryColor: Colors.blue,
            onToggle: () {},
          ),
        ),
      );

      expect(find.byType(SacTextField), findsOneWidget);
    });

    testWidgets('should hide the response field on parents with children',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          RequirementTreeItem(
            requirement: parentWithChildren(),
            completed: false,
            depth: 0,
            categoryColor: Colors.blue,
            onToggle: () {},
          ),
        ),
      );

      expect(find.byType(SacTextField), findsNothing);
    });

    testWidgets('should not complete a leaf without a response',
        (tester) async {
      var toggled = false;

      await tester.pumpWidget(
        wrap(
          RequirementTreeItem(
            requirement: leaf(requiresEvidence: false),
            completed: false,
            depth: 0,
            categoryColor: Colors.blue,
            onToggle: () => toggled = true,
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('requirement-check')));
      await tester.pump();

      expect(toggled, isFalse);
      expect(
        find.text('honors.requirements.response_required'),
        findsOneWidget,
      );
    });

    testWidgets('should complete a leaf when a response is present',
        (tester) async {
      var toggled = false;
      final controller = TextEditingController(text: 'Mi respuesta');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        wrap(
          RequirementTreeItem(
            requirement: leaf(requiresEvidence: false),
            completed: false,
            depth: 0,
            categoryColor: Colors.blue,
            responseController: controller,
            onToggle: () => toggled = true,
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('requirement-check')));
      await tester.pump();

      expect(toggled, isTrue);
    });

    testWidgets('should lock the response field when the honor is not editable',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          RequirementTreeItem(
            requirement: leaf(requiresEvidence: false),
            completed: true,
            depth: 0,
            categoryColor: Colors.blue,
            enabled: false,
            onToggle: () {},
          ),
        ),
      );

      final field = tester.widget<SacTextField>(find.byType(SacTextField));
      expect(field.enabled, isFalse);
    });

    testWidgets('should not toggle completion when the honor is not editable',
        (tester) async {
      var toggled = false;
      final controller = TextEditingController(text: 'Mi respuesta');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        wrap(
          RequirementTreeItem(
            requirement: leaf(requiresEvidence: false),
            completed: true,
            depth: 0,
            categoryColor: Colors.blue,
            enabled: false,
            responseController: controller,
            onToggle: () => toggled = true,
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('requirement-check')));
      await tester.pump();

      expect(toggled, isFalse);
    });

    testWidgets('should not add evidence when the honor is not editable',
        (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        wrap(
          RequirementTreeItem(
            requirement: leaf(),
            completed: true,
            depth: 0,
            categoryColor: Colors.blue,
            enabled: false,
            onToggle: () {},
            onAddEvidence: () => tapped = true,
          ),
        ),
      );

      await tester
          .tap(find.text('honors.requirements.requirement_evidence_button'));
      await tester.pump();

      expect(tapped, isFalse);
    });
  });
}
