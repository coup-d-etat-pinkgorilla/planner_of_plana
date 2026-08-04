import 'dart:math' as math;

import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/ui/widgets/plan_element_builder.dart';
import 'package:ba_planner_v7/ui/widgets/section_template_surface.dart';
import 'package:ba_planner_v7/ui/widgets/student_range_condition_section.dart';
import 'package:ba_planner_v7/ui/widgets/student_section_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

StudentCatalogEntry _student(String id) => StudentCatalogEntry(
  studentId: id,
  displayName: id,
  templateName: '$id.png',
  group: id,
  variant: null,
  school: 'Gehenna',
  rarity: '3',
  attackType: 'Explosive',
  defenseType: 'Light',
  combatClass: 'striker',
  role: 'dealer',
  position: 'back',
  searchTags: const [],
  krSearchTags: const [],
);

void main() {
  test(
    'student filter and condition sections preserve a 24 px visible gap',
    () {
      for (final size in const [Size(1100, 720), Size(1440, 900)]) {
        final filter = studentFilterSectionPath(size).getBounds();
        final condition = studentFilterCompanionSectionRect(size);
        final depth = sectionTemplateCutDepth(filter.height);
        expect(condition.width, greaterThan(0));
        expect(condition.top, closeTo(filter.top, 0.01));
        expect(condition.bottom, closeTo(filter.bottom, 0.01));
        expect(
          condition.left + depth / 2 - (filter.right - depth / 2),
          closeTo(studentFilterCompanionSectionGap, 0.01),
        );
      }
    },
  );

  test('condition cards advance along the parent 80 degree rails', () {
    for (final size in const [Size(520, 900), Size(640, 1080)]) {
      final contentHeight =
          size.height -
          studentRangeConditionSectionInset * 2 -
          studentRangeConditionArrowHeight -
          studentRangeConditionCardGap * 2;
      final slotHeight = contentHeight / 2;
      final firstSlot = Rect.fromLTWH(
        0,
        studentRangeConditionSectionInset,
        size.width,
        slotHeight,
      );
      final arrowTop = firstSlot.bottom + studentRangeConditionCardGap;
      final secondSlot = Rect.fromLTWH(
        0,
        arrowTop +
            studentRangeConditionArrowHeight +
            studentRangeConditionCardGap,
        size.width,
        slotHeight,
      );
      final designSize = studentRangeConditionCardDesignSize();
      final first = studentRangeConditionFittedCardRect(
        sectionSize: size,
        verticalSlot: firstSlot,
        designSize: designSize,
      );
      final second = studentRangeConditionFittedCardRect(
        sectionSize: size,
        verticalSlot: secondSlot,
        designSize: designSize,
      );
      final tangent = math.tan(80 * math.pi / 180);
      final sine = math.sin(80 * math.pi / 180);

      expect(second.width, closeTo(first.width, 0.001));
      expect(second.height, closeTo(first.height, 0.001));
      expect(
        second.center.dx - first.center.dx,
        closeTo(-(second.center.dy - first.center.dy) / tangent, 0.001),
      );

      for (final card in [first, second]) {
        final topInterval = studentRangeConditionHorizontalInterval(
          size,
          card.top,
        );
        final bottomInterval = studentRangeConditionHorizontalInterval(
          size,
          card.bottom,
        );
        final childDepth = card.height / tangent;
        final normalGaps = [
          (card.left + childDepth - topInterval.$1) * sine,
          (topInterval.$2 - card.right) * sine,
          (card.left - bottomInterval.$1) * sine,
          (bottomInterval.$2 - (card.right - childDepth)) * sine,
        ];
        for (final gap in normalGaps) {
          expect(
            gap,
            greaterThanOrEqualTo(studentRangeConditionSectionInset - 0.001),
          );
        }
      }

      final arrowY = arrowTop + studentRangeConditionArrowHeight / 2;
      final arrowInterval = studentRangeConditionHorizontalInterval(
        size,
        arrowY,
      );
      expect(
        (arrowInterval.$1 + arrowInterval.$2) / 2,
        closeTo(size.width / 2 - (arrowY - size.height / 2) / tangent, 0.001),
      );
    }
  });

  test('condition shell wraps the cards while preserving diagonal margins', () {
    for (final size in const [Size(520, 900), Size(640, 1080)]) {
      final geometry = studentRangeConditionGeometry(size);
      final tangent = math.tan(80 * math.pi / 180);
      final sine = math.sin(80 * math.pi / 180);

      expect(geometry.sectionBounds.top, closeTo(0, 0.001));
      expect(geometry.sectionBounds.width, lessThan(size.width));
      expect(geometry.sectionBounds.height, lessThan(size.height));
      expect(
        geometry.sectionBounds.left + geometry.sectionBounds.height / tangent,
        closeTo(size.height / tangent, 0.001),
      );
      expect(
        geometry.lowerCardRect.top,
        closeTo(studentRangeConditionSectionInset, 0.001),
      );
      expect(
        geometry.sectionBounds.height - geometry.upperCardRect.bottom,
        closeTo(studentRangeConditionSectionInset, 0.001),
      );

      final outerLeftRail = geometry.sectionBounds.height / tangent;
      final outerRightRail = geometry.sectionBounds.width;
      for (final card in [geometry.lowerCardRect, geometry.upperCardRect]) {
        final childLeftRail = card.left + card.bottom / tangent;
        final childRightRail = card.right + card.top / tangent;
        expect(
          (childLeftRail - outerLeftRail) * sine,
          closeTo(studentRangeConditionSectionInset, 0.001),
        );
        expect(
          (outerRightRail - childRightRail) * sine,
          closeTo(studentRangeConditionSectionInset, 0.001),
        );
      }
      expect(
        geometry.arrowRect.top - geometry.lowerCardRect.bottom,
        greaterThanOrEqualTo(studentRangeConditionCardGap - 0.001),
      );
      expect(
        geometry.upperCardRect.top - geometry.arrowRect.bottom,
        greaterThanOrEqualTo(studentRangeConditionCardGap - 0.001),
      );
    }
  });

  test('student range conditions apply inclusive lower and upper bounds', () {
    final student = _student('aru');
    final currentValues = <String, dynamic>{
      for (final entry in planElementTargetMinimums.entries)
        entry.key: entry.value,
      'level': 50,
    };
    final initial = StudentRangeConditions.initial();

    expect(
      initial.matchesStudent(
        student: student,
        currentValues: currentValues,
        owned: true,
      ),
      isTrue,
    );
    expect(
      initial
          .copyWith(
            lowerEnabled: true,
            lowerTargets: {...initial.lowerTargets, 'level': 50},
          )
          .matchesStudent(
            student: student,
            currentValues: currentValues,
            owned: true,
          ),
      isTrue,
    );
    expect(
      initial
          .copyWith(
            lowerEnabled: true,
            lowerTargets: {...initial.lowerTargets, 'level': 51},
          )
          .matchesStudent(
            student: student,
            currentValues: currentValues,
            owned: true,
          ),
      isFalse,
    );
    expect(
      initial
          .copyWith(
            upperEnabled: true,
            upperTargets: {...initial.upperTargets, 'level': 50},
          )
          .matchesStudent(
            student: student,
            currentValues: currentValues,
            owned: true,
          ),
      isTrue,
    );
    expect(
      initial
          .copyWith(
            upperEnabled: true,
            upperTargets: {...initial.upperTargets, 'level': 49},
          )
          .matchesStudent(
            student: student,
            currentValues: currentValues,
            owned: true,
          ),
      isFalse,
    );
  });

  testWidgets(
    'condition section shows two editable cards without a scroll viewport',
    (tester) async {
      var conditions = StudentRangeConditions.initial();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 520,
                height: 900,
                child: StatefulBuilder(
                  builder: (context, setState) => StudentRangeConditionSection(
                    keyPrefix: 'test-range',
                    conditions: conditions,
                    onChanged: (next) => setState(() => conditions = next),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PlanPresetElementCard), findsNWidgets(2));
      expect(find.byType(Scrollable), findsNothing);
      expect(
        find.byKey(const ValueKey('test-range-range-arrow')),
        findsOneWidget,
      );
      final lower = tester.getRect(
        find.byKey(const ValueKey('test-range-lower-card')),
      );
      final upper = tester.getRect(
        find.byKey(const ValueKey('test-range-upper-card')),
      );
      final arrow = tester.getRect(
        find.byKey(const ValueKey('test-range-range-arrow')),
      );
      final section = tester.getRect(
        find.byKey(const ValueKey('test-range-foundation')),
      );
      final available = tester.getRect(
        find.byType(StudentRangeConditionSection),
      );
      expect(section.top, closeTo(available.top, 0.01));
      expect(section.width, lessThan(available.width));
      expect(section.height, lessThanOrEqualTo(available.height));
      expect(section.contains(lower.topLeft), isTrue);
      expect(section.contains(lower.bottomRight), isTrue);
      expect(section.contains(upper.topLeft), isTrue);
      expect(section.contains(upper.bottomRight), isTrue);
      expect(lower.bottom, lessThanOrEqualTo(arrow.top));
      expect(arrow.bottom, lessThanOrEqualTo(upper.top));
      expect(
        upper.center.dx - lower.center.dx,
        closeTo(
          -(upper.center.dy - lower.center.dy) / math.tan(80 * math.pi / 180),
          0.5,
        ),
      );

      for (final kind in const ['lower', 'upper']) {
        final card = tester.getRect(
          find.byKey(ValueKey('test-range-$kind-card')),
        );
        final envelope = planPresetElementEnvelopePath(card.size);
        for (final controlKey in [
          'test-range-$kind-enabled-control',
          'test-range-$kind-reset',
        ]) {
          final control = tester
              .getRect(find.byKey(ValueKey(controlKey)))
              .shift(-card.topLeft)
              .deflate(0.5);
          expect(envelope.contains(control.topLeft), isTrue);
          expect(envelope.contains(control.topRight), isTrue);
          expect(envelope.contains(control.bottomLeft), isTrue);
          expect(envelope.contains(control.bottomRight), isTrue);
        }
        final firstContent = tester.getRect(
          find.descendant(
            of: find.byKey(ValueKey('test-range-$kind-card')),
            matching: find.byKey(
              ValueKey(
                'plan-preset-element-${kind == 'lower' ? 1 : 2}-element-1',
              ),
            ),
          ),
        );
        final headerBottom = math.max(
          tester
              .getRect(find.byKey(ValueKey('test-range-$kind-enabled-control')))
              .bottom,
          tester.getRect(find.byKey(ValueKey('test-range-$kind-reset'))).bottom,
        );
        expect(headerBottom, lessThan(firstContent.top));
      }

      await tester.tap(
        find.byKey(const ValueKey('test-range-lower-enabled-control')),
      );
      await tester.pump();
      expect(conditions.lowerEnabled, isTrue);
      expect(conditions.upperEnabled, isFalse);

      final levelIncrease = find.descendant(
        of: find.byKey(const ValueKey('test-range-lower-card')),
        matching: find.byKey(const ValueKey('plan-stage-1-level-increase')),
      );
      expect(levelIncrease, findsOneWidget);
      await tester.tap(levelIncrease);
      await tester.pump();
      expect(
        conditions.lowerTargets['level'],
        greaterThan(planElementTargetMinimums['level']!),
      );

      await tester.tap(find.byKey(const ValueKey('test-range-lower-reset')));
      await tester.pump();
      expect(conditions.lowerEnabled, isTrue);
      expect(conditions.lowerTargets, planElementTargetMinimums);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('student filter close and reopen resets range conditions', (
    tester,
  ) async {
    final search = TextEditingController();
    addTearDown(search.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1100, 720));
    var conditions = StudentRangeConditions.initial();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => StudentSectionLayout(
              students: [_student('aru')],
              ownedIds: const {'aru'},
              selectedId: null,
              selectedValues: null,
              searchController: search,
              onSearchChanged: (_) {},
              onStudentSelected: (_) {},
              onAddToPlan: null,
              onOpenScan: null,
              onOpenFilter: () {},
              onFilterVisibilityChanged: (visible) {
                if (!visible) {
                  setState(() => conditions = StudentRangeConditions.initial());
                }
              },
              filterCompanion: StudentRangeConditionSection(
                keyPrefix: 'student-test-range',
                conditions: conditions,
                onChanged: (next) => setState(() => conditions = next),
              ),
              rangeConditionMatches: (student, values) =>
                  conditions.matchesStudent(
                    student: student,
                    currentValues: values ?? const {},
                    owned: true,
                  ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('student-open-filter')));
    await tester.pumpAndSettle();
    expect(find.byType(StudentRangeConditionSection), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('student-test-range-upper-enabled-control')),
    );
    await tester.pump();
    expect(conditions.upperEnabled, isTrue);

    await tester.tap(find.byKey(const ValueKey('student-open-filter')));
    await tester.pumpAndSettle();
    expect(find.byType(StudentRangeConditionSection), findsNothing);
    expect(conditions.upperEnabled, isFalse);

    await tester.tap(find.byKey(const ValueKey('student-open-filter')));
    await tester.pumpAndSettle();
    final checkbox = tester.widget<Checkbox>(
      find.descendant(
        of: find.byKey(
          const ValueKey('student-test-range-upper-enabled-control'),
        ),
        matching: find.byType(Checkbox),
      ),
    );
    expect(checkbox.value, isFalse);
    expect(tester.takeException(), isNull);
  });
}
