// FE6-b golden: 인벤토리 전체 아이템(시안 Inventory-All: 전체 보기, 기술 노트(최상급) 선택, 플라이아웃 1개 열림).
//
// 앱 셸 → 인벤토리 탭 → 사이드바 "전체" → 기술 노트(최상급) 타일 선택 → 기술 노트 그룹의 "부족 1" 칩을 눌러 연다.
// 숫자는 FE6-a 검수 fixture(`test/inventory_fe6a_fixture.dart`)다. 게임 그림이 없는 아이콘은 키트 규칙대로 빈 상자다.
// 공용 도구는 golden_harness.dart의 공개 함수만 쓴다(harness는 Lane A 소유라 고치지 않는다).
//
// PNG 생성(사용자 PC, Windows):  .\frontend\tool\fe_gate.ps1 -UpdateGoldens
// 비교:                          .\frontend\tool\fe_gate.ps1
@Tags(['golden'])
library;

import 'package:ba_planner_v7/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../inventory_fe6a_fixture.dart';
import 'golden_harness.dart';

Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  expect(finder, findsOneWidget, reason: 'golden navigation key $key');
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadGoldenFonts);

  testWidgets('inventory-all', (tester) async {
    setGoldenViewport(tester);
    final service = InventoryFixtureService();
    addTearDown(service.dispose);

    await tester.pumpWidget(goldenBoundary(BAPlannerApp(service: service)));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'top-tab-inventory');
    await pumpUntilFound(tester, find.byKey(const ValueKey('inventory-view-all')));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'inventory-view-all');
    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('inventory-tile-Item_Icon_SkillBook_Gehenna_3')),
    );
    await _tapKey(tester, 'inventory-tile-Item_Icon_SkillBook_Gehenna_3');
    await _tapKey(tester, 'inventory-group-flyout-tech_notes');
    expect(find.text('부족한 기술 노트 1종'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('inventory-detail-name')))
          .data,
      '기술 노트 (최상급)',
    );
    await expectGoldenScene(tester, 'inventory-all');
  }, variant: goldenPlatform);
}
