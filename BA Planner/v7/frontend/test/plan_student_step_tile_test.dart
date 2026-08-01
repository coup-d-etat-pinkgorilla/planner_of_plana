import 'package:ba_planner_v7/ui/widgets/diagonal_media_list_item.dart';
import 'package:ba_planner_v7/ui/widgets/plan_student_step_tile.dart';
import 'package:ba_planner_v7/ui/widgets/student_portrait_status_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders from the standalone reusable tile API', (tester) async {
    const step = PlanStudentStepPreview(
      studentId: 'shiroko',
      displayName: '시로코',
      step: 2,
      target: 'Lv.70 · ★4',
      targetValues: {
        'level': 70,
        'student_star': 4,
        'weapon_star': 1,
        'bond_rank': 35,
      },
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 720,
            height: 65,
            child: PlanStudentStepTile(order: 3, step: step, highlighted: true),
          ),
        ),
      ),
    );

    final item = tester.widget<DiagonalMediaListItem>(
      find.byType(DiagonalMediaListItem),
    );
    expect(item.highlighted, isTrue);
    expect(item.data.order, 3);
    expect(item.data.title, '시로코 · Lv.70 · ★4');
    expect(item.data.mediaAssetPath, 'assets/student_portraits/shiroko.png');
    expect(item.data.studentLevel.value, 'Lv.70');
    expect(item.data.studentStars, 4);
    expect(item.data.bondRank.value, '35');
    expect(tester.takeException(), isNull);
  });

  testWidgets('projects ownership and taps through the reusable tile API', (
    tester,
  ) async {
    var tapped = false;
    const step = PlanStudentStepPreview(
      studentId: 'aru',
      displayName: '아루',
      step: 1,
      target: '현재 상태',
      targetValues: {'level': 1, 'bond_rank': 1},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 720,
            height: 65,
            child: PlanStudentStepTile(
              order: 1,
              step: step,
              owned: false,
              onTap: () => tapped = true,
            ),
          ),
        ),
      ),
    );

    final overlay = tester.widget<StudentPortraitStatusOverlay>(
      find.byKey(const ValueKey('diagonal-media-portrait-status')),
    );
    expect(overlay.owned, isFalse);
    await tester.tap(find.byType(DiagonalMediaListItem));
    expect(tapped, isTrue);
  });

  testWidgets('current student state uses the catalog-only presentation', (
    tester,
  ) async {
    const step = PlanStudentStepPreview(
      studentId: 'aru',
      displayName: 'Aru',
      step: 1,
      target: 'Current state',
      targetValues: {
        'level': 1,
        'bond_rank': 1,
        'ex_skill': 1,
        'skill1': 1,
        'skill2': 1,
        'skill3': 1,
      },
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 1000,
            height: 97.5,
            child: PlanStudentStepTile(
              order: 9,
              step: step,
              owned: false,
              currentStudentState: true,
              planned: true,
              jpOnly: true,
            ),
          ),
        ),
      ),
    );

    final item = tester.widget<DiagonalMediaListItem>(
      find.byType(DiagonalMediaListItem),
    );
    expect(item.currentStudentState, isTrue);
    expect(item.data.title, 'Aru');
    expect(find.byKey(const ValueKey('diagonal-media-order')), findsNothing);
    expect(
      find.byKey(const ValueKey('diagonal-media-portrait-status')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('diagonal-media-list-unowned-badge')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('diagonal-media-list-plan-badge')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('diagonal-media-list-jp-badge')),
      findsOneWidget,
    );
    final badgeRects = diagonalMediaStatusBadgeRects(const Size(1000, 97.5));
    expect(badgeRects, hasLength(3));
    expect(badgeRects[0].bottom, lessThan(badgeRects[1].top));
    expect(badgeRects[1].bottom, lessThan(badgeRects[2].top));
    expect(badgeRects.map((rect) => rect.width).toSet(), hasLength(1));
    expect(badgeRects.first.width, greaterThanOrEqualTo(42));
    final itemPath = diagonalMediaListItemPath(const Size(1000, 97.5));
    for (final rect in badgeRects) {
      expect(itemPath.contains(rect.centerLeft), isTrue);
      expect(itemPath.contains(rect.centerRight), isTrue);
    }
    expect(
      find.byKey(const ValueKey('diagonal-media-unowned-portrait-darkening')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('diagonal-media-bond-delta')),
      findsNothing,
    );

    final title = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('diagonal-media-title')),
        matching: find.text('Aru'),
      ),
    );
    expect(title.style?.fontSize, 16.5);
    final level = tester.widget<RichText>(
      find.descendant(
        of: find.byKey(const ValueKey('diagonal-media-student-level')),
        matching: find.byType(RichText),
      ),
    );
    expect((level.text as TextSpan).style?.fontSize, 14.25);
    final weaponLevel = tester.widget<RichText>(
      find.descendant(
        of: find.byKey(const ValueKey('diagonal-media-weapon-level')),
        matching: find.byType(RichText),
      ),
    );
    expect((weaponLevel.text as TextSpan).style?.fontSize, 14.25);
    final skills = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('diagonal-media-skills')),
        matching: find.text('1/1/1/1'),
      ),
    );
    expect(skills.style?.fontSize, 21.375);

    Text valueText(Key key) => tester.widget<Text>(
      find.descendant(of: find.byKey(key), matching: find.byType(Text)).first,
    );
    expect(
      valueText(
        const ValueKey('diagonal-media-equipment-value-0'),
      ).style?.fontSize,
      12.75,
    );
    final favorite = tester.widget<RichText>(
      find.descendant(
        of: find.byKey(const ValueKey('diagonal-media-favorite-item')),
        matching: find.byType(RichText),
      ),
    );
    expect((favorite.text as TextSpan).style?.fontSize, 14.25);
    expect(
      valueText(const ValueKey('diagonal-media-stats')).style?.fontSize,
      14.25,
    );

    final equipment = find.byKey(const ValueKey('diagonal-media-equipment-0'));
    final scaleTransform = tester
        .widgetList<Transform>(
          find.descendant(of: equipment, matching: find.byType(Transform)),
        )
        .first;
    expect(scaleTransform.transform.getMaxScaleOnAxis(), closeTo(1.15, 0.001));
  });
}
