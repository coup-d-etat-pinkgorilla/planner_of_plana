// FE6-a golden: 인벤토리 "부족한 것" 보기, 리오(무장) 엘레프 선택(시안 Inventory).
//
// 앱 셸로 열고 인벤토리 탭을 누른다(머리글 "인벤토리 · 보유 재화와 장비" 포함). 숫자는 검수 fixture
// (`test/inventory_fe6a_fixture.dart`)의 시안 예시 값이다. 게임 그림이 없는 아이콘은 키트 규칙대로 빈 상자로 그린다.
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

void main() {
  setUpAll(loadGoldenFonts);

  testWidgets('inventory', (tester) async {
    setGoldenViewport(tester);
    final service = InventoryFixtureService();
    addTearDown(service.dispose);

    await tester.pumpWidget(goldenBoundary(BAPlannerApp(service: service)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('top-tab-inventory')));
    await tester.pumpAndSettle();
    await pumpUntilFound(
      tester,
      find.byKey(
        const ValueKey('inventory-row-Item_Icon_SecretStone_rio_armed'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('inventory-detail-name')))
          .data,
      '리오(무장)의 엘레프',
    );
    await expectGoldenScene(tester, 'inventory');
  }, variant: goldenPlatform);
}
