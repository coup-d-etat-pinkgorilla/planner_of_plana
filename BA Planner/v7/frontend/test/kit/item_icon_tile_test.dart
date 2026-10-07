// FE2-d 이미지 원자 테스트: 아이템 아이콘(크기·아이콘 상자·그림 없음 = 빈 상자), 아이템 타일(수량·막대·선택),
// 초상 줄 "…+n" 계산, 모은 asset 경로가 기존 문자열과 같은지.
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/ui/kit/game_assets.dart';
import 'package:ba_planner_v7/ui/kit/item_icon_tile.dart';
import 'package:ba_planner_v7/ui/kit/portrait_strip.dart';
import 'package:ba_planner_v7/ui/kit/skew_bar.dart';
import 'package:ba_planner_v7/ui/models/planning_resource_assets.dart';
import 'package:ba_planner_v7/ui/widgets/asset_image_grid.dart';
import 'package:ba_planner_v7/ui/widgets/plan_section_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 모든 그림 읽기가 실패하는 asset 묶음(배포본에 그림을 아직 추출하지 않은 상태).
class _MissingAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      throw FlutterError('missing asset $key');
}

Future<void> _pumpWithBundle(WidgetTester tester, Widget child) =>
    tester.pumpWidget(
      MaterialApp(
        theme: BAPlannerTheme.dark(),
        home: Scaffold(
          body: Center(
            child: DefaultAssetBundle(
              bundle: _MissingAssetBundle(),
              child: child,
            ),
          ),
        ),
      ),
    );

void main() {
  test('asset paths keep the strings the widgets used before', () {
    expect(GameAssets.itemBackgroundBasic, 'assets/item_backgrounds/square.png');
    expect(
      GameAssets.itemBackgroundPurple,
      'assets/item_backgrounds/square_purple.png',
    );
    expect(
      GameAssets.itemBackgroundYellow,
      'assets/item_backgrounds/square_yellow.png',
    );
    expect(
      GameAssets.equipmentIcon('Watch', 10),
      'assets/item_icons/equipment/Equipment_Icon_Watch_Tier10.png',
    );
    expect(
      GameAssets.equipmentIcon('Hat', 9, piece: true),
      'assets/item_icons/equipment/Equipment_Icon_Hat_Tier9_Piece.png',
    );
    expect(
      GameAssets.schoolLogo('MILLENNIUM'),
      'assets/item_icons/school_logo/School_Icon_MILLENNIUM.png',
    );
    expect(GameAssets.studentPortrait('hoshino'), 'assets/student_portraits/hoshino.png');
    expect(planDefaultItemBackgroundAsset, 'assets/item_backgrounds/square.png');
    expect(
      planCreditIconAsset,
      'assets/item_icons/currency/Currency_Icon_Gold.png',
    );
    expect(
      planPrimaryBottleneckIconAsset,
      'assets/item_icons/ooparts/Item_Icon_Material_Nebra_2.png',
    );
    expect(
      planPhaseShortageBackgroundAsset,
      'assets/item_backgrounds/square_purple.png',
    );
    expect(
      planBasicTacticalBdIconAsset,
      'assets/item_icons/tactical_bd/Item_Icon_Material_ExSkill_Abydos_0.png',
    );
    expect(
      planningResourceIconAsset(category: 'credits'),
      'assets/item_icons/currency/Currency_Icon_Gold.png',
    );
    expect(
      planningResourceIconAsset(
        category: 'tech_notes',
        itemId: 'Item_Icon_SkillBook_Abydos_3',
      ),
      'assets/item_icons/skill_book/Item_Icon_SkillBook_Abydos_3.png',
    );
    expect(
      planningResourceIconAsset(category: 'student_eleph', itemId: 'hoshino'),
      'assets/student_elephs/hoshino.png',
    );
    expect(planningResourceIconAsset(category: 'unknown', itemId: 'x'), isNull);
  });

  testWidgets('icon tile sizes and the 92% icon box', (tester) async {
    for (final size in const [
      ItemIconSizes.s42,
      ItemIconSizes.s47,
      ItemIconSizes.s52,
      ItemIconSizes.s74,
    ]) {
      await _pumpWithBundle(
        tester,
        ItemIconTile(iconAsset: 'assets/item_icons/x.png', size: size),
      );
      expect(tester.getSize(find.byType(ItemIconTile)), size);
      final icon = tester.getRect(
        find.descendant(
          of: find.byType(ItemIconTile),
          matching: find.byType(Positioned),
        ),
      );
      final tile = tester.getRect(find.byType(ItemIconTile));
      expect(icon.left - tile.left, closeTo(size.width * 0.04, 0.01));
      expect(icon.top - tile.top, closeTo(size.width * 0.04, 0.01));
      expect(icon.width, closeTo(size.width * 0.92, 0.01));
      expect(icon.height, closeTo(size.height * 0.92, 0.01));
    }
  });

  testWidgets('missing images draw an empty box without throwing', (
    tester,
  ) async {
    await _pumpWithBundle(
      tester,
      const ItemIconTile(
        iconAsset: 'assets/item_icons/missing.png',
        background: ItemBackground.yellow,
        size: ItemIconSizes.s52,
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(ItemIconPlaceholder), findsOneWidget);
    final placeholder = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('item-icon-placeholder')),
    );
    expect(
      (placeholder.decoration as BoxDecoration).color,
      itemIconPlaceholderColor,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('item tile: quantity, coverage bar and selection ring', (
    tester,
  ) async {
    await _pumpWithBundle(
      tester,
      const ItemTile(
        quantity: '12',
        tone: CoverageTone.shortage,
        fraction: 0.28,
        selected: true,
      ),
    );
    expect(tester.getSize(find.byType(ItemTile)), const Size(74, 74));
    final quantity = tester.getRect(find.text('12'));
    final tile = tester.getRect(find.byType(ItemTile));
    expect(tile.right - quantity.right, closeTo(5, 0.01));
    expect(quantity.top - tile.top, closeTo(41, 0.01));

    final bar = tester.widget<SkewBar>(find.byType(SkewBar));
    expect(bar.color, CoverageTone.shortage.color);
    expect(bar.fraction, 0.28);
    expect(bar.style, SkewBarStyle.itemTile);
    final barRect = tester.getRect(find.byType(SkewBar));
    expect(barRect.left - tile.left, closeTo(1.5, 0.01));
    expect(barRect.top - tile.top, closeTo(64, 0.01));
    expect(barRect.width, closeTo(64.9, 0.01));
    expect(barRect.height, closeTo(4, 0.01));

    final ring = tester.widget<DecoratedBox>(
      find
          .ancestor(
            of: find.byType(ItemIconTile),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final shadows = (ring.decoration as BoxDecoration).boxShadow!;
    expect(shadows.first.color, AppColors.accent);
    expect(shadows.first.spreadRadius, 2);

    // 계획 무관: 막대 없음. 선택 아님: 링 없음.
    await _pumpWithBundle(tester, const ItemTile(quantity: '0'));
    expect(find.byType(SkewBar), findsNothing);
    final plain = tester.widget<DecoratedBox>(
      find
          .ancestor(
            of: find.byType(ItemIconTile),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect((plain.decoration as BoxDecoration).boxShadow, isNull);
  });

  test('portrait strip split keeps at most n and folds the rest', () {
    expect(portraitStripSplit(3, 5), (visible: 3, hidden: 0));
    expect(portraitStripSplit(5, 5), (visible: 5, hidden: 0));
    expect(portraitStripSplit(7, 5), (visible: 5, hidden: 2));
    expect(portraitStripSplit(0, 5), (visible: 0, hidden: 0));
    expect(portraitStripSplit(4, 0), (visible: 0, hidden: 4));
    expect(PortraitStrip.overflowLabel(2), '…+2');
  });

  testWidgets('portrait strip draws n portraits and the "…+n" chip', (
    tester,
  ) async {
    await _pumpWithBundle(
      tester,
      const PortraitStrip(
        studentIds: ['yuuka', 'noa', 'rio', 'toki', 'himari', 'koyuki', 'kei'],
        slotWidth: 246,
      ),
    );
    final grid = tester.widget<AssetImageGrid>(find.byType(AssetImageGrid));
    expect(grid.columns, 5);
    expect(grid.columnGap, 4);
    // 칸마다 배경 + 초상 98%.
    expect(grid.items, hasLength(10));
    expect(grid.items[0].asset, GameAssets.portraitBackground);
    expect(grid.items[1].asset, GameAssets.studentPortrait('yuuka'));
    expect(grid.items[1].scale, 0.98);
    expect(
      tester.getSize(find.byKey(const ValueKey('portrait-strip-grid'))),
      const Size(34 * 5 + 4 * 4, 28),
    );
    expect(find.text('…+2'), findsOneWidget);
    expect(tester.getSize(find.byType(PortraitOverflowChip)).height, 28);
    expect(tester.getSize(find.byType(PortraitStrip)).width, 246);
    expect(tester.takeException(), isNull);

    await _pumpWithBundle(
      tester,
      const PortraitStrip(studentIds: ['hoshino', 'shiroko']),
    );
    expect(find.byType(PortraitOverflowChip), findsNothing);
    expect(tester.widget<AssetImageGrid>(find.byType(AssetImageGrid)).columns, 2);
  });
}
