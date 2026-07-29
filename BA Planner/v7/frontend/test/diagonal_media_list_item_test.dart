import 'package:ba_planner_v7/ui/widgets/bond_rank_portrait.dart';
import 'package:ba_planner_v7/ui/widgets/diagonal_media_list_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('studio feature groups share exact vertical center lines', () {
    final center = DiagonalMediaListItemLayout.centerY;

    expect(
      center(DiagonalMediaListItemLayout.order),
      closeTo(center(DiagonalMediaListItemLayout.portrait), 1e-12),
    );
    for (final rect in [
      DiagonalMediaListItemLayout.stars,
      DiagonalMediaListItemLayout.weaponLevel,
    ]) {
      expect(
        center(rect),
        closeTo(center(DiagonalMediaListItemLayout.title), 1e-12),
      );
    }
    for (final rect in [
      DiagonalMediaListItemLayout.skills,
      ...DiagonalMediaListItemLayout.equipmentImages,
      ...DiagonalMediaListItemLayout.equipmentValues,
      DiagonalMediaListItemLayout.favoriteItem,
      DiagonalMediaListItemLayout.stats,
    ]) {
      expect(
        center(rect),
        closeTo(center(DiagonalMediaListItemLayout.studentLevel), 1e-12),
      );
    }
    expect(DiagonalMediaListItemLayout.stars.height, closeTo(0.154, 1e-12));
    expect(
      DiagonalMediaListItemLayout.bondWithDelta.center.dx,
      closeTo(0.95, 1e-12),
    );
    expect(
      center(DiagonalMediaListItemLayout.bondAnchor),
      closeTo(center(DiagonalMediaListItemLayout.portrait), 1e-12),
    );
    expect(
      DiagonalMediaListItemLayout.equipmentImages.first.height,
      greaterThan(0.35),
    );
    expect(
      DiagonalMediaListItemLayout.skills.left -
          DiagonalMediaListItemLayout.studentLevel.right,
      greaterThanOrEqualTo(0.012),
    );
    for (var index = 0; index < 3; index++) {
      expect(
        DiagonalMediaListItemLayout.equipmentValues[index].left -
            DiagonalMediaListItemLayout.equipmentImages[index].right,
        closeTo(0.008, 1e-12),
      );
    }
    expect(
      DiagonalMediaListItemLayout.favoriteItem.width,
      greaterThanOrEqualTo(0.05),
    );
  });

  test('bond background tiers include the level 100 purple boundary', () {
    expect(
      bondRankPortraitBackgroundAsset(19),
      defaultStudentPortraitBackgroundAsset,
    );
    expect(
      bondRankPortraitBackgroundAsset(20),
      blueStudentPortraitBackgroundAsset,
    );
    expect(
      bondRankPortraitBackgroundAsset(49),
      blueStudentPortraitBackgroundAsset,
    );
    expect(
      bondRankPortraitBackgroundAsset(50),
      yellowStudentPortraitBackgroundAsset,
    );
    expect(
      bondRankPortraitBackgroundAsset(99),
      yellowStudentPortraitBackgroundAsset,
    );
    expect(
      bondRankPortraitBackgroundAsset(100),
      purpleStudentPortraitBackgroundAsset,
    );
  });

  test('relationship heart follows the wide badge proportions', () {
    final bounds = relationshipRankHeartPath(const Size(100, 80)).getBounds();
    expect(bounds.width / bounds.height, greaterThan(1.2));
    expect(bounds.bottom, closeTo(76.8, 0.01));
    expect(bounds.center.dx, closeTo(52, 3));
  });

  test('maximum skill levels render as M', () {
    expect(formatDiagonalMediaSkillLevels('5/10/10/10'), 'M/M/M/M');
    expect(formatDiagonalMediaSkillLevels('5/6/6/6'), 'M/6/6/6');
    expect(formatDiagonalMediaSkillLevels('4/9/8/7'), '4/9/8/7');
  });

  testWidgets('renders reusable media data and colored value deltas', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 560,
            height: 96,
            child: DiagonalMediaListItem(data: _data),
          ),
        ),
      ),
    );

    final richText = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((widget) => widget.text)
        .whereType<TextSpan>()
        .toList();
    expect(richText.any((span) => span.toPlainText() == 'Lv.50(▲2)'), isTrue);
    expect(
      richText.any((span) => span.toPlainText() == '- / - / - / ▲2'),
      isTrue,
    );
    expect(richText.any((span) => span.toPlainText() == '▼1 / ▲5'), isTrue);
    expect(richText.any((span) => span.toPlainText() == '- / -'), isFalse);

    Color? deltaColor(String text) {
      for (final root in richText) {
        for (final child in root.children ?? const <InlineSpan>[]) {
          if (child is TextSpan && child.text == text) {
            return child.style?.color;
          }
        }
      }
      return null;
    }

    expect(deltaColor('(▲2)'), diagonalMediaIncreaseColor);
    expect(deltaColor('▼1'), diagonalMediaDecreaseColor);
    expect(find.text('T8 Lv.30'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
    final skills = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('diagonal-media-skills')),
        matching: find.text('3/4/4/4'),
      ),
    );
    expect(skills.style?.fontSize, 14.25);
    expect(
      find.byKey(const ValueKey('diagonal-media-bond-delta')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<AspectRatio>(
            find.byKey(const ValueKey('diagonal-media-heart')),
          )
          .aspectRatio,
      1.28,
    );
    expect(
      tester.getCenter(find.byKey(const ValueKey('diagonal-media-heart'))).dy,
      closeTo(
        tester
            .getCenter(find.byKey(const ValueKey('diagonal-media-portrait')))
            .dy,
        0.1,
      ),
    );
    expect(
      tester
          .getCenter(find.byKey(const ValueKey('diagonal-media-bond-delta')))
          .dx,
      closeTo(
        tester.getCenter(find.byKey(const ValueKey('diagonal-media-heart'))).dx,
        0.1,
      ),
    );
    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('diagonal-media-bond-delta')))
          .dy,
      greaterThan(
        tester
            .getBottomLeft(find.byKey(const ValueKey('diagonal-media-heart')))
            .dy,
      ),
    );
    expect(tester.widget<Text>(find.text('100')).style?.fontSize, 15.75);
    final portrait = tester.widget<BondRankPortrait>(
      find.byKey(const ValueKey('diagonal-media-portrait')),
    );
    expect(portrait.bondRank, 100);
    expect(
      tester
          .widgetList<FractionallySizedBox>(
            find.descendant(
              of: find.byKey(const ValueKey('diagonal-media-portrait')),
              matching: find.byType(FractionallySizedBox),
            ),
          )
          .single
          .widthFactor,
      0.98,
    );
    for (var index = 0; index < 3; index++) {
      final equipment = find.byKey(ValueKey('diagonal-media-equipment-$index'));
      expect(
        find.descendant(of: equipment, matching: find.byType(Image)),
        findsNWidgets(2),
      );
      final foreground = tester
          .widgetList<FractionallySizedBox>(
            find.descendant(
              of: equipment,
              matching: find.byType(FractionallySizedBox),
            ),
          )
          .single;
      expect(foreground.widthFactor, 0.98);
      expect(foreground.heightFactor, 0.98);
    }
    expect(
      tester
          .widgetList<Semantics>(find.byType(Semantics))
          .any((widget) => widget.properties.label == '성급 5(▲1), 무기 성급 4'),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}

const _data = DiagonalMediaListItemData(
  order: 1,
  mediaAssetPath: 'assets/student_portraits/shiroko.png',
  title: '시로코 · 1단계',
  studentStars: 5,
  weaponStars: 4,
  studentStarDelta: 1,
  studentLevel: DiagonalMediaValue('Lv.50', delta: 2),
  weaponLevel: DiagonalMediaValue('Lv.30', delta: 5),
  skills: DiagonalMediaValue('3/4/4/4', componentDeltas: [null, null, null, 2]),
  equipment: [
    DiagonalMediaEquipment(
      assetPath: 'assets/equipment_icons/hat_t10.png',
      tier: DiagonalMediaValue('T8', delta: -1),
      level: DiagonalMediaValue('Lv.30', delta: 5),
    ),
    DiagonalMediaEquipment(
      assetPath: 'assets/equipment_icons/hairpin_t10.png',
      tier: DiagonalMediaValue('T8'),
      level: DiagonalMediaValue('Lv.25'),
    ),
    DiagonalMediaEquipment(
      assetPath: 'assets/equipment_icons/watch_t10.png',
      tier: DiagonalMediaValue('T8', delta: 1),
      level: DiagonalMediaValue('Lv.20', delta: 5),
    ),
  ],
  favoriteItem: DiagonalMediaValue('T2', delta: 1),
  bondRank: DiagonalMediaValue('100', delta: 2),
  stats: DiagonalMediaValue('25/25/25', componentDeltas: [null, 1, 2]),
);
